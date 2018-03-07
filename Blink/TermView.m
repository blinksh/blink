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
  
  BOOL _focused;
  
  BOOL _jsIsBusy;
  BOOL _allowBuffering;
  dispatch_queue_t _jsQueue;
  NSMutableString *_jsBuffer;
}


- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];

  if (self) {
    
    _jsQueue = dispatch_queue_create(@"TermView.js".UTF8String, DISPATCH_QUEUE_SERIAL);
    _jsBuffer = [[NSMutableString alloc] init];
    _allowBuffering = YES;

    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self _addWebView];
  }

  return self;
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
  
  self.opaque = NO;
  _webView.opaque = NO;

  self.alpha = 0;
  _webView.alpha = 0;
  _webView.backgroundColor = [UIColor clearColor];
  self.backgroundColor = [UIColor clearColor];
  
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
  _webView.alpha = 1;
  self.opaque = YES;
  _webView.opaque = YES;
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
    
    if (_jsIsBusy && !_allowBuffering) {
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

- (void)writeB64:(NSData *)data
{
  dispatch_async(_jsQueue, ^{
    _allowBuffering = NO;
    NSString *jsScript = term_writeB64(data);
    dispatch_async(dispatch_get_main_queue(), ^{
      [_webView evaluateJavaScript: jsScript completionHandler:^(id result, NSError *error) {
        dispatch_async(_jsQueue, ^{
          _allowBuffering = YES;
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
    self.alpha = 1;
    if ([_termDelegate respondsToSelector:@selector(terminalIsReady:)]) {
      [_termDelegate terminalIsReady:data];
      
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
  } else if ([operation isEqualToString:@"sendString"]) {
    [_termDelegate write:data[@"string"]];
  }
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
