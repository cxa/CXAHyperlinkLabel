# CXAHyperlinkLabel

A drop-in and easy-to-use replacement for UILabel for iOS 6, supports handling link click and long press with block.

## Installation

`CXAHyperlinkLabel` requires `CoreText.framework`, add it to *`Build Phases`* in your build target.

Drop `CXAHyperlinkLabel.{h,m}` into your project, and add `#include "CXAHyperlinkLabel.h"` to the top of classes which will use it.

## How to Use
Use it as the `UILabel`. To support links inside text, first you need to extract the URLs and the releated ranges, and tell `CXAHyperlinkLabel` with the method `- (void)setURL:range:`. To change the style of current touching link, set it with `linkAttributesWhenTouching` property. You can also tell `CXAHyperlinkLabel` what to do after clicking and/or long pressing a link with the block properties `URLClickHandler` and `URLLongPressHandler`.

### Header At a Glance 

    @class CXAHyperlinkLabel;
    
    typedef void (^CXAHyperlinkLabelURLHandler)(CXAHyperlinkLabel *label, NSURL *URL);
    
    @interface CXAHyperlinkLabel : UILabel
    
    @property (nonatomic, copy) CXAHyperlinkLabelURLHandler URLClickHandler;
    @property (nonatomic, copy) CXAHyperlinkLabelURLHandler URLLongPressHandler;
    @property (nonatomic, strong) NSDictionary *linkAttributesWhenTouching;
    
    - (void)setURL:(NSURL *)URL range:(NSRange)range;
    - (void)setURLs:(NSArray *)URLs ranges:(NSArray *)ranges;
    - (void)removeURLAtRange:(NSRange)range;
    - (void)removeAllURLs;
    - (NSURL *)URLAtPoint:(CGPoint)point effectiveRange:(NSRangePointer)effectiveRange;
    
    @end

Clone and run the demo!

## Bonus

This project also includes a category for NSString `NSString (CXAHyperlinkParser)` to parse simple HTML text (only `a` and `br` tags are supported). Extract links and ranges from plain text is also supported. It's very lightweight to save you from some huge library — Don't use a shotgun to kill a butterfly. 

`NSString (CXAHyperlinkParser)` requires `libxml2`. To install, drop `NSString+CXAHyperlinkParser.{h,m}` to your project, add `libxml2.2.dylib` to *`Build Phases`* and don't forget to set `$(SDK_ROOT)/usr/include/libxml2` in `Header Search Paths` of *`Build Settings`* in your build target.

### Header At a Glance 
    
    @interface NSString (CXAHyperlinkParser)
    
    + (NSString *)stringWithHTMLText:(NSString *)HTMLText URLs:(NSArray **)URLs URLRanges:(NSArray **)URLRanges;
    + (NSString *)stringWithHTMLText:(NSString *)HTMLText baseURL:(NSURL *)baseURL URLs:(NSArray **)URLs URLRanges:(NSArray **)URLRanges;
    + (void)getURLs:(NSArray **)URLs URLRanges:(NSArray **)URLRanges forPlainText:(NSString *)plainText;
    
    @end

## Creator

* GitHub: <https://github.com/cxa>
* Twitter: [@_cxa](https://twitter.com/_cxa)
* Apps available in App Store: <http://lazyapps.com>

## License

Under the MIT license. See the LICENSE file for more information.
