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
  if (c == nil || [c length] == 0) {
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
@end

@interface TerminalView () <UIKeyInput, UIGestureRecognizerDelegate>
@end

@implementation TerminalView {
  WKWebView *_webView;
  BOOL _capsMapped;
  // option + e on iOS lets introduce an accented character, that we override
  BOOL _disableAccents;
  BOOL _dismissInput;
  BOOL _pasteMenu;
  NSMutableArray *_kbdCommands;
  SmartKeys *_smartKeys;
  UIView *cover;
  UIPinchGestureRecognizer *_pinchGesture;
  NSTimer *_pinchSamplingTimer;
  BOOL _raw;
}

- (id)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration
{
  self = [super initWithFrame:frame];

  if (self) {
    _webView = [[WKWebView alloc] initWithFrame:self.frame configuration:configuration];
    _capsMapped = YES;
    [self setKbdCommands];

    _webView.opaque = NO;
    [self addSubview:_webView];

    UITapGestureRecognizer *tapBackground = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(activeControl:)];
    [tapBackground setNumberOfTapsRequired:1];
    tapBackground.delegate = self;
    _dismissInput = YES;
    [self addGestureRecognizer:tapBackground];

    UILongPressGestureRecognizer *longPressBackground = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:nil];
    [longPressBackground setNumberOfTapsRequired:1];
    longPressBackground.delegate = self;
    // _dismissInput = YES;
    [self addGestureRecognizer:tapBackground];

    _pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
    _pinchGesture.delegate = self;
    [self addGestureRecognizer:_pinchGesture];

    self.inputAssistantItem.leadingBarButtonGroups = @[];
    self.inputAssistantItem.trailingBarButtonGroups = @[];

    _webView.translatesAutoresizingMaskIntoConstraints = NO;

    [_webView.topAnchor constraintEqualToAnchor:self.topAnchor].active = YES;
    [_webView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor].active = YES;
    [_webView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor].active = YES;
    [_webView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor].active = YES;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
  }
  return self;
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
  _capsMapped = YES;
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
    _capsMapped = NO;
    iaView.hidden = NO;
  }
}

