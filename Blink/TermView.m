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
#import "TermJS.h"

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

  UITapGestureRecognizer *_tapGesture;
  UIPinchGestureRecognizer *_pinchGesture;
  
  BOOL _shouldSkipPasteMenu;
  
  NSTimer *_pinchSamplingTimer;
  BOOL _focused;
  
  BOOL _jsIsBusy;
  dispatch_queue_t _jsQueue;
  NSMutableString *_jsBuffer;
  
  UIVisualEffectView *_overlayView;
  BOOL _readyToDelete;
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

- (BOOL)isDragging {
  return _webView.scrollView.panGestureRecognizer.state == UIGestureRecognizerStateRecognized;
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
  _webView.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
  _webView.scrollView.panGestureRecognizer.minimumNumberOfTouches = 2;
  _webView.scrollView.panGestureRecognizer.cancelsTouchesInView = NO;
  _webView.opaque = NO;
  _webView.backgroundColor = [UIColor clearColor];
  
  _webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  
  [self addSubview:_webView];
}

- (UIView *)_overlayView
{
  if (!_overlayView) {
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    _overlayView = [[UIVisualEffectView alloc] initWithEffect:effect];
    _overlayView.frame = self.bounds;
    UIBarButtonItem *btn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:nil];
    btn.tintColor = [UIColor redColor];
    UIToolbar * toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 50, 60)];
    toolbar.clipsToBounds = YES;
    toolbar.backgroundColor = [UIColor blackColor];
    toolbar.barTintColor = [UIColor blackColor];
    [toolbar setItems:@[btn]];
    [toolbar setBackgroundImage:[UIImage new]
      forToolbarPosition:UIToolbarPositionAny
      barMetrics:UIBarMetricsDefault];
    
    [toolbar setBackgroundColor:[UIColor clearColor]];
    toolbar.center = _webView.center;
    
    toolbar.transform = CGAffineTransformMakeScale(3.0, 3.0);
    [_overlayView.contentView addSubview:toolbar];
  }
  
  return _overlayView;
}

- (BOOL)readyToDelete
{
  return _readyToDelete;
}

- (void)setReadyToDelete:(BOOL)ready
{
  _readyToDelete = ready;
  if (ready) {
    UIView *overlay = [self _overlayView];
    [self addSubview:overlay];
    
    overlay.alpha = 0;
    
    [UIView animateWithDuration:0.3 animations:^{
      overlay.alpha = 0.6;
    }];
  } else {
    [UIView animateWithDuration:0.3 animations:^{
      _overlayView.alpha = 0;
    } completion:^(BOOL finished) {
      [_overlayView removeFromSuperview];
      _overlayView = nil;
    }];
  }
}

- (void)setFreezed:(BOOL)freezed
{
  BOOL enabled = !freezed;
  self.userInteractionEnabled = enabled;
  [_webView.scrollView setScrollEnabled:enabled];
  _webView.userInteractionEnabled = enabled;
  _pinchGesture.enabled = enabled;
  _tapGesture.enabled = enabled;
}

- (void)_addGestures
{
  
  if (!_tapGesture) {
    _tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_activeControl:)];
    [_tapGesture setNumberOfTapsRequired:1];
    _tapGesture.delegate = self;
    [_webView addGestureRecognizer:_tapGesture];
  }


  if (!_pinchGesture) {
    _pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(_handlePinch:)];
    _pinchGesture.delegate = self;
    [_webView addGestureRecognizer:_pinchGesture];
  
//    [_pinchGesture requireGestureRecognizerToFail:_webView.scrollView.panGestureRecognizer];
    [_pinchGesture requireGestureRecognizerToFail: _tapGesture];
  }
}

- (NSString *)title
{
  return _webView.title;
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
  [_webView evaluateJavaScript:term_focus() completionHandler:nil];
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
  
    _jsIsBusy = YES;
    
    NSString * buffer = _jsBuffer;
    _jsBuffer = [[NSMutableString alloc] init];
    
    NSString *jsScript = term_write(buffer);
    
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
    
  });
}


