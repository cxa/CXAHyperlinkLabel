//
//  CXAHyperlinkLabel.h
//  CXAHyperlinkLabelDemo
//
//  Created by Chen Xian'an on 1/3/13.
//  Copyright (c) 2013 lazyapps. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CXAHyperlinkLabel;

// The URL may be broken into 2 or more lines, that's why CXAHyperlinkLabel provide textRects but not textRect
typedef void (^CXAHyperlinkLabelURLHandler)(CXAHyperlinkLabel *label, NSURL *URL, NSRange textRange, NSArray *textRects);

@interface CXAHyperlinkLabel : UILabel

@property (nonatomic, copy) CXAHyperlinkLabelURLHandler URLClickHandler;
@property (nonatomic, copy) CXAHyperlinkLabelURLHandler URLLongPressHandler;
@property (nonatomic, strong) NSDictionary *linkAttributesWhenTouching;

- (void)setURL:(NSURL *)URL forRange:(NSRange)range;
- (void)setURLs:(NSArray *)URLs forRanges:(NSArray *)ranges;
- (void)removeURLForRange:(NSRange)range;
- (void)removeAllURLs;
- (NSURL *)URLAtPoint:(CGPoint)point effectiveRange:(NSRangePointer)effectiveRange;

@end
