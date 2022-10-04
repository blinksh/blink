////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2019 Blink Mobile Shell Project
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
#import "BKFont.h"
#import "BKTheme.h"
#import "TermJS.h"
#import <AVFoundation/AVFoundation.h>

#import "Blink-Swift.h"

NSString * TermViewReadyNotificationKey = @"TermViewReadyNotificationKey";
NSString * TermViewBrowserReadyNotificationKey = @"TermViewBrowserReadyNotificationKey";

struct winsize __winSizeFromJSON(NSDictionary *json) {
  struct winsize res;
  res.ws_col = [json[@"cols"] integerValue];
  res.ws_row = [json[@"rows"] integerValue];
  res.ws_xpixel = 0;
  res.ws_ypixel = 0;
  
  return res;
}

@interface TermView () <WKScriptMessageHandler, WKUIDelegate, WKNavigationDelegate, UIGestureRecognizerDelegate>
@end

@implementation TermView {
  WKWebViewGesturesInteraction *_gestureInteraction;
  
  BOOL _jsIsBusy;
  dispatch_queue_t _jsQueue;
  NSMutableString *_jsBuffer;
  CGRect _currentBounds;
  UIEdgeInsets _currentAdditionalInsets;
  NSTimer *_layoutDebounceTimer;
  
  UIView *_coverView;
  UIView *_parentScrollView;
  NSInteger _touchID;
  NSMutableArray *_touchesArray;
}


- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];

  if (!self) {
    return self;
  }
  _touchID = 1000;
  
  _selectionRect = CGRectZero;
  _layoutDebounceTimer = nil;
  _currentBounds = CGRectZero;
  _jsQueue = dispatch_queue_create(@"TermView.js".UTF8String, DISPATCH_QUEUE_SERIAL);
  _jsBuffer = [[NSMutableString alloc] init];
  _touchesArray = [[NSMutableArray alloc] init];

  [self _addWebView];
  _coverView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
  [self addSubview:_coverView];
  _coverView.backgroundColor = [UIColor blackColor];
  
  return self;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
  if (!backgroundColor) {
    return;
  }
  [super setBackgroundColor:backgroundColor];
  _webView.backgroundColor = backgroundColor;
  _coverView.backgroundColor = backgroundColor;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  
  _coverView.frame = self.bounds;
  [self bringSubviewToFront:_coverView];
  
  [_layoutDebounceTimer invalidate];
  
  if (CGRectEqualToRect(_currentBounds, CGRectZero)) {
    [self _actualLayoutSubviews];
    return;
  }
  
  if (CGRectEqualToRect(_currentBounds, self.bounds) && UIEdgeInsetsEqualToEdgeInsets(_currentAdditionalInsets, self.additionalInsets)) {
    return;
  }
  
  __weak typeof(self) weakSelf = self;
  _layoutDebounceTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 repeats:NO block:^(NSTimer * _Nonnull timer) {
    [weakSelf _actualLayoutSubviews];
  }];
}

- (void)_actualLayoutSubviews {
  CGRect webViewFrame = [self webViewFrame];
  
  if (!CGRectEqualToRect(_webView.frame, webViewFrame)) {
    _webView.frame = webViewFrame;
    _browserView.frame = webViewFrame;
    if (_browserView) {
      [self bringSubviewToFront:_browserView];
    }
  }

  _currentBounds = self.bounds;
  _currentAdditionalInsets = self.additionalInsets;
}

- (UIEdgeInsets)safeAreaInsets {
  return UIEdgeInsetsZero;
}

- (CGRect)webViewFrame {
  if (_layoutLocked) {
    return _layoutLockedFrame;
  }
  return UIEdgeInsetsInsetRect(self.bounds, self.additionalInsets);
}

- (BOOL)canBecomeFirstResponder {
  return NO;
}

- (void)setUserInteractionEnabled:(BOOL)userInteractionEnabled {
  [super setUserInteractionEnabled:userInteractionEnabled];
  [_webView setUserInteractionEnabled:userInteractionEnabled];
}

- (void)_addWebView
{
  WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
  configuration.selectionGranularity = WKSelectionGranularityCharacter;
  configuration.defaultWebpagePreferences.preferredContentMode = WKContentModeDesktop;
//  configuration.limitsNavigationsToAppBoundDomains = YES;
  [configuration.userContentController addScriptMessageHandler:self name:@"interOp"];

  _webView = [[SmarterTermInput alloc] initWithFrame:[self webViewFrame] configuration:configuration];
  
   _gestureInteraction = [[WKWebViewGesturesInteraction alloc] initWithJsScrollerPath:@"t.scrollPort_.scroller_"];
  [_webView addInteraction:_gestureInteraction];
  
  [self addSubview:_webView];
}