//  Since TermView is a WKScriptMessageHandler, it must implement the userContentController:didReceiveScriptMessage method. This is the method that is triggered each time 'interOp' is sent a message from the JavaScript code.
- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message
{
  NSDictionary *sentData = (NSDictionary *)message.body;
  NSString *operation = sentData[@"op"];
  NSDictionary *data = sentData[@"data"];

  if ([operation isEqualToString:@"selectionchange"]) {
    [self _handleSelectionChange:data];
  } else if ([operation isEqualToString:@"sigwinch"]) {
    if ([_termDelegate respondsToSelector:@selector(updateTermRows:Cols:)]) {
      [_termDelegate updateTermRows:data[@"rows"] Cols:data[@"cols"]];
    }
  } else if ([operation isEqualToString:@"terminalReady"]) {
    if ([_termDelegate respondsToSelector:@selector(terminalIsReady:)]) {
      [_termDelegate terminalIsReady:data[@"size"]];
      
      if (_focused) {
        [self focus];
      } else {
        [self blur];
      }
    }
  } else if ([operation isEqualToString:@"fontSizeChanged"]) {
    if ([_termDelegate respondsToSelector:@selector(fontSizeChanged:)]) {
      [_termDelegate fontSizeChanged:data[@"size"]];
    }
  } else if ([operation isEqualToString:@"copy"]) {
    [[UIPasteboard generalPasteboard] setString:data[@"content"]];
  }
}

- (void)_handleSelectionChange:(NSDictionary *)data
{
  _selectedText = data[@"text"];
  BOOL isSelectionEmpty = _selectedText.length == 0;
  _webView.scrollView.scrollEnabled = isSelectionEmpty;
  
  if (isSelectionEmpty) {
    return;
  }
  
  NSMutableArray *items = [[NSMutableArray alloc] init];
  UIMenuController * menu = [UIMenuController sharedMenuController];
  
  _detectedLink = [self _detectLinkInSelection:data];
  
  if (_detectedLink) {
    NSString *host = [_detectedLink host];
    [items addObject:[[UIMenuItem alloc] initWithTitle:[@"Copy " stringByAppendingString:host]
                                                action:@selector(copyLink:)]];
    
    [items addObject:[[UIMenuItem alloc] initWithTitle:[@"Open " stringByAppendingString:host]
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

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
  if (gestureRecognizer == _tapGesture) {
    return YES;
  }

  return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(nonnull UIGestureRecognizer *)otherGestureRecognizer
{
  if (gestureRecognizer == _pinchGesture && [otherGestureRecognizer isKindOfClass:[UISwipeGestureRecognizer class]]) {
    return YES;
  }
  return NO;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer == _tapGesture) {
    return _selectedText.length == 0;
  }
  return YES;
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

- (void)unselect:(id)sender
{
}


- (void)_activeControl:(UITapGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state != UIGestureRecognizerStateRecognized) {
        return;
    }
    
    if (!_focused) {
        [_termDelegate focus];
        return;
    }
    
    if (!_shouldSkipPasteMenu) {
        [self performSelector:@selector(_showPasteMenu) withObject:nil afterDelay:0.4];
    }
    _shouldSkipPasteMenu = !_shouldSkipPasteMenu;
}

- (void)_showPasteMenu
{
  UIMenuController * menu = [UIMenuController sharedMenuController];
  NSMutableArray *items = [[NSMutableArray alloc] init];
  
  [menu setMenuItems:items];
  [menu setTargetRect:CGRectMake(0, self.bounds.size.height - 10, self.bounds.size.width, 10) inView:self];
  [menu setMenuVisible:YES animated:YES];
}

- (void)_handlePinch:(UIPinchGestureRecognizer *)gestureRecognizer
{
  switch (gestureRecognizer.state) {
    case UIGestureRecognizerStateBegan:
      [_pinchSamplingTimer invalidate];
      _pinchSamplingTimer = [NSTimer scheduledTimerWithTimeInterval:0.2
                                                             target:self
                                                           selector:@selector(_pinchSampling:)
                                                           userInfo:nil repeats:YES];
      break;
    case UIGestureRecognizerStateEnded:
    case UIGestureRecognizerStateCancelled:
      [_pinchSamplingTimer invalidate];
      break;
    default:
      break;
  }
}

- (void)_pinchSampling:(NSTimer *)timer
{
  [_webView evaluateJavaScript: term_scale(_pinchGesture.scale)
             completionHandler:^(id _Nullable res, NSError * _Nullable error) {
    _pinchGesture.scale = 1;
  }];
}

- (void)copy:(id)sender
{
  [_webView copy:sender];
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
  if (font && font.isCustom && font.content) {
    [script addObject:term_appendUserCss(font.content)];
    fontFamily = [self _detectFontFamilyFromContent:font.content] ?: font.name;
  }
  
  [script addObject:@"function applyUserSettings() {"];
  {
    if (fontFamily) {
      [script addObject: term_setFontFamily(fontFamily)];
    }
    
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

- (void)terminate
{
  // Disconnect message handler
  [_webView.configuration.userContentController removeScriptMessageHandlerForName:@"interOp"];
}

@end
