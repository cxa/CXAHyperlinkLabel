//
//  CXAHyperlinkLabel.m
//  CXAHyperlinkLabelDemo
//
//  Created by Chen Xian'an on 1/3/13.
//  Copyright (c) 2013 lazyapps. All rights reserved.
//

#import "CXAHyperlinkLabel.h"
#import "NSAttributedString+CXACoreTextFrameSize.h"
#import <CoreText/CoreText.h>

#define ZERORANGE ((NSRange){0, 0})
#define LONGPRESS_DURATION .3
#define LONGPRESS_ARG @[_touchingURL, [NSValue valueWithRange:_touchingURLRange], _touchingRects]

@interface CXAHyperlinkLabel(){
  CFArrayRef _lines;
  CGRect *_lineImageRectsCArray;
  NSUInteger _numLines;
  NSURL *_touchingURL;
  NSRange _touchingURLRange;
  NSMutableArray *_touchingRects;
  NSRangePointer _rangesCArray;
  NSAttributedString *_attributedTextBeforeTouching;
  NSMutableArray *_URLs;
  NSMutableArray *_URLRanges;
}

- (void)drawRun:(CTRunRef)run inContext:(CGContextRef)context lineOrigin:(CGPoint)lineOrigin isTouchingRun:(BOOL)isTouchingRun;
- (void)handleTouches:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)highlightTouchingLinkAtRange:(NSRange)range;
- (void)reset;
- (void)longpress:(NSArray *)info;

@end

@implementation CXAHyperlinkLabel

#pragma mark -
- (id)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]){
    _linkAttributesWhenTouching = @{ NSBackgroundColorAttributeName : [UIColor colorWithHue:.41 saturation:.00 brightness:.76 alpha:1.00] };
    self.userInteractionEnabled = YES;
  }
  
  return self;
}

- (void)dealloc
{
  if (_lines)
    CFRelease(_lines);
  
  if (_lineImageRectsCArray)
    free(_lineImageRectsCArray);
  
  if (_rangesCArray)
    free(_rangesCArray);
}

#pragma mark -
- (void)setURL:(NSURL *)URL
      forRange:(NSRange)range
{
  if (!_URLs){
    _URLs = [@[] mutableCopy];
    _URLRanges = [@[] mutableCopy];
  }
  
  NSValue *rng = [NSValue valueWithRange:range];
  NSUInteger idx = [_URLRanges indexOfObject:rng inSortedRange:NSMakeRange(0, [_URLRanges count]) options:NSBinarySearchingInsertionIndex usingComparator:^NSComparisonResult(id obj1, id obj2){
    NSRange r1 = [obj1 rangeValue];
    NSRange r2 = [obj2 rangeValue];
    if (r1.location < r2.location)
      return NSOrderedAscending;
    
    if (r1.location > r2.location)
      return NSOrderedDescending;
    
    return NSOrderedSame;
  }];
  
  [_URLs insertObject:URL atIndex:idx];
  [_URLRanges insertObject:rng atIndex:idx];
}

- (void)setURLs:(NSArray *)URLs
      forRanges:(NSArray *)ranges
{
  if (!_URLs){
    _URLs = [URLs mutableCopy];
    _URLRanges = [ranges mutableCopy];
    
    return;
  }
  
  [URLs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
    [self setURL:obj forRange:[ranges[idx] rangeValue]];
  }];
}
- (void)removeURLForRange:(NSRange)range
{
  NSValue *v = [NSValue valueWithRange:range];
  NSUInteger idx = [_URLRanges indexOfObject:v];
  if (idx == NSNotFound)
    return;
  
  [_URLRanges removeObjectAtIndex:idx];
  [_URLs removeObjectAtIndex:idx];
}

- (void)removeAllURLs
{
  _URLs = nil;
  _URLRanges = nil;
}