- (void)addBrowserWebView:(NSURL *)url agent: (NSString *)agent injectUIO: (BOOL) injectUIO
{
  WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
  configuration.selectionGranularity = WKSelectionGranularityCharacter;
  configuration.defaultWebpagePreferences.preferredContentMode = WKContentModeDesktop;
  
  if (injectUIO) {
//    configuration.limitsNavigationsToAppBoundDomains = true;
    
    NSURL *scriptURL = [[NSBundle mainBundle] URLForResource:@"blink-uio.min" withExtension:@"js"];
    NSString * script =  [NSString stringWithContentsOfURL:scriptURL encoding:NSUTF8StringEncoding error:nil];
    WKUserScript *userScript = [[WKUserScript alloc] initWithSource:script injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly: YES];

    [configuration.userContentController addUserScript:userScript];
    [configuration.userContentController addScriptMessageHandler:self name:@"interOp"];
  }
//    configuration.limitsNavigationsToAppBoundDomains = YES;


  _browserView = [[VSCodeInput alloc] initWithFrame:[self webViewFrame] configuration:configuration];
  _browserView.customUserAgent =
//  [@"Mozilla/5.0 (Linux; Intel Mac OS X 10_15_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.1 Safari/605.1.15 " stringByAppendingString:agent];
  [@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.1 Safari/605.1.15 " stringByAppendingString:agent];

  NSLog(@"AGENT: %@", _browserView.customUserAgent);
  _browserView.UIDelegate = self;
  _browserView.navigationDelegate = self;
  
  if (injectUIO) {
  
    _browserView.scrollView.delaysContentTouches = NO;
    _browserView.scrollView.canCancelContentTouches = NO;
    [_browserView.scrollView setScrollEnabled:NO];
    [_browserView.scrollView.panGestureRecognizer setEnabled:NO];
  //   _gestureInteraction = [[WKWebViewGesturesInteraction alloc] initWithJsScrollerPath:@"t.scrollPort_.scroller_"];
  //  [_webView addInteraction:_gestureInteraction];
    
    UIPanGestureRecognizer *rec = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_pan:)];
    rec.maximumNumberOfTouches = 1;
    rec.cancelsTouchesInView = YES;
    rec.allowedScrollTypesMask = UIScrollTypeMaskAll;
    rec.allowedTouchTypes = @[@(UITouchTypeIndirectPointer)];
    rec.delegate = self;
    
    
    UITapGestureRecognizer *rec2 = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_pan2:)];
  //  rec2.maximumNumberOfTouches = 1;
    rec2.cancelsTouchesInView = YES;
    //  rec.allowedScrollTypesMask = UIScrollTypeMaskAll;
    rec2.allowedTouchTypes = @[@(UITouchTypeIndirectPointer)];
    rec2.delegate = self;
    
    [_browserView addGestureRecognizer:rec];
    [_browserView addGestureRecognizer:rec2];
      
  }

  [self addSubview:_browserView];
  [_browserView setOpaque:NO];
  _browserView.backgroundColor = [UIColor clearColor];
  _browserView.scrollView.backgroundColor = [UIColor clearColor];

  NSURLRequest *request = [NSURLRequest requestWithURL:url];
  [_browserView loadRequest:request];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
  decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
  NSURLCredential *cred = [[NSURLCredential alloc] initWithTrust:challenge.protectionSpace.serverTrust];

  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    if ([challenge.protectionSpace.host isEqual: @"localhost"]) {
      // Let localhost go through.
      completionHandler(NSURLSessionAuthChallengeUseCredential, cred);
      return;
    }
    
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, cred);
  });
  
}



- (void)webView:(WKWebView *)webView authenticationChallenge:(NSURLAuthenticationChallenge *)challenge shouldAllowDeprecatedTLS:(void (^)(BOOL))decisionHandler {
  decisionHandler(YES);
}

- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
 
  BrowserController * ctrl = [[BrowserController alloc] init];
  
  WKWebView * wv = [[WKWebView alloc] initWithFrame:ctrl.view.bounds configuration:configuration];
  
  [ctrl setWebView: wv];
  
  UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:ctrl];
  
  SpaceController *sp = (SpaceController *)self.window.rootViewController;
  // dispatch async presenting controller in order to avoid
  // 'NSInternalInconsistencyException', reason: 'Received request for main thread, but there is no current keyboard task executing.'
  // issue #1501
  dispatch_async(dispatch_get_main_queue(), ^{
    [sp showViewController:navCtrl sender:self];
    [wv becomeFirstResponder];
  });
  
  return wv;
}

