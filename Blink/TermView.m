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

-(void)layoutMarginsDidChange
{
  
}

- (void)safeAreaInsetsDidChange
{
  
}

@end


@interface TermView () <UIGestureRecognizerDelegate, WKScriptMessageHandler>

@end


@implementation TermView {
  WKWebView *_webView;
  UITapGestureRecognizer *_tapBackground;
  UILongPressGestureRecognizer *_longPressBackground;
  UIPinchGestureRecognizer *_pinchGesture;
  
  NSTimer *_pinchSamplingTimer;
  BOOL _focused;
  
  BOOL _jsIsBusy;
  dispatch_queue_t _jsQueue;
  NSMutableString *_jsBuffer;
}


- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];

  if (self) {
    
    _jsQueue = dispatch_queue_create(@"TermView.js".UTF8String, DISPATCH_QUEUE_SERIAL);
    _jsBuffer = [[NSMutableString alloc] init];

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
  configuration.dataDetectorTypes = WKDataDetectorTypeNone;
  [configuration.userContentController addScriptMessageHandler:self name:@"interOp"];

  _webView = [[BLWebView alloc] initWithFrame:self.bounds configuration:configuration];
  [_webView.scrollView setScrollEnabled:NO];
  [_webView.scrollView setBounces:NO];
  _webView.scrollView.delaysContentTouches = NO;
  _webView.opaque = NO;
  _webView.backgroundColor = [UIColor clearColor];
  if (@available(iOS 11.0, *)) {
    _webView.insetsLayoutMarginsFromSafeArea = NO;
    _webView.scrollView.insetsLayoutMarginsFromSafeArea = NO;
  } else {
    // Fallback on earlier versions
  }
  
  _webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  
  [self addSubview:_webView];
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
  NSString *userScript = [self _termInitScript];
  
  NSString * initScript = @"";
  if (userScript) {
    userScript = [userScript stringByAppendingString:initScript];
  } else {
    userScript = initScript;
  }
  
  WKUserScript *script = [[WKUserScript alloc] initWithSource:userScript injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
  [_webView.configuration.userContentController addUserScript:script];
  
  NSString *path = [[NSBundle mainBundle] pathForResource:@"term" ofType:@"html"];
  NSURL *url = [NSURL fileURLWithPath:path];
  NSURLRequest *request = [NSURLRequest requestWithURL:url];
  
  [_webView loadRequest:request];
}

// Write data to terminal control
- (void)write:(NSString *)data
{
  dispatch_async(_jsQueue, ^{
    [_jsBuffer appendString:data];
    
    if (_jsIsBusy) {
      return;
    }
  
    _jsIsBusy = YES;
    
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
  if (gestureRecognizer == _pinchGesture && [otherGestureRecognizer isKindOfClass:[UISwipeGestureRecognizer class]]) {
    return YES;
  }
  return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
  if (gestureRecognizer == _tapBackground && [otherGestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
    // We cancel the one from the WebView from executing, as it will wait for this one to fail.
    // We return yes, to make sure that is understood.
    [otherGestureRecognizer requireGestureRecognizerToFail:gestureRecognizer];
    return YES;
  }
  if (gestureRecognizer == _longPressBackground && [otherGestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
    return YES;
  }

  return NO;
}

- (void)longPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer.state != UIGestureRecognizerStateRecognized) {
    return;
  }
  
  UIMenuController *menuController = [UIMenuController sharedMenuController];

  if (menuController.isMenuVisible) {
    [menuController setMenuVisible:NO animated:YES];
  } else {
    CGPoint touchPoint = [gestureRecognizer locationInView:self];
    CGRect targetRect = CGRectMake(touchPoint.x - 10, touchPoint.y - 10, 10, 10);
    
    [self _detectLinkInSelection: ^{
      [menuController setTargetRect: targetRect inView:self];
      
      NSMutableArray *items = [[NSMutableArray alloc] init];
      
      [items addObject:[[UIMenuItem alloc] initWithTitle:@"Paste"
                                                  action:@selector(yank:)]];
      
      if (_detectedLink) {
        NSString *host = [_detectedLink host];
        [items addObject:[[UIMenuItem alloc] initWithTitle:[@"Copy " stringByAppendingString:host]
                                                    action:@selector(copyLink:)]];
        
        [items addObject:[[UIMenuItem alloc] initWithTitle:[@"Open " stringByAppendingString:host]
                                                    action:@selector(openLink:)]];
      }
      
//      [items addObject:[[UIMenuItem alloc] initWithTitle:@"Unselect"
//                                                  action:@selector(unselect:)]];
//
      [menuController setMenuItems:items];
      [menuController setMenuVisible:YES animated:YES];
    }];
  }
}

- (void)_detectLinkInSelection:(void (^)()) block {
  _detectedLink = nil;
  [_webView evaluateJavaScript:@"term_getCurrentSelection();" completionHandler:^(id _Nullable res, NSError * _Nullable error) {
    if (error) {
      block();
      return;
    }
    _selectedText = res[@"text"];
    NSString *text = res[@"base"];
    NSInteger offset = [res[@"offset"] integerValue];
    
    if (text == nil || [text length] == 0) {
      block();
      return;
    }
    
    NSDataDetector * dataDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil];
    [dataDetector enumerateMatchesInString:text options:kNilOptions range:NSMakeRange(0, [text length])
        usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
          
      if (result == nil) {
        return;
      }
      NSURL *url = result.URL;
      
      if (url != nil && result.range.location <= offset && result.range.location + result.range.length >= offset) {
        _detectedLink = url;
        *stop = YES;
      }
    }];
    block();
  }];
}

- (void)cleanSelection
{
  [_webView evaluateJavaScript:@"term_cleanSelection();" completionHandler: nil];
}

- (void)copyLink:(id)sender
{
}

- (void)openLink:(id)sender
{
}

- (void)yank:(id)sender
{
  // just to remove warning in selector
}

- (void)unselect:(id)sender
{
}

- (void)activeControl:(UITapGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer.state != UIGestureRecognizerStateRecognized) {
    return;
  }
  
  [self focus];
  [_termDelegate focus];
  [self cleanSelection];
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

- (void)increaseFontSize
{
  [_webView evaluateJavaScript:@"term_increaseFontSize();" completionHandler:nil];
}

- (void)decreaseFontSize
{
  [_webView evaluateJavaScript:@"term_decreaseFontSize();" completionHandler:nil];
}

- (void)resetFontSize
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

- (void)setInputEnabled:(BOOL) enabled {
  
}

- (BOOL)rawMode {
  return YES;
}

- (NSString *)_termInitScript
{
  BKFont *font = [BKFont withName:[BKDefaults selectedFontName]];
  NSString *fontFamily = NULL;
  
  if (font) {
    fontFamily = font.name;
    if (![@"Menlo" isEqualToString:fontFamily]) {
      fontFamily = [fontFamily stringByAppendingString:@", Menlo"];
    }
  } else {
    fontFamily = @"Menlo";
  }
  
  NSMutableString *script = [[NSMutableString alloc] init];
  
  [script appendString:@"function applyUserSettings() {\n"];
  
  BKTheme *theme = [BKTheme withName:[BKDefaults selectedThemeName]];
  if (theme) {
    [script appendString:theme.content];
  }
  
  //  if (!_disableFontSizeSelection) {
  //    NSNumber *fontSize = [BKDefaults selectedFontSize];
  // TODO
//  [script appendString:[NSString stringWithFormat:@"\nterm_setFontSize('%ld');", (long)_sessionParameters.fontSize]];
  //  }
  
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
  
  
  [script appendString:@"\n};"];

//  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@[ fontFamily ] options:0 error:nil];
//  NSString *jsString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
//  NSString *jsScript = [NSString stringWithFormat:@"\n waitForFontFamily(%@[0], applyUserSetting)", jsString];
//
//  [script appendString:jsScript];
  [script appendString:@"\nterm_init();"];
//
  return script;
}

- (void)terminate
{
  // Disconnect message handler
  [_webView.configuration.userContentController removeScriptMessageHandlerForName:@"interOp"];
}




@end
