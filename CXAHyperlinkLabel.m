//
//  CXAHyperlinkLabel.m
//  CXAHyperlinkLabelDemo
//
//  Created by Chen Xian'an on 1/3/13.
//  Copyright (c) 2013 lazyapps. All rights reserved.
//

#import "CXAHyperlinkLabel.h"
#import <CoreText/CoreText.h>

#define ZERORANGE ((NSRange){0, 0})
#define LONGPRESS_DURATION .3

@interface CXAHyperlinkLabel(){
  CFArrayRef _lines;
  CGRect *_lineImageRectsCArray;
  NSUInteger _numLines;
  NSURL *_touchingURL;
  NSRange _touchingURLRange;
  NSRangePointer _rangesCArray;
  NSAttributedString *_attributedTextBeforeTouching;
  NSMutableArray *_URLs;
  NSMutableArray *_URLRanges;
}

- (void)drawRuns:(CFArrayRef)runs inContext:(CGContextRef)context lineOrigin:(CGPoint)lineOrigin;
- (NSURL *)handleTouches:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)highlightTouchingLinkAtRange:(NSRange)range;
- (void)reset;
- (void)longpressURL:(NSURL *)URL;

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
         range:(NSRange)range
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
         ranges:(NSArray *)ranges
{
  NSMutableDictionary *map = [@{} mutableCopy];
  if (!_URLs){
    _URLs = [@[] mutableCopy];
    _URLRanges = [ranges mutableCopy];
  } else {
    [_URLRanges enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
      map[obj] = _URLs[idx];
    }];
    [_URLRanges addObjectsFromArray:ranges];
  }
  
  [ranges enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
    map[obj] = URLs[idx];
  }];
  NSArray *unique = [[NSSet setWithArray:_URLRanges] allObjects];
  _URLRanges = [unique mutableCopy];
  [_URLRanges sortUsingComparator:^NSComparisonResult(id obj1, id obj2){
    NSRange r1 = [obj1 rangeValue];
    NSRange r2 = [obj2 rangeValue];
    if (r1.location < r2.location)
      return NSOrderedAscending;
    
    if (r1.location > r2.location)
      return NSOrderedDescending;
    
    return NSOrderedSame;
  }];
  
  [_URLs removeAllObjects];
  [_URLRanges enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
    [_URLs addObject:map[obj]];
  }];
}

- (void)removeURLAtRange:(NSRange)range
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
  if (_URLs)
    [_URLs removeAllObjects];
  
  if (_URLRanges)
    [_URLRanges removeAllObjects];
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
  
  CGContextTranslateCTM(context, 0, rectHeight);
  CGContextScaleCTM(context, 1, -1);
  CGContextSetTextMatrix(context, CGAffineTransformIdentity);
  [(__bridge NSArray *)_lines enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
    CTLineRef line = (__bridge CTLineRef)obj;
    CFArrayRef runs = CTLineGetGlyphRuns(line);
    [self drawRuns:runs inContext:context lineOrigin:lineOrigins[idx]];
  }];
  
  free(lineOrigins);
  CFRelease(framesetter);
  CFRelease(path);
  if (_rangesCArray)
    free(_rangesCArray);
  
  _rangesCArray = malloc(sizeof(NSRange) * [_URLs count]);
  [_URLRanges enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
    _rangesCArray[idx] = [obj rangeValue];
  }];}

- (CGSize)sizeThatFits:(CGSize)size
{
  // workaround for broken CTFramesetterCreateWithAttributedString
  // http://stackoverflow.com/a/10019378/395213
  if (!self.attributedText)
    return CGSizeZero;
  
  NSParagraphStyle *ps = [self.attributedText attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:NULL];
  id attrStr;
  if (!ps ||
      !ps.lineSpacing){
    __block CGFloat maxLineSpacing = 0;
    [self.attributedText enumerateAttribute:NSFontAttributeName inRange:NSMakeRange(0, [self.attributedText length]) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
      UIFont *f = value;
      CGFloat lineSpacing = f.lineHeight - f.ascender + f.descender;
      if (lineSpacing > maxLineSpacing)
        maxLineSpacing = lineSpacing;
    }];
    NSMutableParagraphStyle *mps = ps ? [ps mutableCopy] : [[NSMutableParagraphStyle alloc] init];
    mps.lineSpacing = maxLineSpacing;
    attrStr = [self.attributedText mutableCopy];
    [attrStr addAttributes:@{NSParagraphStyleAttributeName : mps} range:NSMakeRange(0, [attrStr length])];
  } else {
    attrStr = self.attributedText;
  }
  
  CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)attrStr);
  CGSize constraints = size;
  constraints.height = INT16_MAX;
  CGSize suggestSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, [attrStr length]), NULL, constraints, NULL);
  suggestSize.width = ceilf(suggestSize.width);
  suggestSize.height = ceilf(suggestSize.height);
  
  return suggestSize;
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
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(longpressURL:) object:_touchingURL];
  
  if ((_touchingURL = [self handleTouches:touches withEvent:event])){
    if (self.URLLongPressHandler){
      [self performSelector:@selector(longpressURL:) withObject:_touchingURL afterDelay:LONGPRESS_DURATION];
    }
  } else
    [super touchesBegan:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches
           withEvent:(UIEvent *)event
{
  if (_touchingURL)
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(longpressURL:) object:_touchingURL];
  
  if ((_touchingURL = [self URLAtPoint:[[touches anyObject] locationInView:self] effectiveRange:NULL])){
    if (self.URLClickHandler)
      self.URLClickHandler(self, _touchingURL);
  } else 
    [super touchesEnded:touches withEvent:event];
  
  [self reset];
}