- (NSURL *)URLAtPoint:(CGPoint)point
       effectiveRange:(NSRangePointer)effectiveRange
{
  if (effectiveRange)
    *effectiveRange = ZERORANGE;
  
  if (![_URLRanges count] ||
      !CGRectContainsPoint(self.bounds, point))
    return nil;
  
  void *found = bsearch_b(&point, _lineImageRectsCArray, _numLines, sizeof(CGRect), ^int(const void *key, const void *el){
    CGPoint *p = (CGPoint *)key;
    CGRect *r = (CGRect *)el;
    if (CGRectContainsPoint(*r, *p))
      return 0;
    
    if  (p->y > CGRectGetMaxY(*r))
      return 1;
    
    return -1;
  });
  
  if (!found)
    return nil;
  
  size_t idx = (CGRect *)found - _lineImageRectsCArray;
  CTLineRef line = CFArrayGetValueAtIndex(_lines, idx);
  CFIndex strIdx = CTLineGetStringIndexForPosition(line, point);
  if (strIdx == kCFNotFound)
    return nil;
  
  CGFloat offset = CTLineGetOffsetForStringIndex(line, strIdx, NULL);
  offset += _lineImageRectsCArray[idx].origin.x;
  if (point.x < offset)
    strIdx--;
  
  found = bsearch_b(&strIdx, _rangesCArray, [_URLRanges count], sizeof(NSRange), ^int(const void *key, const void *el){
    NSUInteger *idx = (NSUInteger *)key;
    NSRangePointer rng = (NSRangePointer)el;
    if (NSLocationInRange(*idx, *rng))
      return 0;
    
    if (*idx < rng->location)
      return -1;
    
    return 1;
  });
  
  if (!found)
    return nil;
  
  idx = (NSRangePointer)found - _rangesCArray;
  if (effectiveRange)
    *effectiveRange = [_URLRanges[idx] rangeValue];
  
  return _URLs[idx];
}

#pragma mark - 
- (void)drawTextInRect:(CGRect)rect
{
  if (!self.attributedText)
    return;
  
  CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)self.attributedText);
  CGPathRef path = CGPathCreateWithRect(rect, NULL);  
  CGFloat rectHeight = CGRectGetHeight(rect);
  CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, [self.attributedText length]), path, NULL);
  CGContextRef context = UIGraphicsGetCurrentContext();
  if (_lines)
    CFRelease(_lines);
  
  _lines = CTFrameGetLines(frame);  
  _numLines = CFArrayGetCount(_lines);
  CGPoint *lineOrigins = malloc(sizeof(CGPoint) * _numLines);
  CTFrameGetLineOrigins(frame, CFRangeMake(0, _numLines), lineOrigins);
  if (_lineImageRectsCArray)
    free(_lineImageRectsCArray);
  
  _lineImageRectsCArray = malloc(sizeof(CGRect) * _numLines);
  for (CFIndex i=0; i<_numLines; i++){
    CTLineRef line = CFArrayGetValueAtIndex(_lines, i);
    CGRect imgBounds = CTLineGetImageBounds(line, context);
    CGFloat ascender, descender, leading;
    CTLineGetTypographicBounds(line, &ascender, &descender, &leading);
    CGFloat filpY = CGRectGetHeight(self.bounds) - lineOrigins[i].y - ascender;
    imgBounds.origin.y = filpY - imgBounds.origin.y;
    _lineImageRectsCArray[i] = imgBounds;
  }
  
  if (_rangesCArray)
    free(_rangesCArray);
  
  _rangesCArray = malloc(sizeof(NSRange) * [_URLs count]);
  [_URLRanges enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
    _rangesCArray[idx] = [obj rangeValue];
  }];
  
  if (!_touchingRects)
    _touchingRects = [@[] mutableCopy];
  else
    [_touchingRects removeAllObjects];
  
  CGContextTranslateCTM(context, 0, rectHeight);
  CGContextScaleCTM(context, 1, -1);
  CGContextSetTextMatrix(context, CGAffineTransformIdentity);
  [(__bridge NSArray *)_lines enumerateObjectsUsingBlock:^(id lineObj, NSUInteger lineIdx, BOOL *lineStop){
    CTLineRef line = (__bridge CTLineRef)lineObj;
    CFArrayRef runs = CTLineGetGlyphRuns(line);
    [(__bridge NSArray *)runs enumerateObjectsUsingBlock:^(id runObj, NSUInteger runIdx, BOOL *runStop){
      CTRunRef run = (__bridge CTRunRef)runObj;
      CFRange cfrng = CTRunGetStringRange(run);
      [self drawRun:run inContext:context lineOrigin:lineOrigins[lineIdx] isTouchingRun:NSLocationInRange(cfrng.location, _touchingURLRange)];
    }];
  }];
  
  free(lineOrigins);
  CFRelease(framesetter);
  CFRelease(path);
}

