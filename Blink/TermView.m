////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2018 Blink Mobile Shell Project
//
// This file is part of Blink.
//
// Blink is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Blink is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Blink. If not, see <http://www.gnu.org/licenses/>.
//
// In addition, Blink is also subject to certain additional terms under
// GNU GPL version 3 section 7.
//
// You should have received a copy of these additional terms immediately
// following the terms and conditions of the GNU General Public License
// which accompanied the Blink Source Code. If not, see
// <http://www.github.com/blinksh/blink>.
//
////////////////////////////////////////////////////////////////////////////////

#import "TermView.h"
#import "TermDevice.h"
#import "BKDefaults.h"
#import "BKSettingsNotifications.h"
#import "BKFont.h"
#import "BKTheme.h"
#import "TermJS.h"
#import <zlib.h>

#import <compression.h>

struct winsize __winSizeFromJSON(NSDictionary *json) {
  struct winsize res;
  res.ws_col = [json[@"cols"] integerValue];
  res.ws_row = [json[@"rows"] integerValue];
  
  return res;
}

@implementation BKWebView

- (BOOL)canResignFirstResponder
{
  return NO;
}

- (BOOL)becomeFirstResponder
{
  return NO;
}

- (void)_keyboardDidChangeFrame:(id)sender
{
  
}

- (void)_keyboardWillChangeFrame:(id)sender
{
  
}

- (void)_keyboardWillShow:(id)sender
{
  
}

- (void)_keyboardWillHide:(id)sender
{
  
}


@end


@interface TermView () <UIGestureRecognizerDelegate, WKScriptMessageHandler>
@end

@implementation TermView {
  WKWebView *_webView;
  UIImageView *_snapshotImageView;
  
  BOOL _focused;
  BOOL _jsIsBusy;
  dispatch_queue_t _jsQueue;
  NSMutableString *_jsBuffer;
}


- (id)initWithFrame:(CGRect)frame andBgColor:(UIColor *)bgColor
{
  self = [super initWithFrame:frame];

  if (!self) {
    return self;
  }
    
  _jsQueue = dispatch_queue_create(@"TermView.js".UTF8String, DISPATCH_QUEUE_SERIAL);
  _jsBuffer = [[NSMutableString alloc] init];

  self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [self _addWebView];
  self.opaque = YES;
  _webView.opaque = YES;
  
  UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
  imageView.contentMode = UIViewContentModeTop | UIViewContentModeLeft;
  imageView.autoresizingMask =  UIViewAutoresizingNone;
  
  bgColor = bgColor ?: [UIColor blackColor];
  imageView.backgroundColor = bgColor;
  self.backgroundColor = bgColor;
  
  _snapshotImageView = imageView;
  [self addSubview:imageView];
  
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self selector:@selector(_willResignActive) name:UIApplicationWillResignActiveNotification object:nil];
  [nc addObserver:self selector:@selector(_didBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];

  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)_willResignActive
{
  if (self.window == nil) {
    return;
  }

  if (@available(iOS 11.0, *)) {
    [_webView takeSnapshotWithConfiguration:nil completionHandler:^(UIImage * _Nullable snapshotImage, NSError * _Nullable error) {
      _snapshotImageView.image = snapshotImage;
      _snapshotImageView.frame = self.bounds;
      _snapshotImageView.alpha = 1;
      [self addSubview:_snapshotImageView];
      [_webView removeFromSuperview];
    }];
  } else {
    // Blank screen for ios 10?
    _snapshotImageView.frame = self.bounds;
    [self addSubview:_snapshotImageView];
    [_webView removeFromSuperview];
  }
}

- (void)_didBecomeActive
{
  if (_webView.superview) {
    return;
  }

  _webView.frame = self.bounds;
  [self insertSubview:_webView belowSubview:_snapshotImageView];
  [UIView animateWithDuration:0.2 delay:0.0 options:kNilOptions animations:^{
    _snapshotImageView.alpha = 0;
  } completion:^(BOOL finished) {
    [_snapshotImageView removeFromSuperview];
  }];
}

- (BOOL)canBecomeFirstResponder {
  return NO;
}

- (void)_addWebView
{
  WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
  configuration.selectionGranularity = WKSelectionGranularityCharacter;
  [configuration.userContentController addScriptMessageHandler:self name:@"interOp"];

  _webView = [[BKWebView alloc] initWithFrame:self.bounds configuration:configuration];
  
  _webView.scrollView.delaysContentTouches = NO;
  _webView.scrollView.canCancelContentTouches = NO;
  _webView.scrollView.scrollEnabled = NO;
  _webView.scrollView.panGestureRecognizer.enabled = NO;
  
  _webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  
  [self addSubview:_webView];
}

