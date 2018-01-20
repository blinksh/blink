//
//  InputView.m
//  Blink
//
//  Created by Yury Korolev on 1/12/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#import "BKDefaults.h"
#import "TermInput.h"
#import "SmartKeysController.h"
#import "SmartKeysView.h"
#import "BKSettingsNotifications.h"
#import "BKUserConfigurationManager.h"
#import "BKKeyboardModifierViewController.h"

static NSDictionary *bkModifierMaps = nil;

static NSDictionary *CTRLCodes = nil;
static NSDictionary *FModifiers = nil;
static NSDictionary *FKeys = nil;
static NSString *SS3 = nil;
static NSString *CSI = nil;

NSString *const TermViewCtrlSeq = @"ctrlSeq:";
NSString *const TermViewEscSeq = @"escSeq:";
NSString *const TermViewCursorFuncSeq = @"cursorSeq:";
NSString *const TermViewFFuncSeq = @"fkeySeq:";
NSString *const TermViewAutoRepeateSeq = @"autoRepeatSeq:";


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
                @"_" : @"\x1F",
                @"/" : @"\x1F"
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
            UIKeyInputLeftArrow : @"D",
            SpecialCursorKeyPgUp: @"5~",
            SpecialCursorKeyPgDown: @"6~",
            SpecialCursorKeyHome: @"H",
            SpecialCursorKeyEnd: @"F"
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
  
  BOOL isPageCursorKey = c == SpecialCursorKeyPgUp || c == SpecialCursorKeyPgDown;
  
  if ([FKeys.allKeys containsObject:c]) {
    if (m) {
      out = @[ CSI, FKeys[c] ];
    } else if (raw && !isPageCursorKey) {
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
    case 11:
    case 12:
    return [NSString stringWithFormat:@"%@2%ld~", CSI, number - 9];
    default:
    return nil;
  }
}
@end


@implementation TermInput {

  NSMutableDictionary *_controlKeys;
  NSMutableDictionary *_functionKeys;
  NSMutableDictionary *_functionTriggerKeys;
  NSString *_specialFKeysRow;
  NSString *_textInputContextIdentifier;
  
  // option + e on iOS lets introduce an accented character, that we override
  BOOL _disableAccents;
  BOOL _dismissInput;

  NSMutableArray<UIKeyCommand *> *_kbdCommands;
  SmartKeysController *_smartKeys;
  
  BOOL _inputEnabled;
  BOOL _cmdAsModifier;
}

+ (void)initialize
{
  bkModifierMaps = @{
     BKKeyboardModifierCtrl : [NSNumber numberWithInt:UIKeyModifierControl],
     BKKeyboardModifierAlt : [NSNumber numberWithInt:UIKeyModifierAlternate],
     BKKeyboardModifierCmd : [NSNumber numberWithInt:UIKeyModifierCommand],
     BKKeyboardModifierCaps : [NSNumber numberWithInt:UIKeyModifierAlphaShift],
     BKKeyboardModifierShift : [NSNumber numberWithInt:UIKeyModifierShift]
  };
}

- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  
  if (self) {
    _textInputContextIdentifier = [NSProcessInfo.processInfo globallyUniqueString];
    
    self.inputAssistantItem.leadingBarButtonGroups = @[];
    self.inputAssistantItem.trailingBarButtonGroups = @[];
    
    
    // Disable Smart Anything introduced within iOS11
    if (@available(iOS 11.0, *)) {
      self.smartDashesType = UITextSmartDashesTypeNo;
      self.smartQuotesType = UITextSmartQuotesTypeNo;
      self.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
    }
    
    self.autocorrectionType = UITextAutocorrectionTypeNo;
    self.autocapitalizationType = UITextAutocapitalizationTypeNone;
    
    _smartKeys = [[SmartKeysController alloc] init];
    _smartKeys.textInputDelegate = self;
    self.inputAccessoryView = [_smartKeys view];
    
    [self _configureNotifications];
    [self _configureShotcuts];
  }
  
  return self;
}

- (UIKeyboardAppearance)keyboardAppearance
{
  return [BKDefaults isLightKeyboard] ? UIKeyboardAppearanceLight : UIKeyboardAppearanceDark;
}

- (void)didMoveToWindow
{
  [super didMoveToWindow];
  
  // Do not show smart kb on non touch screen
  if (self.window && self.window.screen != [UIScreen mainScreen]) {
    self.inputAccessoryView = nil;
  }
}

