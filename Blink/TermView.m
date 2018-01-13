////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016 Blink Mobile Shell Project
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

#include <sys/ioctl.h>


#import "TermView.h"
#import "BKDefaults.h"
#import "BKSettingsNotifications.h"
#import "BKFont.h"
#import "BKTheme.h"

@implementation BLWebView

- (BOOL)canResignFirstResponder
{
  return NO;
}

- (BOOL)becomeFirstResponder
{
  return NO;
}

- (UIEdgeInsets)layoutMargins
{
  return UIEdgeInsetsZero;
}

- (NSDirectionalEdgeInsets)directionalLayoutMargins
{
  return NSDirectionalEdgeInsetsZero;
}

@end


@interface TermView () <UIGestureRecognizerDelegate, WKScriptMessageHandler, WKUIDelegate, WKNavigationDelegate>
@property UITapGestureRecognizer *tapBackground;
@property UILongPressGestureRecognizer *longPressBackground;
@property UIPinchGestureRecognizer *pinchGesture;
@end


@implementation TermView {
  
  UIView *cover;
  NSTimer *_pinchSamplingTimer;
  BOOL _focused;
  BOOL _pasteMenu;
  
  BOOL _jsIsBusy;
  dispatch_queue_t _jsQueue;
  NSMutableString *_jsBuffer;
  NSInteger _jsBufferCount;
  NSInteger _currentBufferUsed;
  NSInteger _maxBufferUsed;
  
}


- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];

  if (self) {
    
    _jsQueue = dispatch_queue_create(@"js".UTF8String, DISPATCH_QUEUE_SERIAL);
    _jsBuffer = [[NSMutableString alloc] init];
    _jsBufferCount = 0;

    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self _addWebView];
  }

  return self;
}

- (void)didMoveToWindow
{
  [super didMoveToWindow];
  
  if (self.window.screen == [UIScreen mainScreen]) {
    [self _addGestures];
  }
}

- (BOOL)canBecomeFirstResponder {
  return NO;
}

- (void)_addWebView
{
  WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
  configuration.selectionGranularity = WKSelectionGranularityCharacter;
  [configuration.userContentController addScriptMessageHandler:self name:@"interOp"];

  _webView = [[BLWebView alloc] initWithFrame:self.bounds configuration:configuration];
  [_webView.scrollView setScrollEnabled:NO];
  [_webView.scrollView setBounces:NO];
  _webView.scrollView.delaysContentTouches = NO;
  
  _webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  
  
  [self addSubview:_webView];
  
  
  self.backgroundColor = [UIColor greenColor];
  _webView.opaque = YES;
  _webView.backgroundColor = [UIColor yellowColor];
}

- (void)_addGestures
{
  if (!_tapBackground) {
    _tapBackground = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(activeControl:)];
    [_tapBackground setNumberOfTapsRequired:1];
    _tapBackground.delegate = self;
    [self addGestureRecognizer:_tapBackground];
  }

  if (!_longPressBackground) {
    _longPressBackground = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
    _longPressBackground.delegate = self;
    [self addGestureRecognizer:_longPressBackground];
  }

  if (!_pinchGesture) {
    _pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
    _pinchGesture.delegate = self;
    [self addGestureRecognizer:_pinchGesture];
  }
}


#pragma mark Terminal Control
- (void)setScrollEnabled:(BOOL)scroll
{
  [_webView.scrollView setScrollEnabled:NO];
}

- (void)setColumnNumber:(NSInteger)count
{
  [_webView evaluateJavaScript:[NSString stringWithFormat:@"term_setWidth(\"%ld\");", (long)count] completionHandler:nil];
}

- (void)setFontSize:(NSNumber *)newSize
{
  [_webView evaluateJavaScript:[NSString stringWithFormat:@"term_setFontSize(\"%@\");", newSize] completionHandler:nil];
}

- (void)clear
{
  [_webView evaluateJavaScript:@"term_clear();" completionHandler:nil];
}