- (void)touchesMoved:(NSSet *)touches
           withEvent:(UIEvent *)event
{
  if (_touchingURL)
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(longpressURL:) object:_touchingURL];
  
  _touchingURL = [self handleTouches:touches withEvent:event];
  if (!_touchingURL)
    [super touchesMoved:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches
               withEvent:(UIEvent *)event
{
  if (_touchingURL)
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(longpressURL:) object:_touchingURL];
  
  [super touchesCancelled:touches withEvent:event];
  [self reset];
}

#pragma mark - privates
- (void)drawRuns:(CFArrayRef)runs
       inContext:(CGContextRef)context
      lineOrigin:(CGPoint)lineOrigin
{
  [(__bridge NSArray *)runs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
    CTRunRef run = (__bridge CTRunRef)obj;
    CFRange range = CFRangeMake(0, 0);
    CGFloat lineOriginY = ceilf(lineOrigin.y);
    const CGPoint *posPtr = CTRunGetPositionsPtr(run);
    CGPoint *pos = NULL;
    NSDictionary *attrs = (__bridge NSDictionary *)CTRunGetAttributes(run);
    UIColor *bgColor = attrs[NSBackgroundColorAttributeName];
    if (bgColor){
      if (!posPtr){
        pos = malloc(sizeof(CGPoint));
        CTRunGetPositions(run, CFRangeMake(0, 1), pos);
        posPtr = pos;
      }
      CGFloat ascender, descender, leading;
      CGFloat width = CTRunGetTypographicBounds(run, range, &ascender, &descender, &leading);
      CGRect rect = CGRectMake(posPtr->x, lineOriginY - descender - leading, width, ascender + descender);
      rect = CGRectIntegral(rect);
      rect = CGRectInset(rect, -2, -2);
      if (posPtr->x <= 0){
        rect.origin.x += 2;
        rect.size.width -= 2;
      }
      
      if (lineOriginY <= 0){
        rect.origin.y += 2;
        rect.size.height -= 2;
      }
      
      UIBezierPath *bp = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:3.];
      CGContextSaveGState(context);
      CGContextAddPath(context, bp.CGPath);
      CGContextSetFillColorWithColor(context, bgColor.CGColor);
      CGContextFillPath(context);
      CGContextRestoreGState(context);
    }
    
    NSShadow *shadow = attrs[NSShadowAttributeName];
    if (shadow){
      CGContextSaveGState(context);
      CGContextSetShadowWithColor(context, shadow.shadowOffset, shadow.shadowBlurRadius, [shadow.shadowColor CGColor]);
    }
    
    CGContextSetTextPosition(context, 0, lineOriginY);
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
      CGContextMoveToPoint(context, posPtr->x, lineOriginY-1.5);
      CGContextAddLineToPoint(context, posPtr->x + width, lineOriginY-1.5);
      CGContextSaveGState(context);
      CGContextStrokePath(context);
      CGContextRestoreGState(context);
      if (pos)
        free(pos);
    }
  }];
}

- (NSURL *)handleTouches:(NSSet *)touches
               withEvent:(UIEvent *)event
{
  NSRange prevHitURLRange = _touchingURLRange;
  NSURL *URL = [self URLAtPoint:[[touches anyObject] locationInView:self] effectiveRange:&_touchingURLRange];
  if (_touchingURLRange.length){
    if (!prevHitURLRange.length ||
        !NSEqualRanges(prevHitURLRange, _touchingURLRange))
      [self highlightTouchingLinkAtRange:_touchingURLRange];
  } else {
    if (prevHitURLRange.length)
        self.attributedText = _attributedTextBeforeTouching;
  }
  
  return URL;
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
  if (_touchingURLRange.length){
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(setAttributedText:) object:_attributedTextBeforeTouching];
    [self performSelector:@selector(setAttributedText:) withObject:_attributedTextBeforeTouching afterDelay:.3];
  }
  
  _touchingURLRange = ZERORANGE;
  _attributedTextBeforeTouching = nil;
}

- (void)longpressURL:(NSURL *)URL
{
  self.URLLongPressHandler(self, URL);
}

@end