- (void)_configureNotifications
{
  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
  [defaultCenter removeObserver:self];
  
  [defaultCenter addObserver:self selector:@selector(_willResignActive) name:UIApplicationWillResignActiveNotification object:nil];
  [defaultCenter addObserver:self selector:@selector(_didBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
  
  [defaultCenter addObserver:self
                    selector:@selector(_configureShotcuts)
                        name:BKKeyboardConfigChanged
                      object:nil];
  
  [defaultCenter addObserver:self
                    selector:@selector(_configureShotcuts)
                        name:BKKeyboardFuncTriggerChanged
                      object:nil];
}

- (void)_willResignActive
{
//  [self reloadInputViews];
}

- (void)_didBecomeActive
{
  [self reloadInputViews];
}

- (BOOL)becomeFirstResponder
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [self reloadInputViews];
  });
  return [super becomeFirstResponder];
}

- (BOOL)resignFirstResponder
{
  [_termDelegate blur];
  return [super resignFirstResponder];
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
  BOOL capsWithoutSWKeyboard = [self _capsMapped] & self.inputAccessoryView.hidden;
  if (capsWithoutSWKeyboard && text.length == 1 && [text characterAtIndex:0] > 0x1F) {
    text = [text lowercaseString];
  }
  
  // If the key is a special key, we do not apply modifiers.
  if (text.length > 1) {
    // Check if we have a function key
    NSRange range = [text rangeOfString:@"FKEY"];
    if (range.location != NSNotFound) {
      NSString *value = [text substringFromIndex:(range.length)];
      [_termDelegate write:[CC FKEY:[value integerValue]]];
    } else {
      [_termDelegate write:[CC KEY:text MOD:0 RAW:_raw]];
    }
  } else {
    NSUInteger modifiers = [[_smartKeys view] modifiers];
    if (modifiers & KbdCtrlModifier) {
      [_termDelegate write:[CC CTRL:text]];
    } else if (modifiers & KbdAltModifier) {
      [_termDelegate write:[CC ESC:text]];
    } else {
      [_termDelegate write:[CC KEY:text MOD:0 RAW:_raw]];
    }
  }
}

- (NSString *)textInputContextIdentifier
{
  return _textInputContextIdentifier;
}

- (void)deleteBackward
{
  // Send a delete backward key to the buffer
  [_termDelegate write:@"\x7f"];
}

- (void)escSeq:(UIKeyCommand *)cmd
{
  [_termDelegate write:[CC ESC:cmd.input]];
}

- (void)arrowSeq:(UIKeyCommand *)cmd
{
  [_termDelegate write:[CC KEY:cmd.input MOD:cmd.modifierFlags RAW:_raw]];
}

// Shift prints uppercase in the case CAPSLOCK is blocked
- (void)shiftSeq:(UIKeyCommand *)cmd
{
  if ([cmd.input length] == 0) {
    return;
  } else {
    [_termDelegate write:[cmd.input uppercaseString]];
  }
}

- (void)ctrlSeq:(UIKeyCommand *)cmd
{
  [_termDelegate write:[CC CTRL:cmd.input]];
}

- (void)metaSeq:(UIKeyCommand *)cmd
{
  if ([cmd.input isEqual:@"e"]) {
    //_disableAccents = YES;
  }
  
  [_termDelegate write:[CC ESC:cmd.input]];
}

- (void)cursorSeq:(UIKeyCommand *)cmd
{
  if (cmd.input == UIKeyInputUpArrow) {
    [_termDelegate write:[CC KEY:SpecialCursorKeyPgUp MOD:0 RAW:_raw]];
  }
  if (cmd.input == UIKeyInputDownArrow) {
    [_termDelegate write:[CC KEY:SpecialCursorKeyPgDown MOD:0 RAW:_raw]];
  }
  if (cmd.input == UIKeyInputLeftArrow) {
    [_termDelegate write:[CC KEY:SpecialCursorKeyHome MOD:0 RAW:_raw]];
  }
  if (cmd.input == UIKeyInputRightArrow) {
    [_termDelegate write:[CC KEY:SpecialCursorKeyEnd MOD:0 RAW:_raw]];
  }
}

- (void)fkeySeq:(UIKeyCommand *)cmd
{
  NSInteger value = [cmd.input integerValue];
  
  if (value == 0) {
    [_termDelegate write:[CC FKEY:10]];
  } else {
    [_termDelegate write:[CC FKEY:value]];
  }
}