- (void)loadTerminal
{
  NSString *userScript = [self termInitScript];
  
  NSString * initScript = @"\ndocument.fonts.ready.then(function() {term_decorate(document.getElementById('terminal'));});";
  if (userScript) {
    userScript = [userScript stringByAppendingString:initScript];
  } else {
    userScript = initScript;
  }
  
  WKUserScript *script = [[WKUserScript alloc] initWithSource:userScript injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
  [_webView.configuration.userContentController addUserScript:script];
  
  NSString *path = [[NSBundle mainBundle] pathForResource:@"term" ofType:@"html"];
  NSString *html = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
  
  html = [html stringByReplacingOccurrencesOfString:@"<!-- CSS -->" withString:[self termInitCss]];
  
  NSURL *baseUrl = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
  [_webView loadHTMLString:html baseURL:baseUrl];
}

// Write data to terminal control
- (void)write:(NSString *)data
{
  dispatch_async(_jsQueue, ^{
    [_jsBuffer appendString:data];
    
    if (_jsIsBusy) {
      _jsBufferCount++;
      _currentBufferUsed++;
      return;
    }
  
    _jsIsBusy = YES;
    
    _maxBufferUsed = MAX(_maxBufferUsed, _currentBufferUsed);
    _currentBufferUsed = 0;
    
    NSString * buffer = _jsBuffer;
    _jsBuffer = [[NSMutableString alloc] init];
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@[ buffer ] options:0 error:nil];
    NSString *jsString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSString *jsScript = [NSString stringWithFormat:@"term_write(%@[0]);", jsString];
    
    dispatch_async(dispatch_get_main_queue(), ^{
      [_webView evaluateJavaScript:jsScript completionHandler:^(id result, NSError *error) {
        dispatch_async(_jsQueue, ^{
          _jsIsBusy = NO;
          if (_jsBuffer.length > 0) {
            [self write:@""];
          }
        });
      }];
    });
    
  });
  
}

- (NSString *)title
{
  return _webView.title;
}

//  Since TermView is a WKScriptMessageHandler, it must implement the userContentController:didReceiveScriptMessage method. This is the method that is triggered each time 'interOp' is sent a message from the JavaScript code.
- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message
{
  NSDictionary *sentData = (NSDictionary *)message.body;
  NSString *operation = sentData[@"op"];
  NSDictionary *data = sentData[@"data"];

  if ([operation isEqualToString:@"sigwinch"]) {
    if ([_termDelegate respondsToSelector:@selector(updateTermRows:Cols:)]) {
      [_termDelegate updateTermRows:data[@"rows"] Cols:data[@"cols"]];
    }
  } else if ([operation isEqualToString:@"terminalReady"]) {
    if ([_termDelegate respondsToSelector:@selector(terminalIsReady:)]) {
      [_termDelegate terminalIsReady:data[@"size"]];
      _webView.frame = self.bounds;
      _webView.scrollView.contentInset = UIEdgeInsetsZero;
      _webView.scrollView.contentSize = self.bounds.size;
    }
    if (_focused) {
      [self focus];
    } else {
      [self blur];
    }
  } else if ([operation isEqualToString:@"fontSizeChanged"]) {
    if ([_termDelegate respondsToSelector:@selector(fontSizeChanged:)]) {
      [_termDelegate fontSizeChanged:data[@"size"]];
    }
  } else if ([operation isEqualToString:@"copy"]) {
    [[UIPasteboard generalPasteboard] setString:data[@"content"]];
  }
}

#pragma mark On-Screen keyboard - UIKeyInput


- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(nonnull UIGestureRecognizer *)otherGestureRecognizer
{
  if (gestureRecognizer == self.pinchGesture && [otherGestureRecognizer isKindOfClass:[UISwipeGestureRecognizer class]]) {
    return YES;
  }
  return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
  if (gestureRecognizer == self.tapBackground && [otherGestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
    // We cancel the one from the WebView from executing, as it will wait for this one to fail.
    // We return yes, to make sure that is understood.
    [otherGestureRecognizer requireGestureRecognizerToFail:gestureRecognizer];
    return YES;
  }
  if (gestureRecognizer == self.longPressBackground && [otherGestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
    return YES;
  }

  return NO;
}

- (void)longPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
//  if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
//    [_webView becomeFirstResponder];
//  }
}

- (void)activeControl:(UITapGestureRecognizer *)gestureRecognizer
{
//  if (!_focused) {
    [self focus];
    [_termDelegate focus];
    return;
//  }
//  if (![self isFirstResponder]) {
//    [self becomeFirstResponder];
//    return;
//  }
  
  if (_pasteMenu) {
    [[UIMenuController sharedMenuController]
      setMenuVisible:NO
            animated:YES];
  } else {
    CGRect targetRect = CGRectMake(0, self.bounds.size.height - 20, self.bounds.size.width, 10);

    [[UIMenuController sharedMenuController] setTargetRect: targetRect
                                                    inView:self];

    UIMenuItem *pasteItem = [[UIMenuItem alloc] initWithTitle:@"Paste"
                                                       action:@selector(yank:)];

    [[UIMenuController sharedMenuController]
      setMenuItems:@[ pasteItem ]];
    [[UIMenuController sharedMenuController]
      setMenuVisible:YES
            animated:YES];
  }
  _pasteMenu = !_pasteMenu;
}

- (void)handlePinch:(UIPinchGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
    [_webView evaluateJavaScript:@"term_scaleStart();" completionHandler:nil];
    if (_pinchSamplingTimer) {
      [_pinchSamplingTimer invalidate];
    }

    _pinchSamplingTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(pinchSampling:) userInfo:nil repeats:YES];
    [_pinchSamplingTimer fire];
  }
  
  if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
    [_pinchSamplingTimer invalidate];    
  }
}