- (NSString *)title
{
  return _webView.title;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
  [super setBackgroundColor:backgroundColor];
  _webView.backgroundColor = backgroundColor;
}

- (void)loadWith:(MCPSessionParameters *)params;
{
  [_webView.configuration.userContentController addUserScript:[self _termInitScriptWith:params]];
  
  NSString *path = [[NSBundle mainBundle] pathForResource:@"term" ofType:@"html"];
  NSURL *url = [NSURL fileURLWithPath:path];
  NSURLRequest *request = [NSURLRequest requestWithURL:url];
  
  [_webView loadRequest:request];
}

- (void)reloadWith:(MCPSessionParameters *)params;
{
  _snapshotImageView.frame = self.bounds;
  [self addSubview:_snapshotImageView];
  _snapshotImageView.alpha = 1;
  [_webView.configuration.userContentController removeAllUserScripts];
  [_webView.configuration.userContentController addUserScript:[self _termInitScriptWith:params]];
  [_webView reload];
}

- (void)setWidth:(NSInteger)count
{
  [_webView evaluateJavaScript:term_setWidth(count) completionHandler:nil];
}

- (void)setFontSize:(NSNumber *)newSize
{
  [_webView evaluateJavaScript:term_setFontSize(newSize) completionHandler:nil];
}

- (void)clear
{
  [_webView evaluateJavaScript:term_clear() completionHandler:nil];
}

- (void)cleanSelection
{
  [_webView evaluateJavaScript:term_cleanSelection() completionHandler:nil];
}

- (void)setCursorBlink:(BOOL)state
{
  [_webView evaluateJavaScript:term_setCursorBlink(state) completionHandler:nil];
}

- (void)setBoldAsBright:(BOOL)state
{
  [_webView evaluateJavaScript:term_setBoldAsBright(state) completionHandler:nil];
}

- (void)setBoldEnabled:(NSUInteger)state
{
  [_webView evaluateJavaScript:term_setBoldEnabled(state) completionHandler:nil];
}

- (void)reset
{
  [_webView evaluateJavaScript:term_reset() completionHandler:nil];
}

- (void)increaseFontSize
{
  [_webView evaluateJavaScript:term_increaseFontSize() completionHandler:nil];
}

- (void)decreaseFontSize
{
  [_webView evaluateJavaScript:term_decreaseFontSize() completionHandler:nil];
}

- (void)resetFontSize
{
  [_webView evaluateJavaScript:term_resetFontSize() completionHandler:nil];
}

- (void)focus {
  _focused = YES;
  [self _didBecomeActive]; // Double check and attach if we are detached
  [_webView evaluateJavaScript:term_focus() completionHandler:nil];
}

- (void)reportTouchInPoint:(CGPoint)point
{
  [_webView evaluateJavaScript:term_reportTouchInPoint(point) completionHandler:nil];
}

- (void)blur
{
  _focused = NO;
  [_webView evaluateJavaScript:term_blur() completionHandler:nil];
}

// Write data to terminal control
- (void)write:(NSString *)data
{
  dispatch_async(_jsQueue, ^{
    [_jsBuffer appendString:data];
    
    if (_jsIsBusy) {
      return;
    }

    NSString * buffer = _jsBuffer;
    if (buffer.length == 0) {
      return;
    }
  
    _jsIsBusy = YES;
    _jsBuffer = [[NSMutableString alloc] init];
    
    const NSString *jsScript = term_write(buffer);
    [self _evalJSScript:jsScript];
  });
}

- (void)writeB64:(NSData *)data
{
  dispatch_async(_jsQueue, ^{
    _jsIsBusy = YES;

    NSString * buffer = _jsBuffer;
    _jsBuffer = [[NSMutableString alloc] init];
    
    NSString *jsScript = term_writeB64(data);
    
    if (buffer.length > 0) {
      jsScript = [term_write(buffer) stringByAppendingString:jsScript];
    }
    [self _evalJSScript:jsScript];
  });
}

- (void)_evalJSScript:(NSString *)jsScript
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [_webView evaluateJavaScript: jsScript completionHandler:^(id result, NSError *error) {
      dispatch_async(_jsQueue, ^{
        _jsIsBusy = NO;
        if (_jsBuffer.length > 0) {
          [self write:@""];
        }
      });
    }];
  });
}