- (void)autoRepeatSeq:(id)sender
{
  UIKeyCommand *command = (UIKeyCommand*)sender;
  [_termDelegate write:command.input];
}

// This are all key commands capture by UIKeyInput and triggered
// straight to the handler. A different firstresponder than UIKeyInput could
// capture them, but we would not capture normal keys. We remap them
// here as commands to the terminal.

// Cmd+c
- (void)copy:(id)sender
{
  if ([sender isKindOfClass:[UIMenuController class]] || !_cmdAsModifier) {
    [_termDelegate.termView copy:sender];
  } else {
    [_termDelegate write:[CC CTRL:@"c"]];
  }
}
// Cmd+x
- (void)cut:(id)sender
{
  [_termDelegate write:[CC CTRL:@"x"]];
}
// Cmd+v
- (void)paste:(id)sender
{
  if ([sender isKindOfClass:[UIMenuController class]] || !_cmdAsModifier) {
    [self yank:sender];
  } else {
    [_termDelegate write:[CC CTRL:@"v"]];
  }
}

// Cmd+a
- (void)selectAll:(id)sender
{
  [_termDelegate write:[CC CTRL:@"a"]];
}
// Cmd+b
- (void)toggleBoldface:(id)sender
{
  [_termDelegate write:[CC CTRL:@"b"]];
}
// Cmd+i
- (void)toggleItalics:(id)sender
{
  [_termDelegate write:[CC CTRL:@"i"]];
}
// Cmd+u
- (void)toggleUnderline:(id)sender
{
  [_termDelegate write:[CC CTRL:@"u"]];
}

- (void)copyLink:(id)sender
{
  UIPasteboard.generalPasteboard.URL = [_termDelegate.termView detectedLink];
  [_termDelegate.termView cleanSelection];
}

- (void)openLink:(id)sender
{
  NSURL * url = [_termDelegate.termView detectedLink];
  
  [_termDelegate.termView cleanSelection];
  
  if (url == nil) {
    return;
  }
  
  UIApplication * app = [UIApplication sharedApplication];
  if (![app canOpenURL:url]) {
    return;
  }
  
  [app openURL:url];
}

- (void)unselect:(id)sender
{
  [_termDelegate.termView cleanSelection];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
  if ([sender isKindOfClass:[UIMenuController class]]) {
    // The menu can only perform paste methods
    if (action == @selector(paste:) ||
        action == @selector(copy:) ||
        action == @selector(copyLink:) ||
        action == @selector(openLink:) ||
        action == @selector(unselect:)
      ) {
      return YES;
    }
    
    return NO;
  }
  
  // super returns NO (No text?), so we check ourselves.
  if (action == @selector(paste:) ||
      action == @selector(cut:) ||
      action == @selector(copy:) ||
      action == @selector(select:) ||
      action == @selector(selectAll:) ||
      action == @selector(delete:) ||
      action == @selector(makeTextWritingDirectionLeftToRight:) ||
      action == @selector(makeTextWritingDirectionRightToLeft:) ||
      action == @selector(toggleBoldface:) ||
      action == @selector(toggleItalics:) ||
      action == @selector(toggleUnderline:)
      ) {
    return YES;
  }
  
  BOOL result = [super canPerformAction:action withSender:sender];
  return result;
}

#pragma mark External Keyboard

- (void)_setKbdCommands
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
  
  [_kbdCommands addObjectsFromArray:self._functionModifierKeys];
}

- (void)_assignSequence:(NSString *)seq toModifier:(UIKeyModifierFlags)modifier
{
  if (seq) {
    NSMutableArray *cmds = [NSMutableArray array];
    NSString *charset;
    if (seq == TermViewCtrlSeq) {
      charset = @"qwertyuiopasdfghjklzxcvbnm[\\]^/_ ";
    } else if (seq == TermViewEscSeq) {
      charset = @"qwertyuiopasdfghjklzxcvbnm1234567890`~-=_+[]\{}|;':\",./<>?/";
    } else if (seq == TermViewAutoRepeateSeq){
      charset = @"qwertyuiopasdfghjklzxcvbnm1234567890";
    }
    else {
      return;
    }
    
    // Cmd is default for iOS shortcuts, so we control whether or not we are re-mapping those ourselves.
    if (modifier == UIKeyModifierCommand) {
      _cmdAsModifier = YES;
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
                                 [cmds addObjectsFromArray:[self _shiftMaps]];
                               }
                             }];
    
    [_controlKeys setObject:cmds forKey:[NSNumber numberWithInteger:modifier]];
  } else {
    if (modifier == UIKeyModifierCommand) {
      _cmdAsModifier = NO;
    }
    
    [_controlKeys setObject:@[] forKey:[NSNumber numberWithInteger:modifier]];
  }
}

