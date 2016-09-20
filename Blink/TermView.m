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

#import "SmartKeys.h"
#import "SmartKeysView.h"
#import "TermView.h"

static NSDictionary *CTRLCodes = nil;
static NSDictionary *FModifiers = nil;
static NSDictionary *FKeys = nil;
static NSString *SS3 = nil;
static NSString *CSI = nil;

NSString *const TermViewCtrlSeq = @"ctrlSeq:";
NSString *const TermViewEscSeq = @"escSeq:";
NSString *const TermViewCursorFuncSeq = @"cursorSeq:";
NSString *const TermViewFFuncSeq = @"fkeySeq:";

typedef enum {
  SpecialCursorKeyHome = 0,
  SpecialCursorKeyEnd,
  SpecialCursorKeyPgUp,
  SpecialCursorKeyPgDown
} SpecialCursorKeys;

@interface CC : NSObject

+ (void)initialize;
+ (NSString *)CTRL:(NSString *)c;
+ (NSString *)ESC:(NSString *)c;
+ (NSString *)KEY:(NSString *)c;

@end

@implementation CC
+ (void)initialize
{
  CTRLCodes = @{
    @" " : @"\x00",
    @"[" : @"\x1B",
    @"]" : @"\x1D",
    @"\\" : @"\x1C",
    @"^" : @"\x1E",
    @"_" : @"\x1F"
  };
  FModifiers = @{
    @0 : @0,
    [NSNumber numberWithInt:UIKeyModifierShift] : @2,
    [NSNumber numberWithInt:UIKeyModifierAlternate] : @3,
    [NSNumber numberWithInt:UIKeyModifierShift | UIKeyModifierAlternate] : @4,
    [NSNumber numberWithInt:UIKeyModifierControl] : @5,
    [NSNumber numberWithInt:UIKeyModifierShift | UIKeyModifierControl] : @6,
    [NSNumber numberWithInt:UIKeyModifierAlternate | UIKeyModifierControl] : @7,
    [NSNumber numberWithInt:UIKeyModifierShift | UIKeyModifierAlternate | UIKeyModifierControl] : @8
  };
  FKeys = @{
    UIKeyInputUpArrow : @"A",
    UIKeyInputDownArrow : @"B",
    UIKeyInputRightArrow : @"C",
    UIKeyInputLeftArrow : @"D"
  };

  SS3 = [self ESC:@"O"];
  CSI = [self ESC:@"["];
}

+ (NSDictionary *)FModifiers
{
  return FModifiers;
}

+ (NSString *)CTRL:(NSString *)c
{
  NSString *code;

  if ((code = [CTRLCodes objectForKey:c]) != nil) {
    return code;
  } else {
    char x = [c characterAtIndex:0];
    return [NSString stringWithFormat:@"%c", x - 'a' + 1];
  }
}

+ (NSString *)ESC:(NSString *)c
{
  if (c == nil || [c length] == 0 || c == UIKeyInputEscape) {
    return @"\x1B";
  } else {
    return [NSString stringWithFormat:@"\x1B%c", [c characterAtIndex:0]];
  }
}

+ (NSString *)KEY:(NSString *)c
{
  return [CC KEY:c MOD:0 RAW:NO];
}

+ (NSString *)KEY:(NSString *)c MOD:(NSInteger)m RAW:(BOOL)raw
{
  NSArray *out;

  if ([FKeys.allKeys containsObject:c]) {
    if (m) {
      out = @[ CSI, FKeys[c] ];
    } else if (raw) {
      return [NSString stringWithFormat:@"%@%@", SS3, FKeys[c]];
    } else {
      return [NSString stringWithFormat:@"%@%@", CSI, FKeys[c]];
    }
  } else if (c == UIKeyInputEscape) {
    return @"\x1B";
  } else if ([c isEqual:@"\n"]) {
    return @"\r";
  }

  if (m) {
    NSString *modSeq = [NSString stringWithFormat:@"1;%@", FModifiers[[NSNumber numberWithInteger:m]]];
    return [out componentsJoinedByString:modSeq];
  }

  return c;
}

+ (NSString *)CURSOR:(SpecialCursorKeys)c
{
  switch (c) {
    case SpecialCursorKeyHome:
      return [NSString stringWithFormat:@"%@H", CSI];
    case SpecialCursorKeyEnd:
      return [NSString stringWithFormat:@"%@F", CSI];
    case SpecialCursorKeyPgUp:
      return [NSString stringWithFormat:@"%@5~", CSI];
    case SpecialCursorKeyPgDown:
      return [NSString stringWithFormat:@"%@6~", CSI];
  }
}

