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
#import "BLKDefaults.h"
#import "BKFont.h"
#import "BKTheme.h"
#import "TermJS.h"
#import "LayoutConstraintManager.h"
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


@interface TermView () <WKScriptMessageHandler, WKUIDelegate, WKNavigationDelegate, UIGestureRecognizerDelegate, UIEditMenuInteractionDelegate>
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
  
  id<UIInteraction> _editMenuIteraction;
  CGFloat _cmdScrollAccumulator;
}


- (instancetype)initWithFrame:(CGRect)frame termUIState:(TermUIState *)termUIState
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

  self.termUIState = termUIState;

  [self _addWebView];
  
  _coverView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
  _coverView.backgroundColor = [UIColor blackColor];
  [self addSubview:_coverView];
  
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
}


- (UIEdgeInsets)safeAreaInsets {
  // Should be unused
  NSAssert(true, @"Unused");
  return UIEdgeInsetsZero;
}

- (CGRect)webViewFrame {
  if (_layoutLocked) {
    return _layoutLockedFrame;
  }
  
  // With constraints, return the actual frame of the WebView
  return _webView.frame;
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
  if (@available(iOS 18.0, *)) {
    configuration.writingToolsBehavior = UIWritingToolsBehaviorNone;
  }
  configuration.selectionGranularity = WKSelectionGranularityCharacter;
  configuration.defaultWebpagePreferences.preferredContentMode = WKContentModeDesktop;
//  configuration.limitsNavigationsToAppBoundDomains = YES;
  [configuration.userContentController addScriptMessageHandler:self name:@"interOp"];

  _webView = [[SmarterTermInput alloc] initWithFrame:CGRectZero configuration:configuration];
  _webView.UIDelegate = self;
  
  if (@available(iOS 16.0, *)) {
    _editMenuIteraction = [[UIEditMenuInteraction alloc] initWithDelegate:self];
    [_webView addInteraction:_editMenuIteraction];
  }
  
   _gestureInteraction = [[WKWebViewGesturesInteraction alloc] initWithJsScrollerPath:@"t.scrollPort_.scroller_"];
  [_webView addInteraction:_gestureInteraction];
  
  [self addSubview:_webView];
}

- (void)didMoveToSuperview {
  [super didMoveToSuperview];
  
  // Setup constraints when view is added to superview (if not already done)
  [self setupWebViewConstraints];
}

- (void)didMoveToWindow {
  [super didMoveToWindow];
  
  [self setupWebViewConstraints];
}

- (void)setupWebViewConstraints {
  // Only setup if we haven't already set up constraints
  if (self.constraintManager) {
    return;
  }
  
  if (!self.window) {
    // Need a window to get keyboard layout guide
    return;
  }
  
  // Get current layout mode from stored termUIState
  BKLayoutMode layoutMode = BKLayoutModeDefault;
  if (self.termUIState) {
    layoutMode = self.termUIState.layoutMode;
    // Reset lock modes
    self.termUIState.layoutLocked = NO;
    self.termUIState.layoutLockedFrame = CGRectZero;
  }
  
  self.constraintManager = [LayoutConstraintManager managerForView:_webView
                                                        layoutMode:layoutMode 
                                                    keyboardGuide:self.keyboardLayoutGuide];
  
  // Setup browser view constraints to match web view
  if (_browserView) {
    _browserView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
      [_browserView.topAnchor constraintEqualToAnchor:_webView.topAnchor],
      [_browserView.leadingAnchor constraintEqualToAnchor:_webView.leadingAnchor],
      [_browserView.trailingAnchor constraintEqualToAnchor:_webView.trailingAnchor],
      [_browserView.bottomAnchor constraintEqualToAnchor:_webView.bottomAnchor]
    ]];
  }
}