- (void)_assignKey:(NSString *)key toModifier:(UIKeyModifierFlags)modifier
{
  NSMutableArray *cmds = [[NSMutableArray alloc] init];
  
  if (key == UIKeyInputEscape) {
    [cmds addObject:[UIKeyCommand keyCommandWithInput:@"" modifierFlags:modifier action:@selector(escSeq:)]];
    if (modifier == UIKeyModifierAlphaShift) {
      [cmds addObjectsFromArray:[self _shiftMaps]];
    }
    [_functionKeys setObject:cmds forKey:[NSNumber numberWithInteger:modifier]];
  } else {
    [_functionKeys setObject:cmds forKey:[NSNumber numberWithInteger:modifier]];
  }
}

- (NSArray *)_shiftMaps
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

- (void)_assignFunction:(NSString *)function toTriggers:(UIKeyModifierFlags)triggers
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
}

- (NSArray *)presetShortcuts
{
  UIKeyModifierFlags modifiers = [BKUserConfigurationManager shortCutModifierFlags];
  return @[ 
            [UIKeyCommand keyCommandWithInput: @"v"
                                modifierFlags:modifiers
//                                       action: @selector(yank:)
                                       action: @selector(paste:)
                         discoverabilityTitle: @"Paste"],
            ];
}

- (NSArray *)_functionModifierKeys
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

- (BOOL)_capsMapped
{
  NSNumber *key = [NSNumber numberWithInteger:UIKeyModifierAlphaShift];
  return ([[_controlKeys objectForKey:key] count] ||
          [[_functionKeys objectForKey:key] count]);
}

- (void)yank:(id)sender
{
  NSString *str = [UIPasteboard generalPasteboard].string;
  
  if (str) {
    [_termDelegate write:str];
  }
}

- (void)_resetDefaultControlKeys
{
  _controlKeys = [[NSMutableDictionary alloc] init];
  _functionKeys = [[NSMutableDictionary alloc] init];
  _functionTriggerKeys = [[NSMutableDictionary alloc] init];
  _specialFKeysRow = @"1234567890";
  [self _setKbdCommands];
}

- (void)_configureShotcuts
{
  [self _resetDefaultControlKeys];

  if ([BKDefaults autoRepeatKeys]) {
    [self _assignSequence:TermViewAutoRepeateSeq toModifier:0];
  }

  for (NSString *key in [BKDefaults keyboardKeyList]) {
    NSString *sequence = [BKDefaults keyboardMapping][key];
    NSInteger modifier = [bkModifierMaps[key] integerValue];
    if ([sequence isEqual:BKKeyboardSeqNone]) {
      [self _assignSequence:nil toModifier:modifier];
    } else if ([sequence isEqual:BKKeyboardSeqCtrl]) {
      [self _assignSequence:TermViewCtrlSeq toModifier:modifier];
    } else if ([sequence isEqual:BKKeyboardSeqEsc]) {
      [self _assignSequence:TermViewEscSeq toModifier:modifier];
    }
  }

  if ([BKDefaults isShiftAsEsc]) {
    [self _assignKey:UIKeyInputEscape toModifier:UIKeyModifierShift];
  }

  if ([BKDefaults isCapsAsEsc]) {
    [self _assignKey:UIKeyInputEscape toModifier:UIKeyModifierAlphaShift];
  }

  for (NSString *func in [BKDefaults keyboardFuncTriggers].allKeys) {
    NSArray *triggers = [BKDefaults keyboardFuncTriggers][func];
    UIKeyModifierFlags modifiers = 0;
    for (NSString *t in triggers) {
      NSNumber *modifier = bkModifierMaps[t];
      modifiers = modifiers | modifier.intValue;
    }
    if ([func isEqual:BKKeyboardFuncCursorTriggers]) {
      [self _assignFunction:TermViewCursorFuncSeq toTriggers:modifiers];
    } else if ([func isEqual:BKKeyboardFuncFTriggers]) {
      [self _assignFunction:TermViewFFuncSeq toTriggers:modifiers];
    }
  }
  
  [self _setKbdCommands];
}


@end