- (NSString *)title {
  return _webView.title;
}

- (void)_pan: (UIPanGestureRecognizer *)rec {

//  _touchID = 12345;
  if (rec.state == UIGestureRecognizerStateBegan) {
    _touchID = (_touchID + 1 ) % 10000000;
//    [_touchesArray addObject:@(_touchID)];

    CGPoint point = [rec locationInView:rec.view];

    NSString *script = [NSString stringWithFormat:@"term_touch(\"touchstart\", %@, %@,  %@,  %@,  %@, %@);", @(_touchID), @(point.x), @(point.y), @(0), @(0), @(rec.modifierFlags)];

    [_browserView evaluateJavaScript:script completionHandler:nil];

    return;
  }
  if (rec.state == UIGestureRecognizerStateChanged) {
    CGPoint delta = [rec translationInView:rec.view];
    CGPoint point = [rec locationInView:rec.view];

    NSString *script = [NSString stringWithFormat:@"term_touch(\"touchmove\", %@, %@,  %@,  %@,  %@, %@);",  @(_touchID), @(point.x), @(point.y), @(delta.x), @(delta.y), @(rec.modifierFlags)];

    [_browserView evaluateJavaScript:script completionHandler:nil];
    return;
  }

  if (rec.state == UIGestureRecognizerStateEnded) {
    CGPoint delta = [rec translationInView:rec.view];
    CGPoint point = [rec locationInView:rec.view];

    NSString *script = [NSString stringWithFormat:@"term_touch(\"touchend\", %@, %@,  %@,  %@,  %@, %@);", @(_touchID), @(point.x), @(point.y), @(delta.x), @(delta.y), @(rec.modifierFlags)];

    [_browserView evaluateJavaScript:script completionHandler:nil];
    return;
  }

  if (rec.state == UIGestureRecognizerStateCancelled) {
    CGPoint point = [rec locationInView:rec.view];

    NSString *script = [NSString stringWithFormat:@"term_touch(\"touchcancel\", %@, %@,  %@,  %@,  %@, %@);", @(_touchID), @(point.x), @(point.y), @(0), @(0), @(rec.modifierFlags)];

    [_browserView evaluateJavaScript:script completionHandler:nil];
  }
}

- (void)_pan2: (UITapGestureRecognizer *)rec {

  _touchID = 12345;
  if (rec.state == UIGestureRecognizerStateBegan) {
//    _touchID = (_touchID + 1 ) % 10000000;
//    [_touchesArray addObject:@(_touchID)];

    CGPoint point = [rec locationInView:rec.view];

    NSString *script = [NSString stringWithFormat:@"term_touch(\"touchstart\", %@, %@,  %@,  %@,  %@, %@);", @(_touchID), @(point.x), @(point.y), @(0), @(0), @(rec.modifierFlags)];

    [_browserView evaluateJavaScript:script completionHandler:nil];

    return;
  }
  if (rec.state == UIGestureRecognizerStateChanged) {
    CGPoint point = [rec locationInView:rec.view];

    NSString *script = [NSString stringWithFormat:@"term_touch(\"touchmove\", %@, %@,  %@,  %@,  %@, %@);",  @(_touchID), @(point.x), @(point.y), @(0), @(0), @(rec.modifierFlags)];

    [_browserView evaluateJavaScript:script completionHandler:nil];
    return;
  }

  if (rec.state == UIGestureRecognizerStateEnded) {
    CGPoint point = [rec locationInView:rec.view];
    NSString *script = [NSString stringWithFormat:@"term_touch(\"touchstart\", %@, %@,  %@,  %@,  %@, %@);", @(_touchID), @(point.x), @(point.y), @(0), @(0), @(rec.modifierFlags)];
    [_browserView evaluateJavaScript:script completionHandler:nil];

    script = [NSString stringWithFormat:@"term_touch(\"touchend\", %@, %@,  %@,  %@,  %@, %@);", @(_touchID), @(point.x), @(point.y), @(0), @(0), @(rec.modifierFlags)];

    [_browserView evaluateJavaScript:script completionHandler:nil];
    return;
  }

  if (rec.state == UIGestureRecognizerStateCancelled) {
    CGPoint point = [rec locationInView:rec.view];

    NSString *script = [NSString stringWithFormat:@"term_touch(\"touchcancel\", %@, %@,  %@,  %@,  %@, %@);", @(_touchID), @(point.x), @(point.y), @(0), @(0), @(rec.modifierFlags)];

    [_browserView evaluateJavaScript:script completionHandler:nil];
  }
}

                         
- (void)loadWith:(MCPParams *)params;
{
  [_webView.configuration.userContentController addUserScript:[self _termInitScriptWith:params]];
  
  NSString *path = [[NSBundle mainBundle] pathForResource:@"term" ofType:@"html"];
  NSURL *url = [NSURL fileURLWithPath:path];
  [_webView loadFileURL:url allowingReadAccessToURL:url];
}

