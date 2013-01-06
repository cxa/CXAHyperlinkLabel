//
//  CXADemoViewController.m
//  CXAHyperlinkLabelDemo
//
//  Created by Chen Xian'an on 1/4/13.
//  Copyright (c) 2013 lazyapps. All rights reserved.
//

#import "CXADemoViewController.h"
#import "CXAHyperlinkLabel.h"
#import "NSString+CXAHyperlinkParser.h"

@interface CXADemoViewController (){
  CXAHyperlinkLabel *_label;
}

- (NSAttributedString *)attributedString:(NSArray **)URLs URLRanges:(NSArray **)URLRanges;

@end

@implementation CXADemoViewController

- (id)init
{
  if (self = [super initWithNibName:nil bundle:nil]){
    
  }
  
  return self;
}

- (void)loadView
{
  UIScrollView *sv = [[UIScrollView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
  sv.contentSize = sv.bounds.size;
  self.view  = sv;
  self.view.backgroundColor = [UIColor colorWithHue:0 saturation:0 brightness:.9 alpha:1];
  NSArray *URLs;
  NSArray *URLRanges;
  NSAttributedString *as = [self attributedString:&URLs URLRanges:&URLRanges];
  _label = [[CXAHyperlinkLabel alloc] initWithFrame:CGRectZero];
  _label.numberOfLines = 0;
  _label.backgroundColor = [UIColor clearColor];
  _label.attributedText = as;
  _label.linkAttributesWhenTouching = @{ NSBackgroundColorAttributeName : [UIColor colorWithHue:.41 saturation:.00 brightness:.76 alpha:1.00] };
  [URLs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
    [_label setURL:obj range:[URLRanges[idx] rangeValue]];
  }];
  _label.URLClickHandler = ^(CXAHyperlinkLabel *label, NSURL *URL){
    [[[UIAlertView alloc] initWithTitle:@"URLClickHandler" message:[NSString stringWithFormat:NSLocalizedString(@"Click on the URL %@", nil), [URL absoluteString]] delegate:nil cancelButtonTitle:NSLocalizedString(@"Dismiss", nil) otherButtonTitles:nil] show];
  };
  _label.URLLongPressHandler = ^(CXAHyperlinkLabel *label, NSURL *URL){
    [[[UIActionSheet alloc] initWithTitle:[NSString stringWithFormat:@"URLLongPressHandler for URL: %@", [URL absoluteString]] delegate:nil cancelButtonTitle:NSLocalizedString(@"Cancel", nil) destructiveButtonTitle:nil otherButtonTitles:nil] showInView:self.view];
  };
  [self.view addSubview:_label];
}

- (void)viewWillLayoutSubviews
{
  CGFloat margin = 10.;
  CGSize size = CGRectInset(self.view.bounds, margin, margin).size;
  size.height = INT16_MAX;
  CGSize labelSize = [_label sizeThatFits:size];
  labelSize.width = size.width;
  _label.frame = (CGRect){CGPointMake(margin, margin), labelSize};
  CGFloat height = CGRectGetMaxY(_label.frame) + margin;
  if (height < CGRectGetHeight(self.view.bounds))
    height = CGRectGetHeight(self.view.bounds);
  
  ((UIScrollView *)self.view).contentSize = (CGSize){CGRectGetWidth(self.view.bounds), height};
}

#pragma mark - privates
- (NSAttributedString *)attributedString:(NSArray *__autoreleasing *)outURLs
                               URLRanges:(NSArray *__autoreleasing *)outURLRanges
{
  NSString *HTMLText = @"An inline link may display a modified version of the content; for instance, instead of an image, a <a href='/wiki/Thumbnail' title='Thumbnail'>thumbnail</a>, <a href='/wiki/Image_resolution' title='Image resolution'>low resolution</a> <a href='/wiki/Preview_(computing)' title='Preview (computing)'>preview</a>, <a href='/wiki/Cropping_(image)' title='Cropping (image)'>cropped</a> section, or <a href='/wiki/Magnification' title='Magnification'>magnified</a> section may be shown. The full content will then usually be available on demand, as is the case with <a href='/wiki/Desktop_publishing' title='Desktop publishing'>print publishing</a> software – e.g. with an external link. This allows for smaller file sizes and quicker response to changes when the full linked content is not needed, as is the case when rearranging a <a href='/wiki/Page_layout' title='Page layout'>page layout</a>.";
  NSArray *URLs;
  NSArray *URLRanges;
  UIColor *color = [UIColor blackColor];
  UIFont *font = [UIFont fontWithName:@"Baskerville" size:19.];
  NSMutableParagraphStyle *mps = [[NSMutableParagraphStyle alloc] init];
  mps.lineSpacing = ceilf(font.pointSize * .5);
  NSShadow *shadow = [[NSShadow alloc] init];
  shadow.shadowColor = [UIColor whiteColor];
  shadow.shadowOffset = CGSizeMake(0, 1);
  NSString *str = [NSString stringWithHTMLText:HTMLText baseURL:[NSURL URLWithString:@"http://en.wikipedia.org/"] URLs:&URLs URLRanges:&URLRanges];
  NSMutableAttributedString *mas = [[NSMutableAttributedString alloc] initWithString:str attributes:@
  {
    NSForegroundColorAttributeName : color,
    NSFontAttributeName            : font,
    NSParagraphStyleAttributeName  : mps,
    NSShadowAttributeName          : shadow,
  }];
  [URLRanges enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
    [mas addAttributes:@
     {
       NSForegroundColorAttributeName : [UIColor blueColor],
       NSUnderlineStyleAttributeName  : @(NSUnderlineStyleSingle)
     } range:[obj rangeValue]];
  }];
  
  *outURLs = URLs;
  *outURLRanges = URLRanges;
  
  return [mas copy];
}

@end