//  Since TermView is a WKScriptMessageHandler, it must implement the userContentController:didReceiveScriptMessage method. This is the method that is triggered each time 'interOp' is sent a message from the JavaScript code.
- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message
{
  NSDictionary *sentData = (NSDictionary *)message.body;
  NSString *operation = sentData[@"op"];
  NSDictionary *data = sentData[@"data"] ?: @{};

  if ([operation isEqualToString:@"selectionchange"]) {
    [self _handleSelectionChange:data];
  } else if ([operation isEqualToString:@"sigwinch"]) {
    [_device viewWinSizeChanged:__winSizeFromJSON(data)];
  } else if ([operation isEqualToString:@"terminalReady"]) {
    [self _onTerminalReady:data];
  } else if ([operation isEqualToString:@"fontSizeChanged"]) {
    [_device viewFontSizeChanged:[data[@"size"] integerValue]];
  } else if ([operation isEqualToString:@"copy"]) {
    [_device viewCopyString: data[@"content"]];
  } else if ([operation isEqualToString:@"sendString"]) {
    [_device viewSendString:data[@"string"]];
  }
}

- (void)_onTerminalReady:(NSDictionary *)data
{
  NSArray *bgColor = data[@"bgColor"];
  if (bgColor && bgColor.count == 3) {
    self.backgroundColor = [UIColor colorWithRed:[bgColor[0] floatValue] / 255.0f
                                           green:[bgColor[1] floatValue] / 255.0f
                                            blue:[bgColor[2] floatValue] / 255.0f
                                           alpha:1];
  }
  
  [_device viewWinSizeChanged:__winSizeFromJSON(data[@"size"])];
  
  self.alpha = 1;

  [_device viewIsReady];
    
  if (_focused) {
    [self focus];
  } else {
    [self blur];
  }
  
  [UIView animateWithDuration:0.2 delay:0.0 options:kNilOptions animations:^{
    _snapshotImageView.alpha = 0;
  } completion:^(BOOL finished) {
    [_snapshotImageView removeFromSuperview];
  }];
}
  
- (NSString *)_menuTitleFromNSURL:(NSURL *)url
{
  if (!url) {
    return @"";
  }
  
  NSString *base = url.host;
  
  if (!base) {
    if ([@"mailto" isEqualToString:url.scheme]) {
      base = @"Email";
    } else {
      base = @"URL";
    }
  }
  
  if (url.fragment.length > 0 || url.path.length > 0 || url.query.length > 0) {
    return [base stringByAppendingString:@"…"];
  }
  
  return base;
}
  
- (NSString *)_menuActionTitleFromNSURL:(NSURL *)url
{
  if (!url) {
    return @"Open";
  }

  if ([@"mailto" isEqualToString:url.scheme]) {
    return @"Compose";
  }
  
  return @"Open";
}

- (void)_handleSelectionChange:(NSDictionary *)data
{
  _selectedText = data[@"text"];
  _hasSelection = _selectedText.length > 0;
  
  if (!_hasSelection) {
    return;
  }
  
  NSMutableArray *items = [[NSMutableArray alloc] init];
  UIMenuController * menu = [UIMenuController sharedMenuController];
  
  [items addObject:[[UIMenuItem alloc] initWithTitle:@"Paste selection"
                                              action:@selector(pasteSelection:)]];
  
  _detectedLink = [self _detectLinkInSelection:data];
  
  if (_detectedLink) {
    NSString *urlName = [self _menuTitleFromNSURL: _detectedLink];
    [items addObject:[[UIMenuItem alloc] initWithTitle:[@"Copy " stringByAppendingString:urlName]
                                                action:@selector(copyLink:)]];
    
    NSString *actionTitle = [NSString stringWithFormat:@"%@ %@",
                             [self _menuActionTitleFromNSURL:_detectedLink], urlName];
    [items addObject:[[UIMenuItem alloc] initWithTitle:actionTitle
                                                action:@selector(openLink:)]];
  }

  
  CGRect rect = CGRectFromString(data[@"rect"]);
  [menu setMenuItems:items];
  [menu setTargetRect:rect inView:self];
  [menu setMenuVisible:YES animated:NO];
}

- (void)modifySideOfSelection
{
  [_webView evaluateJavaScript:term_modifySideSelection() completionHandler:nil];
}