- (void)reloadWith:(MCPParams *)params;
{
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

- (void)restore
{
  [self _evalJSScript:term_restore()];
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
  _gestureInteraction.focused = YES;
//  [_webView evaluateJavaScript:term_focus() completionHandler:nil];
}

- (void)blur {
  _gestureInteraction.focused = NO;
//  [_webView evaluateJavaScript:term_blur() completionHandler:nil];
}

- (void)reportTouchInPoint:(CGPoint)point
{
  [_webView evaluateJavaScript:term_reportTouchInPoint(point) completionHandler:nil];
}


- (void)processKB:(NSString *)str {
  [self _evalJSScript: term_processKB(str)];
}

- (void)displayInput:(NSString *)input {
  [self _evalJSScript: term_displayInput(input, BKDefaults.isKeyCastsOn)];
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
    
    NSString *jsScript = term_write(buffer);
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
  } else if ([operation isEqualToString:@"alert"]) {
    [_device viewShowAlert:data[@"title"] andMessage:data[@"message"]];
  } else if ([operation isEqualToString:@"sendString"]) {
    [_device viewSendString:data[@"string"]];
  } else if ([operation isEqualToString:@"line"]) {
    [_device viewSubmitLine:data[@"text"]];
  } else if ([operation isEqualToString:@"api"]) {
    [_device viewAPICall:data[@"name"] andJSONRequest:data[@"request"]];
  } else if ([operation isEqualToString:@"notify"]) {
    [data setValue:[NSNumber numberWithInt:BKNotificationTypeOsc] forKey:@"type"];
    [_device viewNotify:data];
  } else if ([operation isEqualToString:@"browser-ready"]) {
    [_browserView ready];
    [[NSNotificationCenter defaultCenter] postNotificationName:TermViewBrowserReadyNotificationKey object:self];
  } else if ([operation isEqualToString:@"ring-bell"]) {
    [_device viewDidReceiveBellRing];
    
  }
}

- (void)_onTerminalReady:(NSDictionary *)data
{
  [_webView ready];
  NSArray *bgColor = data[@"bgColor"];
  if (bgColor && bgColor.count == 3) {
    UIColor *color = [UIColor colorWithRed:[bgColor[0] floatValue] / 255.0f
                                           green:[bgColor[1] floatValue] / 255.0f
                                            blue:[bgColor[2] floatValue] / 255.0f
                                           alpha:1];
    self.backgroundColor = color;
    _gestureInteraction.indicatorStyle = color.isLight ? UIScrollViewIndicatorStyleBlack : UIScrollViewIndicatorStyleWhite;
  } else {
    _gestureInteraction.indicatorStyle = UIScrollViewIndicatorStyleDefault;
  }
  
  [_device viewWinSizeChanged:__winSizeFromJSON(data[@"size"])];

  _isReady = YES;
  [_device viewIsReady];
  [[NSNotificationCenter defaultCenter] postNotificationName:TermViewReadyNotificationKey object:self];
    
//  if (_gestureInteraction.focused) {
//    [_webView evaluateJavaScript:term_focus() completionHandler:nil];
//  } else {
//    [_webView evaluateJavaScript:term_blur() completionHandler:nil];
//  }
  
  [UIView transitionFromView:_coverView toView:_webView duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve completion:^(BOOL finished) {
    [_coverView removeFromSuperview];
    _coverView = nil;
  }];
}

- (BOOL)isFocused {
  return _gestureInteraction.focused;
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
  _gestureInteraction.hasSelection = _hasSelection;
  
  if (_browserView) {
    return;
  }
  
  [_device viewSelectionChanged];
  
  UIMenuController * menu = [UIMenuController sharedMenuController];
  
  if (!_hasSelection) {
    [menu hideMenu];
    return;
  }
  
  NSMutableArray *items = [[NSMutableArray alloc] init];
  
  
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
  } else {
    [items addObject:[[UIMenuItem alloc] initWithTitle:@"Search"
                                                action:@selector(googleSelection:)]];
  }
  [items addObject:[[UIMenuItem alloc] initWithTitle:@"Share"
  action:@selector(shareSelection:)]];
  
  _selectionRect = CGRectFromString(data[@"rect"]);
  [menu setMenuItems:items];
