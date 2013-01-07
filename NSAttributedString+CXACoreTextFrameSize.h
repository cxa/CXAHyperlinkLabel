//
//  NSAttributedString+CXACoreTextFrameSize.h
//  CXAHyperlinkLabelDemo
//
//  Created by Chen Xian'an on 1/7/13.
//  Copyright (c) 2013 lazyapps. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSAttributedString (CXACoreTextFrameSize)

- (CGSize)cxa_coreTextFrameSizeWithConstraints:(CGSize)size;

@end
