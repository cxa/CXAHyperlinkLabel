//
//  CXAHyperlinkLabel.h
//  CXAHyperlinkLabelDemo
//
//  Created by Chen Xian'an on 1/3/13.
//  Copyright (c) 2013 lazyapps. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CXAHyperlinkLabel;

typedef void (^CXAHyperlinkLabelURLHandler)(CXAHyperlinkLabel *label, NSURL *URL);

@interface CXAHyperlinkLabel : UILabel

@property (nonatomic, copy) CXAHyperlinkLabelURLHandler URLClickHandler;
@property (nonatomic, copy) CXAHyperlinkLabelURLHandler URLLongPressHandler;
@property (nonatomic, strong) NSDictionary *linkAttributesWhenTouching;

- (void)setURL:(NSURL *)URL range:(NSRange)range;
- (NSURL *)URLAtPoint:(CGPoint)point effectiveRange:(NSRangePointer)effectiveRange;

@end