+ (NSString *)FKEY:(NSInteger)number
{
  switch (number) {
    case 1:
      return [NSString stringWithFormat:@"%@P", SS3];
    case 2:
      return [NSString stringWithFormat:@"%@Q", SS3];
    case 3:
      return [NSString stringWithFormat:@"%@R", SS3];
    case 4:
      return [NSString stringWithFormat:@"%@S", SS3];
    case 5:
      return [NSString stringWithFormat:@"%@15~", CSI];
    case 6:
    case 7:
    case 8:
      return [NSString stringWithFormat:@"%@1%ld~", CSI, number + 1];
    case 9:
    case 10:
      return [NSString stringWithFormat:@"%@2%ld~", CSI, number - 9];
    default:
      return nil;
  }
}
@end

@interface TerminalView () <UIKeyInput, UIGestureRecognizerDelegate, WKScriptMessageHandler>
@property UITapGestureRecognizer *tapBackground;
@property UILongPressGestureRecognizer *longPressBackground;
@property UIPinchGestureRecognizer *pinchGesture;
@end

@implementation TerminalView {
  WKWebView *_webView;
  // option + e on iOS lets introduce an accented character, that we override
  BOOL _disableAccents;
  BOOL _dismissInput;
  BOOL _pasteMenu;
  NSMutableArray *_kbdCommands;
  SmartKeys *_smartKeys;
  UIView *cover;
  NSTimer *_pinchSamplingTimer;
  BOOL _raw;
  BOOL _inputEnabled;
  NSMutableDictionary *_controlKeys;
  NSMutableDictionary *_functionKeys;
  NSMutableDictionary *_functionTriggerKeys;
  NSString *_specialFKeysRow;
}

- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];

  if (self) {
    _inputEnabled = YES;
    self.inputAssistantItem.leadingBarButtonGroups = @[];
    self.inputAssistantItem.trailingBarButtonGroups = @[];

    [self addWebView];
    [self resetDefaultControlKeys];
    [self addGestures];
    [self configureNotifications];
  }

  return self;
}

- (void)addWebView
{
  WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
  [configuration.userContentController addScriptMessageHandler:self name:@"interOp"];
    
  _webView = [[WKWebView alloc] initWithFrame:self.frame configuration:configuration];
  [self addSubview:_webView];

  _webView.opaque = NO;
  _webView.translatesAutoresizingMaskIntoConstraints = NO;
  [_webView.topAnchor constraintEqualToAnchor:self.topAnchor].active = YES;
  [_webView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor].active = YES;
  [_webView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor].active = YES;
  [_webView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor].active = YES;
}

- (void)addGestures
{
    _tapBackground = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(activeControl:)];
    [_tapBackground setNumberOfTapsRequired:1];
    _tapBackground.delegate = self;
    [self addGestureRecognizer:_tapBackground];

    _longPressBackground = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
    _longPressBackground.delegate = self;
    [self addGestureRecognizer:_longPressBackground];

    _pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
    _pinchGesture.delegate = self;
    [self addGestureRecognizer:_pinchGesture];
}

- (void)configureNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)resetDefaultControlKeys
{
  _controlKeys = [[NSMutableDictionary alloc] init];
  _functionKeys = [[NSMutableDictionary alloc] init];
  _functionTriggerKeys = [[NSMutableDictionary alloc] init];
  _specialFKeysRow = @"1234567890";
  [self setKbdCommands];
}

#pragma mark Terminal Control
- (void)setScrollEnabled:(BOOL)scroll
{
  [_webView.scrollView setScrollEnabled:NO];
}

- (void)setRawMode:(BOOL)raw
{
  _raw = raw;
}

- (BOOL)rawMode
{
  return _raw;
}

- (void)setInputEnabled:(BOOL)enabled
{
  _inputEnabled = enabled;
  if (!enabled && self.isFirstResponder) {
    [self resignFirstResponder];
  }
}

- (void)setColumnNumber:(NSInteger)count
{
  [_webView evaluateJavaScript:[NSString stringWithFormat:@"setWidth(\"%ld\");", (long)count] completionHandler:nil];
}

- (void)setFontSize:(NSNumber *)newSize
{
  [_webView evaluateJavaScript:[NSString stringWithFormat:@"setFontSize(\"%@\");", newSize] completionHandler:nil];
}