#ifdef TARGET_OS_MACCATALYST
//  if (!menu.isMenuVisible) {
//    [menu showMenuFromView:self rect:_selectionRect];
//  }
#else
  [menu showMenuFromView:self rect:_selectionRect];
#endif
}

- (void)modifySideOfSelection
{
  [_webView evaluateJavaScript:term_modifySideSelection() completionHandler:nil];
}

- (void)modifySelectionInDirection:(NSString *)direction granularity:(NSString *)granularity
{
  [_webView evaluateJavaScript:term_modifySelection(direction, granularity) completionHandler:nil];
}

- (void)apiResponse:(NSString *)name response:(NSString *)response {
  [_webView evaluateJavaScript:term_apiResponse(name, response) completionHandler:nil];
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

- (void)googleSelection:(id)sender {
  
}

- (void)soSelection:(id)sender {
  
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
  NSString *text = _selectedText;
  if (text) {
    [UIPasteboard generalPasteboard].string = text;
  }
  UIMenuController * menu = [UIMenuController sharedMenuController];
  [menu hideMenuFromView:self];
  [self cleanSelection];
}

- (void)paste:(id)sender
{
  NSString *str = [UIPasteboard generalPasteboard].string;
  if (str) {
    if (_browserView) {
      [_browserView evaluateJavaScript:term_paste(str) completionHandler:nil];
    } else {
      [_webView evaluateJavaScript:term_paste(str) completionHandler:nil];
    }
  }
  
  [self cleanSelection];
}

- (NSString *)_detectFontFamilyFromContent:(NSString *)content
{
  NSRegularExpression *regex = [NSRegularExpression
                                regularExpressionWithPattern:@"font-family:\\s*([^;]+);"
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

- (WKUserScript *)_termInitScriptWith:(MCPParams *)params;
{
  NSMutableArray *script = [[NSMutableArray alloc] init];
  BOOL lockdownMode = [[NSUserDefaults.standardUserDefaults objectForKey:@"LDMGlobalEnabled"] boolValue];
  BKFont *font = lockdownMode ? nil : [BKFont withName: params.fontName ?: [BKDefaults selectedFontName]];
  NSString *fontFamily = font.name;
  NSString *content = font.content;
  if (font && font.isCustom && content) {
    [script addObject:term_appendUserCss(content)];
    fontFamily = [self _detectFontFamilyFromContent:content] ?: font.name;
  }
  
  [script addObject:@"function applyUserSettings() {"];
  {
    if (fontFamily) {
      [script addObject: term_setFontFamily(fontFamily, font.systemWide ? @"dom" : @"canvas")];
    }
    
    [script addObject:term_setBoldEnabled(params.enableBold)];
    [script addObject:term_setBoldAsBright(params.boldAsBright)];
    
    NSString *themeContent = [[BKTheme withName: params.themeName ?: [BKDefaults selectedThemeName]] content];
    if (themeContent) {
      [script addObject:themeContent];
    }
    
    [script addObject:term_setFontSize(params.fontSize == 0 ? [BKDefaults selectedFontSize] : @(params.fontSize))];
    
    [script addObject: term_setCursorBlink([BKDefaults isCursorBlink])];
  }
  [script addObject:@"};"];

  [script addObject:term_init(UIAccessibilityIsVoiceOverRunning(), lockdownMode)];

  return [[WKUserScript alloc] initWithSource:
          [script componentsJoinedByString:@"\n"]
                                injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                             forMainFrameOnly:YES];
}

- (void)applyTheme:(NSString *)themeName {
  NSString *themeContent = [[BKTheme withName: themeName ?: [BKDefaults selectedThemeName]] content];
  if (themeContent) {
    NSString *script = [NSString stringWithFormat:@"(function(){%@})();", themeContent];
    [_webView evaluateJavaScript:script completionHandler:nil];
  }
}

- (void)terminate
{
  _device = nil;
  // Disconnect message handler
  [_webView terminate];
  [_webView.configuration.userContentController removeScriptMessageHandlerForName:@"interOp"];
}

- (void)dealloc {
  [self terminate];
  [_webView removeInteraction:_gestureInteraction];
  _gestureInteraction = nil;
  [_layoutDebounceTimer invalidate];
  _layoutDebounceTimer = nil;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
  return YES;
}

@end