// WKWebView has its own gestures going on, so we have to handle them properly and only use ours when those fail.
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
  if ([otherGestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
    // Tap should always enable this control too.
    [otherGestureRecognizer requireGestureRecognizerToFail:gestureRecognizer];
    _dismissInput = NO;
  }
  if ([otherGestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
    [_webView becomeFirstResponder];
    [gestureRecognizer requireGestureRecognizerToFail:otherGestureRecognizer];
  }
  return NO;
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
  //[_webView evaluateJavaScript:[NSString stringWithFormat:@"scaleTerm(%f);", scale] completionHandler:nil];


  // _webView.transform = CGAffineTransformScale(gestureRecognizer.view.transform, 1/gestureRecognizer.scale, 1/gestureRecognizer.scale);
  //  CGFloat scale = round(1.0 - (0.04 * (_lastPinchScale - gestureRecognizer.velocity)) * 100) / 100.0;
  //
  //  if (gestureRecognizer.scale < 0.5 || gestureRecognizer.scale > 2.0)
  //    return;
  //  if (scale != _lastPinchScale) {
  //    NSLog(@"%f", scale);
  //    [_webView evaluateJavaScript:[NSString stringWithFormat:@"scaleTerm(%f);", scale] completionHandler:nil];
  //    _lastPinchScale = scale;
  //  }
}

- (void)pinchSampling:(NSTimer *)timer
{
  [_webView evaluateJavaScript:[NSString stringWithFormat:@"scaleTerm(%f);", _pinchGesture.scale] completionHandler:nil];
}

- (BOOL)canBecomeFirstResponder
{
  return YES;
}

- (BOOL)canResignFirstResponder
{
  // Make sure this control cannot resign in favor of the WKWebView during a tap.
  //    if (!_dismissInput) {
  //      _dismissInput = YES;
  //      return NO;
  //    }
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

  // Discard CAPS unless it is a control sequence or non single character.
  if (_capsMapped == YES && text.length == 1 && [text characterAtIndex:0] > 0x1F) {
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

#pragma mark External Keyboard

- (void)setKbdCommands
{
  _kbdCommands = [NSMutableArray array];
  // [kbdCommands addObjectsFromArray:presetShortcuts]
  // [kbdCommands addObjectsFromArray:functionKeys]
  // [kbdCommands addObjectsFromArray:controlSeqs]

  // presetShortcuts
  [_kbdCommands addObject:[UIKeyCommand keyCommandWithInput:@"v" modifierFlags:UIKeyModifierControl action:@selector(yank:)]];
  [_kbdCommands addObject:[UIKeyCommand keyCommandWithInput:@"+" modifierFlags:UIKeyModifierControl action:@selector(increaseFontSize:)]];
  [_kbdCommands addObject:[UIKeyCommand keyCommandWithInput:@"-" modifierFlags:UIKeyModifierControl action:@selector(decreaseFontSize:)]];
  [_kbdCommands addObject:[UIKeyCommand keyCommandWithInput:@"0" modifierFlags:UIKeyModifierControl action:@selector(resetFontSize:)]];

  // controlSeqs
  NSString *charset = @"qwertyuiopasdfghjklzxcvbnmйцукеёнгшщзхъфывапролджэячсмитьбю!@#$%^&*()=_[]{}'\\\"|`~,./<>?";
  NSUInteger length = charset.length;
  unichar buffer[length + 1];
  [charset getCharacters:buffer range:NSMakeRange(0, length)];

  [charset enumerateSubstringsInRange:NSMakeRange(0, length)
			      options:NSStringEnumerationByComposedCharacterSequences
			   usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
			     [_kbdCommands addObject:[UIKeyCommand keyCommandWithInput:substring modifierFlags:UIKeyModifierControl action:@selector(ctrlSeq:)]];
			     [_kbdCommands addObject:[UIKeyCommand keyCommandWithInput:substring modifierFlags:UIKeyModifierAlternate action:@selector(metaSeq:)]];
			     [_kbdCommands addObject:[UIKeyCommand keyCommandWithInput:substring modifierFlags:UIKeyModifierCommand action:@selector(ctrlSeq:)]];
			     [_kbdCommands addObject:[UIKeyCommand keyCommandWithInput:substring modifierFlags:UIKeyModifierAlphaShift action:@selector(ctrlSeq:)]];
			     NSRange first = [substring rangeOfComposedCharacterSequenceAtIndex:0];
			     NSRange match = [substring rangeOfCharacterFromSet:[NSCharacterSet letterCharacterSet] options:0 range:first];
			     if (match.location != NSNotFound) {
			       [_kbdCommands addObject:[UIKeyCommand keyCommandWithInput:substring modifierFlags:UIKeyModifierShift action:@selector(shiftSeq:)]];
			     }

			   }];
  [_kbdCommands addObject:[UIKeyCommand keyCommandWithInput:UIKeyInputEscape modifierFlags:0 action:@selector(escSeq:)]];

  // Function keys with modifier sequences.
  for (NSNumber *modifier in [CC FModifiers]) {
    [_kbdCommands addObject:[UIKeyCommand keyCommandWithInput:UIKeyInputDownArrow modifierFlags:modifier.intValue action:@selector(arrowSeq:)]];
    [_kbdCommands addObject:[UIKeyCommand keyCommandWithInput:UIKeyInputUpArrow modifierFlags:modifier.intValue action:@selector(arrowSeq:)]];
    [_kbdCommands addObject:[UIKeyCommand keyCommandWithInput:UIKeyInputRightArrow modifierFlags:modifier.intValue action:@selector(arrowSeq:)]];
    [_kbdCommands addObject:[UIKeyCommand keyCommandWithInput:UIKeyInputLeftArrow modifierFlags:modifier.intValue action:@selector(arrowSeq:)]];
  }
}

- (NSArray<UIKeyCommand *> *)keyCommands
{
  return _kbdCommands;
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
  [_delegate write:[CC KEY:cmd.input]];
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

// This are all key commands capture by UIKeyInput and triggered
// straight to the handler. A different firstresponder than UIKeyInput could
// capture them, but we would not capture normal keys. We remap them
// here as commands to the terminal.

// Cmd+c
- (void)copy:(id)sender
{
  if ([sender isKindOfClass:[UIMenuController class]]) {
    [_webView copy:sender];
  } else {
    [_delegate write:[CC CTRL:@"c"]];
  }
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
    // The menu can only perform copy and paste methods
    if (action == @selector(paste:)) {
      return YES;
    }
    return NO;
  }
  // From the keyboard we validate everything
  return YES;
}

@end