- (void)clear
{
  [_webView evaluateJavaScript:[NSString stringWithFormat:@"clear();"] completionHandler:nil];
}

- (void)loadTerminal
{
  NSString *path = [[NSBundle mainBundle] pathForResource:@"term" ofType:@"html"];
  NSURL *url = [NSURL fileURLWithPath:path];
  // NSURL *url = [NSURL URLWithString:@"http://www.apple.com"];
  NSURLRequest *request = [NSURLRequest requestWithURL:url];
  [_webView loadRequest:request];
}

// Write data to terminal control
- (void)write:(NSString *)data
{
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@[ data ] options:0 error:nil];
  NSString *jsString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
  NSString *jsScript = [NSString stringWithFormat:@"write_to_term(%@[0])", jsString];

  [_webView evaluateJavaScript:jsScript completionHandler:nil];
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
    if ([self.delegate respondsToSelector:@selector(updateTermRows:Cols:)]) {
      [self.delegate updateTermRows:data[@"rows"] Cols:data[@"columns"]];
    }
  } else if ([operation isEqualToString:@"terminalReady"]) {
    if ([self.delegate respondsToSelector:@selector(terminalIsReady)]) {
      [self.delegate terminalIsReady];
    } 
  } else if ([operation isEqualToString:@"fontSizeChanged"]) {
    if ([self.delegate respondsToSelector:@selector(fontSizeChanged:)]) {
      [self.delegate fontSizeChanged:data[@"size"]];
    }
  } else if ([operation isEqualToString:@"copy"]) {
    [[UIPasteboard generalPasteboard] setString:data[@"content"]];
  }
}

#pragma mark On-Screen keyboard - UIKeyInput
- (UIKeyboardAppearance)keyboardAppearance
{
  return UIKeyboardAppearanceDark;
}
- (UITextAutocorrectionType)autocorrectionType
{
  return UITextAutocorrectionTypeNo;
}

- (UIView *)inputAccessoryView
{
  return [_smartKeys view];
}

- (void)keyboardWillHide:(NSNotification *)sender
{
  // Always hide the AccessoryView.
  self.inputAccessoryView.hidden = YES;
  //_capsMapped = YES;
  // If keyboard hides, then become first responder. This ensures there is a responder for the long focus events.
  //[self becomeFirstResponder];
}

- (void)keyboardWillShow:(NSNotification *)sender
{
  UIView *iaView = self.inputAccessoryView;

  CGRect frame = [sender.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
  // Not needed, since iOS 8.0 respects the coordinates.
  //CGRect inViewFrame = [self.view convertRect:frame fromView:nil];
  CGRect bounds = self.bounds;
  CGRect intersection = CGRectIntersection(frame, bounds);

  // If the intersection is only the accesoryView, we have a external keyboard
  if (intersection.size.height == [iaView frame].size.height) {
    iaView.hidden = YES;
  } else {
    //_capsMapped = NO;
    iaView.hidden = NO;
  }
}

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
  if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
    [_webView becomeFirstResponder];
  }
}

- (void)activeControl:(UITapGestureRecognizer *)gestureRecognizer
{
  if (![self isFirstResponder]) {
    [self becomeFirstResponder];
  } else {
    if (_pasteMenu) {
      [[UIMenuController sharedMenuController]
        setMenuVisible:NO
              animated:YES];
    } else {
      [[UIMenuController sharedMenuController] setTargetRect:self.frame
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
}

- (void)handlePinch:(UIPinchGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
    //_lastPinchScale = _webView.scrollView.zoomScale;
    [_webView evaluateJavaScript:@"scaleTermStart();" completionHandler:nil];
    if (_pinchSamplingTimer)
      [_pinchSamplingTimer invalidate];

    _pinchSamplingTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(pinchSampling:) userInfo:nil repeats:YES];
    [_pinchSamplingTimer fire];
  }

  if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
    [_pinchSamplingTimer invalidate];    
  }
}

- (void)pinchSampling:(NSTimer *)timer
{
  [_webView evaluateJavaScript:[NSString stringWithFormat:@"scaleTerm(%f);", _pinchGesture.scale] completionHandler:nil];
}

- (BOOL)canBecomeFirstResponder
{
  if (!_inputEnabled) {
    return NO;
  }

  return YES;
}

- (BOOL)canResignFirstResponder
{
  return YES;
}

- (BOOL)becomeFirstResponder
{
  if (!_smartKeys) {
    _smartKeys = [[SmartKeys alloc] init];
  }

  _smartKeys.textInputDelegate = self;
  cover.hidden = YES;

  [_webView evaluateJavaScript:@"focusTerm();" completionHandler:nil];
  return [super becomeFirstResponder];
}

