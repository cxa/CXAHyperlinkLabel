# CXAHyperlinkLabel

A drop-in and easy-to-use replacement for UILabel for iOS 6, supports handling link click and long press with block that provides information for URL, the range and rect of URL.

## Installation

`CXAHyperlinkLabel` requires `CoreText.framework`, add it to *`Build Phases`* in your build target.

Drop `CXAHyperlinkLabel.{h,m}` and `NSAttributedString+CXACoreTextFrameSize.{h,m}` into your project, and add `#include "CXAHyperlinkLabel.h"` to the top of classes which will use it.

## How to Use
Use it as the `UILabel`. To support links inside text, first you need to extract the URLs and the releated ranges, and tell `CXAHyperlinkLabel` with the method `- (void)setURL:range:`. To change the style of current touching link, set it with `linkAttributesWhenTouching` property. You can also tell `CXAHyperlinkLabel` what to do after clicking and/or long pressing a link with the block properties `URLClickHandler` and `URLLongPressHandler`.

### Header At a Glance 

#### `CXAHyperlinkLabel.h`
    @class CXAHyperlinkLabel;
    
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

#### `NSAttributedString+CXACoreTextFrameSize.h`

    @interface NSAttributedString (CXACoreTextFrameSize)
    
    - (CGSize)cxa_coreTextFrameSizeWithConstraints:(CGSize)size;
    
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

## Limitation

In order to get positions for links, `CXAHyperlinkLabel` draws its text from the ground-up via Core Text. Some rarely used or hard-to-implement attributes is currently not supported yet:

* `NSStrikethroughStyleAttributeName`
* `hyphenationFactor` of `NSParagraphStyle`

## Creator

* GitHub: <https://github.com/cxa>
* X: [@_realazy](https://x.com/_realazy)
* Apps available in App Store: <http://lazyapps.com>

## License

Under the MIT license. See the LICENSE file for more information.
