//
//  NSString+CXAHyperlinkParser.h
//  CXAHyperlinkLabelDemo
//
//  Created by Chen Xian'an on 1/6/13.
//  Copyright (c) 2013 lazyapps. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (CXAHyperlinkParser)

+ (NSString *)stringWithHTMLText:(NSString *)HTMLText URLs:(NSArray **)URLs URLRanges:(NSArray **)URLRanges;
+ (NSString *)stringWithHTMLText:(NSString *)HTMLText baseURL:(NSURL *)baseURL URLs:(NSArray **)URLs URLRanges:(NSArray **)URLRanges;
+ (void)getURLs:(NSArray **)URLs URLRanges:(NSArray **)URLRanges forPlainText:(NSString *)plainText;

@end
