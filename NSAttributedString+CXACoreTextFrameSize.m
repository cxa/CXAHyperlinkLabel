//
//  NSAttributedString+CXACoreTextFrameSize.m
//  CXAHyperlinkLabelDemo
//
//  Created by Chen Xian'an on 1/7/13.
//  Copyright (c) 2013 lazyapps. All rights reserved.
//

#import "NSAttributedString+CXACoreTextFrameSize.h"
#import <CoreText/CoreText.h>

@implementation NSAttributedString (CXACoreTextFrameSize)

- (CGSize)cxa_coreTextFrameSizeWithConstraints:(CGSize)size
{
  if (!self.length)
    return CGSizeZero;
  
  // workaround for broken CTFramesetterCreateWithAttributedString
  // http://stackoverflow.com/a/10019378/395213
  NSParagraphStyle *ps = [self attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:NULL];
  id attrStr;
  if (!ps ||
      !ps.lineSpacing){
    __block CGFloat maxLineSpacing = 0;
    [self enumerateAttribute:NSFontAttributeName inRange:NSMakeRange(0, [self length]) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
      UIFont *f = value;
      CGFloat lineSpacing = f.lineHeight - f.ascender + f.descender;
      if (lineSpacing > maxLineSpacing)
        maxLineSpacing = lineSpacing;
    }];
    NSMutableParagraphStyle *mps = ps ? [ps mutableCopy] : [[NSMutableParagraphStyle alloc] init];
    mps.lineSpacing = maxLineSpacing;
    attrStr = [self mutableCopy];
    [attrStr addAttributes:@{NSParagraphStyleAttributeName : mps} range:NSMakeRange(0, [attrStr length])];
  } else {
    attrStr = self;
  }
  
  CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)attrStr);
  CGSize constraints = size;
  constraints.height = INT16_MAX;
  CGSize suggestSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, [attrStr length]), NULL, constraints, NULL);
  suggestSize.width = ceilf(suggestSize.width);
  suggestSize.height = ceilf(suggestSize.height);
  
  return suggestSize;
}

@end