- (BOOL)resignFirstResponder
{
  [_webView evaluateJavaScript:@"blurTerm();" completionHandler:nil];
  return [super resignFirstResponder];
}

- (BOOL)hasText
{
  return YES;
}

- (void)deleteBackward
{
  // Send a delete backward key to the buffer
  [_delegate write:@"\x7f"];
}

- (void)insertText:(NSString *)text
{
  if (_disableAccents) {
    // If the accent switch is on, the next character should remove them.
    //CFStringTransform((__bridge CFMutableStringRef)mtext, nil, kCFStringTransformStripCombiningMarks, NO);
    text = [[NSString alloc] initWithData:[text dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES] encoding:NSASCIIStringEncoding];
    _disableAccents = NO;
  }

  // Discard CAPS on characters when caps are mapped and there is no SW keyboard.
  BOOL capsWithoutSWKeyboard = [self capsMapped] & self.inputAccessoryView.hidden;
  if (capsWithoutSWKeyboard && text.length == 1 && [text characterAtIndex:0] > 0x1F) {
    text = [text lowercaseString];
  }

  NSUInteger modifiers = [(SmartKeysView *)[_smartKeys view] modifiers];
  if (modifiers & KbdCtrlModifier) {
    [_delegate write:[CC CTRL:text]];
  } else if (modifiers & KbdAltModifier) {
    [_delegate write:[CC ESC:text]];
  } else {
    [_delegate write:[CC KEY:text]];
  }
}

- (void)loadTerminalThemeJS:(NSString *)themeContent
{
  [_webView evaluateJavaScript:themeContent completionHandler:nil];
}

- (void)loadTerminalFont:(NSString *)familyName fromCSS:(NSString *)cssPath
{
  [_webView evaluateJavaScript:[NSString stringWithFormat:@"loadFontFromCSS(\"%@\", \"%@\");", cssPath, familyName] completionHandler:nil];
}

#pragma mark External Keyboard

- (void)setKbdCommands
{
  _kbdCommands = [NSMutableArray array];
  [_kbdCommands addObjectsFromArray:self.presetShortcuts];
  for (NSNumber *modifier in _controlKeys.allKeys) {
    [_kbdCommands addObjectsFromArray:_controlKeys[modifier]];
  }
  for (NSNumber *modifier in _functionKeys.allKeys) {
    [_kbdCommands addObjectsFromArray:_functionKeys[modifier]];
  }
  for (NSNumber *modifier in _functionTriggerKeys.allKeys) {
    [_kbdCommands addObjectsFromArray:_functionTriggerKeys[modifier]];
  }

  [_kbdCommands addObjectsFromArray:self.functionModifierKeys];
}

- (void)assignSequence:(NSString *)seq toModifier:(UIKeyModifierFlags)modifier
{
  if (seq) {
    NSMutableArray *cmds = [NSMutableArray array];
    NSString *charset;
    if (seq == TermViewCtrlSeq) {
      charset = @"qwertyuiopasdfghjklzxcvbnm[\\]^_ ";
    } else if (seq == TermViewEscSeq) {
      charset = @"qwertyuiopasdfghjklzxcvbnm1234567890`~-=_+[]\{}|;':\",./<>?/";
    } else {
      return;
    }

    NSUInteger length = charset.length;
    unichar buffer[length + 1];
    [charset getCharacters:buffer range:NSMakeRange(0, length)];

    [charset enumerateSubstringsInRange:NSMakeRange(0, length)
                                options:NSStringEnumerationByComposedCharacterSequences
                             usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                               [cmds addObject:[UIKeyCommand keyCommandWithInput:substring
                                                                   modifierFlags:modifier
                                                                          action:NSSelectorFromString(seq)]];

                               // Capture shift key presses to get transformed and not printed lowercase when CapsLock is Ctrl
                               if (modifier == UIKeyModifierAlphaShift) {
                                 [cmds addObjectsFromArray:[self shiftMaps]];
                               }
                             }];

    [_controlKeys setObject:cmds forKey:[NSNumber numberWithInteger:modifier]];
  } else {
    [_controlKeys setObject:@[] forKey:[NSNumber numberWithInteger:modifier]];
  }
  [self setKbdCommands];
}