- (void)addBrowserWebView:(NSURL *)url agent: (NSString *)agent injectUIO: (BOOL) injectUIO
{
  WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
  if (@available(iOS 18.0, *)) {
    configuration.writingToolsBehavior = UIWritingToolsBehaviorNone;
  }
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


  _browserView = [[VSCodeInput alloc] initWithFrame:CGRectZero configuration:configuration];
  _browserView.customUserAgent =
//  [@"Mozilla/5.0 (Linux; Intel Mac OS X 10_15_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.1 Safari/605.1.15 " stringByAppendingString:agent];
  [@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.1 Safari/605.1.15 " stringByAppendingString:agent];

  NSLog(@"AGENT: %@", _browserView.customUserAgent);
  _browserView.UIDelegate = self;
  _browserView.navigationDelegate = self;
  
  [self addSubview:_browserView];
  [_browserView setOpaque:NO];
  _browserView.backgroundColor = [UIColor clearColor];
  _browserView.scrollView.backgroundColor = [UIColor clearColor];
  
  // Setup browser view constraints to match web view
  _browserView.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [_browserView.topAnchor constraintEqualToAnchor:_webView.topAnchor],
    [_browserView.leadingAnchor constraintEqualToAnchor:_webView.leadingAnchor],
    [_browserView.trailingAnchor constraintEqualToAnchor:_webView.trailingAnchor],
    [_browserView.bottomAnchor constraintEqualToAnchor:_webView.bottomAnchor]
  ]];

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

  if (rec.modifierFlags & UIKeyModifierCommand) {
    if (rec.state == UIGestureRecognizerStateBegan) {
      _cmdScrollAccumulator = 0;
    } else if (rec.state == UIGestureRecognizerStateChanged) {
      CGPoint delta = [rec translationInView:rec.view];
      _cmdScrollAccumulator += delta.y;
      [rec setTranslation:CGPointZero inView:rec.view];
      CGFloat lineThreshold = 20.0;
      while (_cmdScrollAccumulator < -lineThreshold) {
        _cmdScrollAccumulator += lineThreshold;
        [self scrollLineUp];
      }
      while (_cmdScrollAccumulator > lineThreshold) {
        _cmdScrollAccumulator -= lineThreshold;
        [self scrollLineDown];
      }
    }
    return;
  }

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

- (void)load
{
  [_webView.configuration.userContentController addUserScript:[self _termInitScriptWithTermUIState:self.termUIState]];

  NSString *path = [[NSBundle mainBundle] pathForResource:@"term" ofType:@"html"];
  NSURL *url = [NSURL fileURLWithPath:path];
  [_webView loadFileURL:url allowingReadAccessToURL:url];
}

- (void)applyTermUIState:(TermUIState *)termUIState
{
  self.termUIState = termUIState;

  NSArray<NSString *> *commands = [self _jsCommandsForTermUIState:termUIState];
  NSString *js = [commands componentsJoinedByString:@"\n"];
  [_webView evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
    [self _syncTerminalState];
  }];

  if (termUIState.layoutMode != [self currentLayoutMode]) {
    [self _setLayoutMode:termUIState.layoutMode];
  }
  if (termUIState.layoutLocked && !self.layoutLocked) {
    self.layoutLockedFrame = termUIState.layoutLockedFrame;
    if (self.constraintManager) {
      [self.constraintManager setLayoutLocked:YES withFrame:termUIState.layoutLockedFrame];
    }
    self.layoutLocked = YES;
  } else if (!termUIState.layoutLocked && self.layoutLocked) {
    [self _unlockLayout];
  }
}

// Reads back terminal-side state after JS changes. Currently just bgColor,
// but could grow into a larger state dict as needed.
- (void)_syncTerminalState
{
  [_webView evaluateJavaScript:@"_colorComponents(t.scrollPort_.screen_.style.backgroundColor)"
             completionHandler:^(NSArray *bgColor, NSError *error) {
    if (bgColor && [bgColor count] == 3) {
      self.backgroundColor = [UIColor colorWithRed:[bgColor[0] floatValue] / 255.0f
                                             green:[bgColor[1] floatValue] / 255.0f
                                              blue:[bgColor[2] floatValue] / 255.0f
                                             alpha:1];
    }
  }];
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
  if (_layoutLocked) {
    return;
  }
  [_webView evaluateJavaScript:term_increaseFontSize() completionHandler:nil];
}

- (void)decreaseFontSize
{
  if (_layoutLocked) {
    return;
  }
  [_webView evaluateJavaScript:term_decreaseFontSize() completionHandler:nil];
}

- (void)resetFontSize
{
  if (_layoutLocked) {
    return;
  }

  [_webView evaluateJavaScript:term_setFontSize([BLKDefaults selectedFontSize]) completionHandler:nil];
}

- (void)scrollLineUp
{
  [_webView evaluateJavaScript:@"t.scrollLineUp();" completionHandler:nil];
}

- (void)scrollLineDown
{
  [_webView evaluateJavaScript:@"t.scrollLineDown();" completionHandler:nil];
}