- (CGSize)sizeThatFits:(CGSize)size
{
  return [self.attributedText cxa_coreTextFrameSizeWithConstraints:size];
}

- (void)sizeToFit
{
  CGSize toFitSize = self.superview ? self.superview.bounds.size : [UIScreen mainScreen].bounds.size;
  CGSize size = [self sizeThatFits:toFitSize];
  self.frame = (CGRect){self.frame.origin, size};
}

#pragma mark -
- (void)touchesBegan:(NSSet *)touches
           withEvent:(UIEvent *)event
{
  if (!_attributedTextBeforeTouching)
    _attributedTextBeforeTouching = self.attributedText;
  
  if (_touchingURL)
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(longpress:) object:LONGPRESS_ARG];
  
  [self handleTouches:touches withEvent:event];
  if (_touchingURL){
    if (self.URLLongPressHandler){
      [self performSelector:@selector(longpress:) withObject:LONGPRESS_ARG afterDelay:LONGPRESS_DURATION];
    }
  } else
    [super touchesBegan:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches
           withEvent:(UIEvent *)event
{
  if (_touchingURL)
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(longpress:) object:LONGPRESS_ARG];
  
  [self URLAtPoint:[[touches anyObject] locationInView:self] effectiveRange:&_touchingURLRange];
  if (_touchingURL){
    if (self.URLClickHandler)
      self.URLClickHandler(self, _touchingURL, _touchingURLRange, _touchingRects);
  } else 
    [super touchesEnded:touches withEvent:event];
  
  [self reset];
}

- (void)touchesMoved:(NSSet *)touches
           withEvent:(UIEvent *)event
{
  if (_touchingURL)
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(longpress:) object:LONGPRESS_ARG];
  
  [self handleTouches:touches withEvent:event];
  if (!_touchingURL)
    [super touchesMoved:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches
               withEvent:(UIEvent *)event
{
  if (_touchingURL)
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(longpress:) object:LONGPRESS_ARG];
  
  [super touchesCancelled:touches withEvent:event];
  [self reset];
}

