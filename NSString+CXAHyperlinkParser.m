//
//  NSString+CXAHyperlinkParser.m
//  CXAHyperlinkLabelDemo
//
//  Created by Chen Xian'an on 1/6/13.
//  Copyright (c) 2013 lazyapps. All rights reserved.
//

#import "NSString+CXAHyperlinkParser.h"
#import <libxml/HTMLparser.h>

static htmlSAXHandler saxHandler;

@interface HTMLSAXHandlerContext : NSObject

@property (nonatomic, strong) NSMutableString *plainText;
@property (nonatomic, strong) NSURL *baseURL;
@property (nonatomic, strong) NSMutableArray *URLs;
@property (nonatomic, strong) NSMutableArray *URLRanges;
@property (nonatomic, strong) NSURL *currentURL;
@property (nonatomic) NSUInteger currentLocation;

@end

@implementation NSString (CXAHyperlinkParser)

+ (NSString *)stringWithHTMLText:(NSString *)HTMLText
                            URLs:(NSArray *__autoreleasing *)URLs
                       URLRanges:(NSArray *__autoreleasing *)URLRanges
{
  return [self stringWithHTMLText:HTMLText baseURL:nil URLs:URLs URLRanges:URLRanges];
}

+ (NSString *)stringWithHTMLText:(NSString *)HTMLText
                         baseURL:(NSURL *)baseURL
                            URLs:(NSArray *__autoreleasing *)URLs
                       URLRanges:(NSArray *__autoreleasing *)URLRanges
{
  HTMLSAXHandlerContext *ctx = [[HTMLSAXHandlerContext alloc] init];
  ctx.plainText = [@"" mutableCopy];
  ctx.baseURL = baseURL;
  if (URLs || URLRanges){
    ctx.URLs = [@[] mutableCopy];
    ctx.URLRanges = [@[] mutableCopy];
  }
  
  htmlSAXParseDoc((xmlChar *)[HTMLText UTF8String], "UTF-8", &saxHandler, (__bridge void *)ctx);
  if (URLs)
    *URLs = [ctx.URLs copy];
  
  if (URLRanges)
    *URLRanges = [ctx.URLRanges copy];
  
  return [ctx.plainText copy];
}

+ (void)getURLs:(NSArray *__autoreleasing *)URLs
      URLRanges:(NSArray *__autoreleasing *)URLRanges
   forPlainText:(NSString *)plainText
{
  NSDataDetector *dd = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:NULL];
  NSMutableArray *mURLs = URLs ? [@[] mutableCopy] : nil;
  NSMutableArray *mURLRanges = URLRanges ? [@[] mutableCopy] : nil;
  [dd enumerateMatchesInString:plainText options:0 range:NSMakeRange(0, [plainText length]) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop){
    if (mURLs)
      [mURLs addObject:[NSURL URLWithString:[plainText substringWithRange:result.range]]];
    
    if (mURLRanges)
      [mURLRanges addObject:[NSValue valueWithRange:result.range]];
  }];
  
  if (URLs &&
      [mURLs count])
    *URLs = [mURLs copy];
  
  if (URLRanges &&
      [mURLRanges count])
    *URLRanges = [mURLRanges copy];
}

@end

#pragma mark - sax event functions

static void _elementStart(void *context, const xmlChar *name,const xmlChar **atts);
static void _elementEnd(void *context, const xmlChar *name);
static void _characters(void *context, const xmlChar *ch, int len);
static htmlSAXHandler saxHandler = {
  NULL, /* internalSubset */
  NULL, /* isStandalone */
  NULL, /* hasInternalSubset */
  NULL, /* hasExternalSubset */
  NULL, /* resolveEntity */
  NULL, /* getEntity */
  NULL, /* entityDecl */
  NULL, /* notationDecl */
  NULL, /* attributeDecl */
  NULL, /* elementDecl */
  NULL, /* unparsedEntityDecl */
  NULL, /* setDocumentLocator */
  NULL, /* startDocument */
  NULL, /* endDocument */
  (startElementSAXFunc)_elementStart, /* startElement */
  (endElementSAXFunc)_elementEnd, /* endElement */
  NULL, /* reference */
  (charactersSAXFunc)_characters, /* characters */
  NULL, /* ignorableWhitespace */
  NULL, /* processingInstruction */
  NULL, /* comment */
  NULL, /* xmlParserWarning */
  NULL, /* xmlParserError */
  NULL, /* xmlParserError */
  NULL, /* getParameterEntity */
};

@implementation HTMLSAXHandlerContext @end

void _elementStart(void *context, const xmlChar *name, const xmlChar **atts)
{
  HTMLSAXHandlerContext *sctx = (__bridge HTMLSAXHandlerContext *)context;
  if (!sctx.URLs)
    return;
  
  if (strcasecmp((char *)name, "a") == 0){
    int i = 0;
    char *att = (char *)atts[i];
    do {
      if (strcasecmp(att, "href") == 0 &&
          atts[i+1]){
        NSString *URLString = [NSString stringWithUTF8String:(char *)atts[i+1]];
        if (sctx.baseURL) // make sure don't encode twice
          URLString = [[URLString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        NSURL *URL = sctx.baseURL ? [NSURL URLWithString:URLString relativeToURL:sctx.baseURL] : [NSURL URLWithString:URLString];
        sctx.currentURL = URL;
        sctx.currentLocation = [sctx.plainText length];
        break;
      }
    } while ((att = (char *)atts[i++]));
  }
}

void _elementEnd(void *context, const xmlChar *name)
{
  HTMLSAXHandlerContext *sctx = (__bridge HTMLSAXHandlerContext *)context;
  if (!sctx.URLs)
    return;
  
  if (strcasecmp((char *)name, "a") == 0 &&
      sctx.currentURL){
    NSRange range = NSMakeRange(sctx.currentLocation, [sctx.plainText length] - sctx.currentLocation);
    [sctx.URLs addObject:sctx.currentURL];
    [sctx.URLRanges addObject:[NSValue valueWithRange:range]];
    sctx.currentURL = nil;
  } else if (strcasecmp((char *)name, "br") == 0){
    [sctx.plainText appendString:@"\n"];
  }
}

void _characters(void *context, const xmlChar *ch, int len)
{
  HTMLSAXHandlerContext *sctx = (__bridge HTMLSAXHandlerContext *)context;
  NSString *string = [NSString stringWithUTF8String:(char *)ch];
  string = [string stringByReplacingOccurrencesOfString:@"\r" withString:@""];
  [sctx.plainText appendString:string];
}