- (void)setClipboardWrite:(BOOL)state {
  [_webView evaluateJavaScript:term_setClipboardWrite(state) completionHandler:nil];
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
  [self _evalJSScript: term_displayInput(input, BLKDefaults.isKeyCastsOn)];
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
    struct winsize newWinSize = __winSizeFromJSON(data);
    _termUIState.rows = newWinSize.ws_row;
    _termUIState.cols = newWinSize.ws_col;
    [_device viewWinSizeChanged:newWinSize];
  } else if ([operation isEqualToString:@"terminalReady"]) {
    [self _onTerminalReady:data];
  } else if ([operation isEqualToString:@"fontSizeChanged"]) {
    NSInteger size = [data[@"size"] integerValue];
    _termUIState.fontSize = size;
    [_device viewFontSizeChanged:size];
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

  [items addObject:[[UIMenuItem alloc] initWithTitle:@"Copy Raw"
                                              action:@selector(copyRaw:)]];

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

// Sanitize terminal selection for clipboard
// hterm selection may include row-padding spaces at EOL; those should not leak
// into the system clipboard as trailing whitespace.
static NSString * _sanitizeTextForClipboard(NSString *text) {
  if (!text || text.length == 0) {
    return @"";
  }

  // Replace \r\n with \n
  NSString *result = [text stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];

  // Remove trailing spaces/tabs before newlines
  NSRegularExpression *trailingEOL = [NSRegularExpression
    regularExpressionWithPattern:@"[ \\t]+\\n"
    options:0
    error:nil];
  result = [trailingEOL stringByReplacingMatchesInString:result
                                                  options:0
                                                    range:NSMakeRange(0, result.length)
                                             withTemplate:@"\n"];

  // Remove trailing spaces/tabs at end of text
  NSRegularExpression *trailingEnd = [NSRegularExpression
    regularExpressionWithPattern:@"[ \\t]+$"
    options:0
    error:nil];
  result = [trailingEnd stringByReplacingMatchesInString:result
                                                  options:0
                                                    range:NSMakeRange(0, result.length)
                                             withTemplate:@""];

  return result;
}

- (void)copy:(id)sender
{
  NSString *text = _selectedText;
  if (text) {
    [UIPasteboard generalPasteboard].string = _sanitizeTextForClipboard(text);
  }
  UIMenuController * menu = [UIMenuController sharedMenuController];
  [menu hideMenuFromView:self];
  [self cleanSelection];
}

- (void)copyRaw:(id)sender
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

- (void)pasteString:(NSString *)str {
  if (str) {
    if (_browserView) {
      [_browserView evaluateJavaScript:term_paste(str) completionHandler:nil];
    } else {
      [_webView evaluateJavaScript:term_paste(str) completionHandler:nil];
    }
  }
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

- (NSArray<NSString *> *)_jsCommandsForTermUIState:(TermUIState *)termUIState
{
  NSMutableArray *commands = [[NSMutableArray alloc] init];
  BOOL lockdownMode = [[NSUserDefaults.standardUserDefaults objectForKey:@"LDMGlobalEnabled"] boolValue];
  BKFont *selectedFont = [BKFont withName: termUIState.fontName ?: [BLKDefaults selectedFontName]];
  BKFont *font = (lockdownMode && selectedFont.isCustom) ? nil : selectedFont;
  NSString *fontFamily = font.name ?: (lockdownMode ? @"monospace" : nil);
  NSString *content = font.content;
  if (font && font.isCustom && content) {
    [commands addObject:term_appendUserCss(content)];
    fontFamily = [self _detectFontFamilyFromContent:content] ?: font.name;
  }

  if (fontFamily) {
    [commands addObject:term_setFontFamily(fontFamily, font.systemWide ? @"dom" : @"canvas")];
  }

  [commands addObject:term_setBoldEnabled(termUIState.enableBold)];
  [commands addObject:term_setBoldAsBright(termUIState.boldAsBright)];

  NSString *themeContent = [[BKTheme withName: termUIState.themeName ?: [BLKDefaults selectedThemeName]] content];
  if (themeContent) {
    [commands addObject:themeContent];
  }

  [commands addObject:term_setFontSize(termUIState.fontSize == 0 ? [BLKDefaults selectedFontSize] : @(termUIState.fontSize))];
  [commands addObject:term_setCursorBlink([BLKDefaults isCursorBlink])];

  return commands;
}

- (WKUserScript *)_termInitScriptWithTermUIState:(TermUIState *)termUIState;
{
  BOOL lockdownMode = [[NSUserDefaults.standardUserDefaults objectForKey:@"LDMGlobalEnabled"] boolValue];
  NSArray<NSString *> *commands = [self _jsCommandsForTermUIState:termUIState];

  NSMutableArray *script = [[NSMutableArray alloc] init];
  [script addObject:@"function applyUserSettings() {"];
  [script addObjectsFromArray:commands];
  [script addObject:@"};"];
  [script addObject:term_init(UIAccessibilityIsVoiceOverRunning(), lockdownMode)];

  return [[WKUserScript alloc] initWithSource:
          [script componentsJoinedByString:@"\n"]
                                injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                             forMainFrameOnly:YES];
}

- (void)applyTheme:(NSString *)themeName {
  NSString *themeContent = [[BKTheme withName: themeName ?: [BLKDefaults selectedThemeName]] content];
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

- (NSInteger)rows {
  return self.termUIState ? self.termUIState.rows : 0;
}

- (NSInteger)cols {
  return self.termUIState ? self.termUIState.cols : 0;
}

// Public methods for layout state
-(BKLayoutMode)currentLayoutMode {
  if (self.termUIState) {
    return self.termUIState.layoutMode;
  }
  return BKLayoutModeDefault;
}

-(BOOL)isLayoutLocked {
  return self.layoutLocked;
}

// Layout mode control methods
-(void)setLayoutModeFill {
  [self _setLayoutMode:BKLayoutModeFill];
}

-(void)setLayoutModeFit {
  [self _setLayoutMode:BKLayoutModeSafeFit];
}

-(void)setLayoutModeCover {
  [self _setLayoutMode:BKLayoutModeCover];
}

-(void)toggleLayoutLock {
  if (self.termUIState.layoutLocked) {
    [self _unlockLayout];
  } else {
    [self _lockLayout];
  }
}

// Private methods
-(void)_setLayoutMode:(BKLayoutMode)layoutMode {
  if (self.termUIState) {
    self.termUIState.layoutMode = layoutMode;
  }
  
  // If layout is locked, unlock it when changing layout mode
  if (self.termUIState.layoutLocked) {
    [self _unlockLayout];
  }
  
  // Trigger layout update
  [self setNeedsLayout];
  
  // Update constraints with new layout mode
  if (self.constraintManager) {
    [self.constraintManager updateLayoutMode:layoutMode];
  }
}

-(void)_lockLayout {
  if (self.termUIState) {
    self.termUIState.layoutLocked = true;
    self.termUIState.layoutLockedFrame = [self webViewFrame];
  }
  
  // Update local state
  self.layoutLockedFrame = [self webViewFrame];
  
  // Update constraint manager
  if (self.constraintManager) {
    [self.constraintManager setLayoutLocked:YES withFrame:[self webViewFrame]];
  }
  
  self.layoutLocked = true;
}

-(void)_unlockLayout {
  if (self.termUIState) {
    self.termUIState.layoutLocked = false;
    self.termUIState.layoutLockedFrame = CGRectZero;
  }
  
  // Update local state
  self.layoutLocked = false;
  
  // Update constraint manager
  if (self.constraintManager) {
    [self.constraintManager setLayoutLocked:NO withFrame:CGRectZero];
  }
  
  // Trigger layout update
  [self setNeedsLayout];
}

@end


@implementation TermView (UIEditMenuInteractionDelegate)

- (UIMenu *)editMenuInteraction:(UIEditMenuInteraction *)interaction menuForConfiguration:(UIEditMenuConfiguration *)configuration suggestedActions:(NSArray<UIMenuElement *> *)suggestedActions  API_AVAILABLE(ios(16.0)){
  
  NSMutableArray *actions = [[NSMutableArray alloc] init];
  
  if (_hasSelection) {
    if (_detectedLink) {
      NSString *urlName = [self _menuTitleFromNSURL: _detectedLink];
      NSMutableArray *urlActions = [[NSMutableArray alloc] init];
      
      [urlActions addObject:[UICommand commandWithTitle:@"Copy full URL" image: [UIImage systemImageNamed:@"doc.on.doc"]
                                                 action:@selector(copyLink:) propertyList: nil]];
      
      [urlActions addObject:[UICommand commandWithTitle:@"Open URL" image: [UIImage systemImageNamed:@"safari"]
                                                 action:@selector(openLink:) propertyList:nil]];
      
      UIMenu *urlMenu = [UIMenu menuWithTitle:urlName image:[UIImage systemImageNamed:@"link"]  identifier:nil options:UIMenuOptionsDisplayInline children: urlActions];
      
      
      [actions addObject:urlMenu];
      
    } else {
      [actions addObject:[UICommand commandWithTitle:@"Search" image: [UIImage systemImageNamed:@"safari"]
                                              action:@selector(googleSelection:) propertyList:nil]];
    }
  } else {
    NSMutableArray *layoutActions = [[NSMutableArray alloc] init];
    
    if ([[DeviceInfo shared] hasCorners]) {
      BKLayoutMode mode = [self currentLayoutMode];
      UICommand *fitCmd = [UICommand commandWithTitle:@"Fit" image: nil
                                               action:@selector(setLayoutModeFit) propertyList:nil];
      //      fitCmd.attributes = UIMenuElementAttributesKeepsMenuPresented;
      fitCmd.state = mode == BKLayoutModeSafeFit ? UIMenuElementStateOn : UIMenuElementStateOff;
      UICommand *fillCmd = [UICommand commandWithTitle:@"Fill" image: nil
                                                action:@selector(setLayoutModeFill) propertyList:nil];
      //      fillCmd.attributes = UIMenuElementAttributesKeepsMenuPresented;
      fillCmd.state = mode == BKLayoutModeFill ? UIMenuElementStateOn : UIMenuElementStateOff;
      UICommand *coverCmd = [UICommand commandWithTitle:@"Cover" image: nil
                                                 action:@selector(setLayoutModeCover) propertyList:nil];
      coverCmd.state = mode == BKLayoutModeCover ? UIMenuElementStateOn : UIMenuElementStateOff;
      //      coverCmd.attributes = UIMenuElementAttributesKeepsMenuPresented;
      UIMenu *layoutMenu = [UIMenu menuWithTitle:@"Mode" image:nil identifier:nil options:UIMenuOptionsDisplayInline children: @[ fitCmd, fillCmd, coverCmd ]];
      
      [layoutActions addObject:layoutMenu];
    }
    
    if ([self _isLayoutLocked]) {
      [layoutActions addObject:[UICommand commandWithTitle:@"Unlock" image: [UIImage systemImageNamed:@"lock.slash"]
                                                    action:@selector(_unlockLayout) propertyList:nil]];
    } else {
      [layoutActions addObject:[UICommand commandWithTitle:@"Lock" image: [UIImage systemImageNamed:@"lock"]
                                                    action:@selector(_lockLayout) propertyList:nil]];
    }
    
    UIMenu *layoutMenu = [UIMenu menuWithTitle:@"Layout" image:[UIImage systemImageNamed:@"squareshape.squareshape.dashed"] identifier:nil options:UIMenuOptionsSingleSelection children:layoutActions];
    
    [actions addObject:layoutMenu];
  }
  
  
  // Copy useful commands, skip cut: and replace paste: with pasteSelection:
  for (UIMenuElement *elem in suggestedActions) {
    if ([elem isKindOfClass:[UIMenu class]]) {
      UIMenu *menu = (UIMenu *)elem;
      if ([menu.identifier isEqual:UIMenuStandardEdit]) {
        NSMutableArray *editItems = [[NSMutableArray alloc] init];
        for (UIMenuElement *editElem in menu.children) {
          if ([editElem isKindOfClass:[UICommand class]]) {

            UICommand *cmd = (UICommand *)editElem;
            if (cmd.action == @selector(cut:)) {
              continue;
            } else if (cmd.action == @selector(paste:) && _hasSelection) {
              [editItems addObject:[UICommand commandWithTitle:@"Paste" image:[UIImage systemImageNamed:@"doc.on.clipboard"] action:@selector(pasteSelection:) propertyList:nil]];
            } else if (cmd.action == @selector(copy:) && _hasSelection) {
              [editItems addObject:editElem];
              [editItems addObject:[UICommand commandWithTitle:@"Copy Raw" image:[UIImage systemImageNamed:@"doc.on.doc.fill"] action:@selector(copyRaw:) propertyList:nil]];
            } else {
              [editItems addObject:editElem];
            }
          }
        }
        UIMenu *newMenu = [UIMenu menuWithTitle:menu.title image:menu.image identifier:menu.identifier options:menu.options children:editItems];
        newMenu.preferredElementSize = menu.preferredElementSize;
        [actions insertObject: newMenu atIndex:0];
        continue;
      }
      [actions addObject:elem];
    }
  }
  
  
  
  return [UIMenu menuWithChildren:actions];
}


- (bool)_isLayoutLocked {
  return self.layoutLocked;
}

- (void)setCmdKeyPressed:(BOOL)pressed {
  [_gestureInteraction setCmdKeyPressed:pressed];
}

@end