#pragma mark - privates
- (void)drawRun:(CTRunRef)run
      inContext:(CGContextRef)context
     lineOrigin:(CGPoint)lineOrigin
  isTouchingRun:(BOOL)isTouchingRun
{
  CFRange range = CFRangeMake(0, 0);
  CGFloat lineOriginX = ceilf(lineOrigin.x);
  CGFloat lineOriginY = ceilf(lineOrigin.y);
  const CGPoint *posPtr = CTRunGetPositionsPtr(run);
  CGPoint *pos = NULL;
  NSDictionary *attrs = (__bridge NSDictionary *)CTRunGetAttributes(run);
  UIColor *bgColor = attrs[NSBackgroundColorAttributeName];
  if (isTouchingRun || bgColor){
    if (!posPtr){
      pos = malloc(sizeof(CGPoint));
      CTRunGetPositions(run, CFRangeMake(0, 1), pos);
      posPtr = pos;
    }
    CGFloat ascender, descender, leading;
    CGFloat width = CTRunGetTypographicBounds(run, range, &ascender, &descender, &leading);
    CGRect rect = CGRectMake(lineOriginX + posPtr->x, lineOriginY - descender, width, ascender + descender);
    rect = CGRectIntegral(rect);
    rect = CGRectInset(rect, -2, -2);
    if (lineOriginX + posPtr->x <= 0){
      rect.origin.x += 2;
      rect.size.width -= 2;
    }
    
    if (lineOriginY <= 0){
      rect.origin.y += 2;
      rect.size.height -= 2;
    }
    
    if (bgColor){
      UIBezierPath *bp = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:3.];
      CGContextSaveGState(context);
      CGContextAddPath(context, bp.CGPath);
      CGContextSetFillColorWithColor(context, bgColor.CGColor);
      CGContextFillPath(context);
      CGContextRestoreGState(context);
    }
    
    if (isTouchingRun){
      rect.origin.y = CGRectGetHeight(self.bounds) - CGRectGetMaxY(rect);
      [_touchingRects addObject:[NSValue valueWithCGRect:rect]];
    }
  }
  
  NSShadow *shadow = attrs[NSShadowAttributeName];
  if (shadow){
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, shadow.shadowOffset, shadow.shadowBlurRadius, [shadow.shadowColor CGColor]);
  }
  
  CGContextSetTextPosition(context, lineOriginX, lineOriginY);
  CTRunDraw(run, context, range);
  if (shadow)
    CGContextRestoreGState(context);
  
  NSNumber *underlineStyle = attrs[NSUnderlineStyleAttributeName];
  if (underlineStyle && [underlineStyle intValue] == NSUnderlineStyleSingle){
    UIColor *fgColor = attrs[NSForegroundColorAttributeName];
    if (!fgColor)
      fgColor = [UIColor blackColor];
    
    CGFloat width = CTRunGetTypographicBounds(run, range, NULL, NULL, NULL);
    if (!posPtr){
      pos = malloc(sizeof(CGPoint));
      CTRunGetPositions(run, CFRangeMake(0, 1), pos);
      posPtr = pos;
    }
    
    CGContextSetStrokeColorWithColor(context, fgColor.CGColor);
    CGContextSetLineWidth(context, 1.);
    CGContextMoveToPoint(context, lineOriginX + posPtr->x, lineOriginY-1.5);
    CGContextAddLineToPoint(context, lineOriginX + posPtr->x + width, lineOriginY-1.5);
    CGContextSaveGState(context);
    CGContextStrokePath(context);
    CGContextRestoreGState(context);
    if (pos)
      free(pos);
  }
}

- (void)handleTouches:(NSSet *)touches
            withEvent:(UIEvent *)event
{
  NSRange prevHitURLRange = _touchingURLRange;
  _touchingURL = [self URLAtPoint:[[touches anyObject] locationInView:self] effectiveRange:&_touchingURLRange];
  if (_touchingURLRange.length){
    if (!prevHitURLRange.length ||
        !NSEqualRanges(prevHitURLRange, _touchingURLRange))
      [self highlightTouchingLinkAtRange:_touchingURLRange];
  } else {
    if (prevHitURLRange.length)
        self.attributedText = _attributedTextBeforeTouching;
  }
}

- (void)highlightTouchingLinkAtRange:(NSRange)range
{
  if (!self.linkAttributesWhenTouching)
    return;
  
  NSMutableAttributedString *mas = [_attributedTextBeforeTouching mutableCopy];
  [mas addAttributes:self.linkAttributesWhenTouching range:range];
  self.attributedText = mas;
}

- (void)reset
{
  if (_touchingURL){
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(setAttributedText:) object:_attributedTextBeforeTouching];
    [self performSelector:@selector(setAttributedText:) withObject:_attributedTextBeforeTouching afterDelay:.3];
  }
  
  _touchingURLRange = ZERORANGE;
  _touchingURL = nil;
  _attributedTextBeforeTouching = nil;
}

- (void)longpress:(NSArray *)info
{
  self.URLLongPressHandler(self, info[0], [info[1] rangeValue], info[2]);
}

@end