- (void)assignKey:(NSString *)key toModifier:(UIKeyModifierFlags)modifier
{
  NSMutableArray *cmds = [[NSMutableArray alloc] init];

  if (key == UIKeyInputEscape) {
    [cmds addObject:[UIKeyCommand keyCommandWithInput:@"" modifierFlags:modifier action:@selector(escSeq:)]];
    if (modifier == UIKeyModifierAlphaShift) {
      [cmds addObjectsFromArray:[self shiftMaps]];
    }
    [_functionKeys setObject:cmds forKey:[NSNumber numberWithInteger:modifier]];
  } else {
    [_functionKeys setObject:cmds forKey:[NSNumber numberWithInteger:modifier]];
  }
  [self setKbdCommands];
}

- (NSArray *)shiftMaps
{
  NSMutableArray *cmds = [[NSMutableArray alloc] init];
  NSString *charset = @"qwertyuiopasdfghjklzxcvbnm";

  [charset enumerateSubstringsInRange:NSMakeRange(0, charset.length)
                              options:NSStringEnumerationByComposedCharacterSequences
                           usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                             [cmds addObject:[UIKeyCommand keyCommandWithInput:substring modifierFlags:UIKeyModifierShift action:@selector(shiftSeq:)]];
                           }];

  return cmds;
}

- (void)assignFunction:(NSString *)function toTriggers:(UIKeyModifierFlags)triggers
{
  // And Removing the Seq?
  NSMutableArray *functions = [[NSMutableArray alloc] init];
  SEL seq = NSSelectorFromString(function);

  if (function == TermViewCursorFuncSeq) {
    [functions addObject:[UIKeyCommand keyCommandWithInput:UIKeyInputDownArrow modifierFlags:triggers action:seq]];
    [functions addObject:[UIKeyCommand keyCommandWithInput:UIKeyInputUpArrow modifierFlags:triggers action:seq]];
    [functions addObject:[UIKeyCommand keyCommandWithInput:UIKeyInputLeftArrow modifierFlags:triggers action:seq]];
    [functions addObject:[UIKeyCommand keyCommandWithInput:UIKeyInputRightArrow modifierFlags:triggers action:seq]];
  } else if (function == TermViewFFuncSeq) {
    [_specialFKeysRow enumerateSubstringsInRange:NSMakeRange(0, [_specialFKeysRow length])
                                         options:NSStringEnumerationByComposedCharacterSequences
                                      usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                                        [functions addObject:[UIKeyCommand keyCommandWithInput:substring modifierFlags:triggers action:@selector(fkeySeq:)]];
                                      }];
  }

  [_functionTriggerKeys setObject:functions forKey:function];
  [self setKbdCommands];
}

- (NSArray *)presetShortcuts
{
  return @[ [UIKeyCommand keyCommandWithInput:@"+"
                                modifierFlags:UIKeyModifierCommand
                                       action:@selector(increaseFontSize:)],
            [UIKeyCommand keyCommandWithInput:@"-"
                                modifierFlags:UIKeyModifierCommand
                                       action:@selector(decreaseFontSize:)],
            [UIKeyCommand keyCommandWithInput:@"0"
                                modifierFlags:UIKeyModifierCommand
                                       action:@selector(resetFontSize:)] ];
}

- (NSArray *)functionModifierKeys
{
  NSMutableArray *f = [NSMutableArray array];

  for (NSNumber *modifier in [CC FModifiers]) {
    [f addObject:[UIKeyCommand keyCommandWithInput:UIKeyInputDownArrow modifierFlags:modifier.intValue action:@selector(arrowSeq:)]];
    [f addObject:[UIKeyCommand keyCommandWithInput:UIKeyInputUpArrow modifierFlags:modifier.intValue action:@selector(arrowSeq:)]];
    [f addObject:[UIKeyCommand keyCommandWithInput:UIKeyInputRightArrow modifierFlags:modifier.intValue action:@selector(arrowSeq:)]];
    [f addObject:[UIKeyCommand keyCommandWithInput:UIKeyInputLeftArrow modifierFlags:modifier.intValue action:@selector(arrowSeq:)]];
  }

  [f addObject:[UIKeyCommand keyCommandWithInput:UIKeyInputEscape modifierFlags:0 action:@selector(escSeq:)]];

  return f;
}

- (NSArray<UIKeyCommand *> *)keyCommands
{
  return _kbdCommands;
}

- (BOOL)capsMapped
{
  return ([[_controlKeys objectForKey:[NSNumber numberWithInteger:UIKeyModifierAlphaShift]] count] ||
          [[_functionKeys objectForKey:[NSNumber numberWithInteger:UIKeyModifierAlphaShift]] count]);
}