- (void)pinchSampling:(NSTimer *)timer
{
  [_webView evaluateJavaScript:[NSString stringWithFormat:@"term_scale(%f);", _pinchGesture.scale] completionHandler:nil];
}

- (void)focus {
  _focused = YES;
  [_webView evaluateJavaScript:@"term_focus();" completionHandler:nil];
}

- (void)blur
{
  _focused = NO;
  [_webView evaluateJavaScript:@"term_blur();" completionHandler:nil];
}


- (void)loadTerminalFont:(NSString *)familyName fromCSS:(NSString *)cssPath
{
  [_webView evaluateJavaScript:[NSString stringWithFormat:@"term_loadFontFromCss(\"%@\", \"%@\");", cssPath, familyName] completionHandler:nil];
}

- (void)loadTerminalThemeJS:(NSString *)themeContent
{
  [_webView evaluateJavaScript:themeContent completionHandler:nil];
}


- (void)loadTerminalFont:(NSString *)familyName cssFontContent:(NSString *)cssContent
{
  cssContent = [NSString stringWithFormat:@"data:text/css;utf-8,%@", cssContent];

  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@[ cssContent ] options:0 error:nil];
  NSString *jsString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
  NSString *jsScript = [NSString stringWithFormat:@"term_loadFontFromCss(%@[0], \"%@\")", jsString, familyName];
  
  [_webView evaluateJavaScript:jsScript completionHandler:nil];
}

- (void)setCursorBlink:(BOOL)state
{
  NSString *jsScript = [NSString stringWithFormat:@"term_setCursorBlink(%@)", state ? @"true" : @"false"];
  [_webView evaluateJavaScript:jsScript completionHandler:nil];
}

- (void)reset
{
  [_webView evaluateJavaScript:@"term_reset();" completionHandler:nil];
}

- (void)increaseFontSize:(UIKeyCommand *)cmd
{
  [_webView evaluateJavaScript:@"term_increaseFontSize();" completionHandler:nil];
}

- (void)decreaseFontSize:(UIKeyCommand *)cmd
{
  [_webView evaluateJavaScript:@"term_decreaseFontSize();" completionHandler:nil];
}

- (void)resetFontSize:(UIKeyCommand *)cmd
{
  [_webView evaluateJavaScript:@"term_resetFontSize();" completionHandler:nil];
}

- (void)copy:(id)sender
{
  [_webView copy:sender];
}

- (void)setRawMode:(BOOL)raw
{
  
}

- (BOOL)rawMode {
  return YES;
}

- (NSString *)termInitCss
{
  BKFont *font = [BKFont withName:[BKDefaults selectedFontName]];
  if (font) {
//    [script appendString:[NSString stringWithFormat:@"\nterm_setFontFamily('%@');", font.name]];
    if (font.isCustom) {
      return font.content;
//      NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@[ font.content ] options:0 error:nil];
//      NSString *jsString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
//      //      NSString *jsScript = [NSString stringWithFormat:@"\nterm_appendUserCss(%@[0])", jsString];
//      [script appendString:jsScript];
//      //      NSString *jsScript = [NSString stringWithFormat:@"term_loadFontFromCSS(%@[0], \"%@\")", jsString, familyName];
//      //      [_terminal loadTerminalFont:font.name cssFontContent:font.content];
    }
  }
  return @"";
}

- (NSString *)termInitScript
{
  NSMutableString *script = [[NSMutableString alloc] init];
  
  BKTheme *theme = [BKTheme withName:[BKDefaults selectedThemeName]];
  if (theme) {
    [script appendString:theme.content];
  }
  
  //  if (!_disableFontSizeSelection) {
  //    NSNumber *fontSize = [BKDefaults selectedFontSize];
  // TODO
//  [script appendString:[NSString stringWithFormat:@"\nterm_setFontSize('%ld');", (long)_sessionParameters.fontSize]];
  //  }
  
  BKFont *font = [BKFont withName:[BKDefaults selectedFontName]];
  if (font) {
    [script appendString:[NSString stringWithFormat:@"\nterm_setFontFamily('%@');", font.name]];
    if (font.isCustom) {
//      NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@[ font.content ] options:0 error:nil];
//      NSString *jsString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
//      NSString *jsScript = [NSString stringWithFormat:@"\nterm_appendUserCss(%@[0])", jsString];
//      [script appendString:jsScript];
      //      NSString *jsScript = [NSString stringWithFormat:@"term_loadFontFromCSS(%@[0], \"%@\")", jsString, familyName];
      //      [_terminal loadTerminalFont:font.name cssFontContent:font.content];
    }
  }
  
  [script appendString:[NSString stringWithFormat:@"\n;term_setCursorBlink(%@);", [BKDefaults isCursorBlink] ? @"true" : @"false"]];
  
  return script;
}




@end