- (void)modifySelectionInDirection:(NSString *)direction granularity:(NSString *)granularity
{
  [_webView evaluateJavaScript:term_modifySelection(direction, granularity) completionHandler:nil];
}

- (NSURL *)_detectLinkInSelection:(NSDictionary *)data
{
  __block NSURL *result = nil;
  NSString *text = data[@"base"];
  NSInteger offset = [data[@"offset"] integerValue];
  
  if (text == nil || [text length] == 0) {
    return nil;
  }
  
  NSDataDetector * dataDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil];
  [dataDetector enumerateMatchesInString:text options:kNilOptions range:NSMakeRange(0, [text length])
                              usingBlock:^(NSTextCheckingResult * _Nullable res, NSMatchingFlags flags, BOOL * _Nonnull stop) {
                                
                                if (res == nil) {
                                  return;
                                }
                                NSURL *url = res.URL;
                                
                                if (url && res.range.location <= offset && res.range.location + res.range.length >= offset) {
                                  result = url;
                                  *stop = YES;
                                }
                              }];
  return result;
}


// just to remove warning in selector

- (void)copyLink:(id)sender
{
}

- (void)openLink:(id)sender
{
}

- (void)yank:(id)sender
{
}
  
- (void)pasteSelection:(id)sender
{
  NSString *str = _selectedText;
  if (str) {
    [_webView evaluateJavaScript:term_paste(str) completionHandler:nil];
  }
  [self cleanSelection];
}

- (void)copy:(id)sender
{
  [_webView copy:sender];
  UIMenuController * menu = [UIMenuController sharedMenuController];
  [menu setMenuVisible:NO animated:YES];
}

- (void)paste:(id)sender
{
  NSString *str = [UIPasteboard generalPasteboard].string;
  if (str) {
    [_webView evaluateJavaScript:term_paste(str) completionHandler:nil];
  }
  
  [self cleanSelection];
}

- (NSString *)_detectFontFamilyFromContent:(NSString *)content
{
  NSRegularExpression *regex = [NSRegularExpression
                                regularExpressionWithPattern:@"font-family:\\s*(.+);"
                                options:NSRegularExpressionCaseInsensitive
                                error:nil];
  __block NSString *result = nil;
  [regex enumerateMatchesInString:content
                          options:0
                            range:NSMakeRange(0, [content length])
                       usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop)
  {
    if (match && match.numberOfRanges == 2) {
     result = [content substringWithRange:[match rangeAtIndex:1]];
    }
    *stop = YES;
  }];
  return result;
}

- (WKUserScript *)_termInitScriptWith:(MCPSessionParameters *)params;
{
  NSMutableArray *script = [[NSMutableArray alloc] init];
  BKFont *font = [BKFont withName: params.fontName ?: [BKDefaults selectedFontName]];
  NSString *fontFamily = font.name;
  NSString *content = font.content;
  if (font && font.isCustom && content) {
    [script addObject:term_appendUserCss(content)];
    fontFamily = [self _detectFontFamilyFromContent:content] ?: font.name;
  }
  
  [script addObject:@"function applyUserSettings() {"];
  {
    if (fontFamily) {
      [script addObject: term_setFontFamily(fontFamily)];
    }
    
    [script addObject:term_setBoldEnabled(params.enableBold)];
    [script addObject:term_setBoldAsBright(params.boldAsBright)];
    
    BKTheme *theme = [BKTheme withName: params.themeName ?: [BKDefaults selectedThemeName]];
    if (theme) {
      [script addObject:theme.content];
    }
    
    [script addObject:term_setFontSize(params.fontSize == 0 ? [BKDefaults selectedFontSize] : @(params.fontSize))];
    
    [script addObject: term_setCursorBlink([BKDefaults isCursorBlink])];
  }
  [script addObject:@"};"];

  [script addObject:term_init()];

  return [[WKUserScript alloc] initWithSource:
          [script componentsJoinedByString:@"\n"]
                                injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                             forMainFrameOnly:YES];
}

- (void)setIme:(NSString *)imeText completionHandler:(void (^ _Nullable)(_Nullable id, NSError * _Nullable error))completionHandler
{
  [_webView evaluateJavaScript:term_setIme(imeText) completionHandler:completionHandler];
}

- (void)terminate
{
  // Disconnect message handler
  [_webView.configuration.userContentController removeScriptMessageHandlerForName:@"interOp"];
}

@end