- (void)yank:(id)sender
{
  NSString *str = [UIPasteboard generalPasteboard].string;

  if (str) {
    [_delegate write:str];
  }
}

- (void)increaseFontSize:(UIKeyCommand *)cmd
{
  [_webView evaluateJavaScript:@"increaseTermFontSize();" completionHandler:nil];
}

- (void)decreaseFontSize:(UIKeyCommand *)cmd
{
  [_webView evaluateJavaScript:@"decreaseTermFontSize();" completionHandler:nil];
}

- (void)resetFontSize:(UIKeyCommand *)cmd
{
  [_webView evaluateJavaScript:@"resetTermFontSize();" completionHandler:nil];
}

- (void)escSeq:(UIKeyCommand *)cmd
{
  [_delegate write:[CC ESC:cmd.input]];
}

- (void)arrowSeq:(UIKeyCommand *)cmd
{
  [_delegate write:[CC KEY:cmd.input MOD:cmd.modifierFlags RAW:_raw]];
}

// Shift prints uppercase in the case CAPSLOCK is blocked
- (void)shiftSeq:(UIKeyCommand *)cmd
{
  if ([cmd.input length] == 0) {
    return;
  } else {
    [_delegate write:[cmd.input uppercaseString]];
  }
}

- (void)ctrlSeq:(UIKeyCommand *)cmd
{
  [_delegate write:[CC CTRL:cmd.input]];
}

- (void)metaSeq:(UIKeyCommand *)cmd
{
  if ([cmd.input isEqual:@"e"]) {
    //_disableAccents = YES;
  }

  [_delegate write:[CC ESC:cmd.input]];
}

- (void)cursorSeq:(UIKeyCommand *)cmd
{
  if (cmd.input == UIKeyInputUpArrow) {
    [_delegate write:[CC CURSOR:SpecialCursorKeyPgUp]];
  }
  if (cmd.input == UIKeyInputDownArrow) {
    [_delegate write:[CC CURSOR:SpecialCursorKeyPgDown]];
  }
  if (cmd.input == UIKeyInputLeftArrow) {
    [_delegate write:[CC CURSOR:SpecialCursorKeyHome]];
  }
  if (cmd.input == UIKeyInputRightArrow) {
    [_delegate write:[CC CURSOR:SpecialCursorKeyEnd]];
  }
}

- (void)fkeySeq:(UIKeyCommand *)cmd
{
  __block NSInteger idx = -1;
  [_specialFKeysRow enumerateSubstringsInRange:NSMakeRange(0, [_specialFKeysRow length])
                                       options:NSStringEnumerationByComposedCharacterSequences
                                    usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                                      if ([cmd.input isEqual:substring]) {
                                        idx = substringRange.location;
                                        *stop = YES;
                                      }
                                    }];

  if (idx >= 0) {
    [_delegate write:[CC FKEY:idx + 1]];
  }
}

// This are all key commands capture by UIKeyInput and triggered
// straight to the handler. A different firstresponder than UIKeyInput could
// capture them, but we would not capture normal keys. We remap them
// here as commands to the terminal.

// Cmd+c
- (void)copy:(id)sender
{
  // if ([sender isKindOfClass:[UIMenuController class]]) {
  //   [_webView copy:sender];
  // } else {
    [_delegate write:[CC CTRL:@"c"]];
    //  }
}
// Cmd+x
- (void)cut:(id)sender
{
  [_delegate write:[CC CTRL:@"x"]];
}
// Cmd+v
- (void)paste:(id)sender
{
  if ([sender isKindOfClass:[UIMenuController class]]) {
    [self yank:sender];
  } else {
    [_delegate write:[CC CTRL:@"v"]];
  }
}
// Cmd+a
- (void)selectAll:(id)sender
{
  [_delegate write:[CC CTRL:@"a"]];
}
// Cmd+b
- (void)toggleBoldface:(id)sender
{
  [_delegate write:[CC CTRL:@"b"]];
}
// Cmd+i
- (void)toggleItalics:(id)sender
{
  [_delegate write:[CC CTRL:@"i"]];
}
// Cmd+u
- (void)toggleUnderline:(id)sender
{
  [_delegate write:[CC CTRL:@"u"]];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
  if ([sender isKindOfClass:[UIMenuController class]]) {
    // The menu can only perform paste methods
    if (action == @selector(paste:)) {
      return YES;
    }
    return NO;
  }
  // From the keyboard we validate everything
  return YES;
}

@end
