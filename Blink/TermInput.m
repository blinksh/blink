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
NSString *const TermViewEscCtrlSeq = @"escCtrlSeq:";
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


@implementation UndoManager
- (BOOL)canRedo
{
  return YES;
}

- (BOOL)canUndo
{
  return YES;
}

-(void)undo
{
  [_undoManagerDelegate undoWithManager:self];
}

- (void)redo
{
  [_undoManagerDelegate redoWithManager:self];
}

@end

@interface TermInput () <UndoManagerDelegate, UITextViewDelegate, NSTextStorageDelegate>
@end

@implementation TermInput {

  NSMutableDictionary *_controlKeys;
  NSMutableDictionary *_controlKeysWithoutAutoRepeat;
  NSMutableDictionary *_functionKeys;
  NSMutableDictionary *_functionTriggerKeys;
  NSString *_specialFKeysRow;
  NSSet<NSString *> *_imeLangSet;
  
  // option + e on iOS lets introduce an accented character, that we override
  BOOL _disableAccents;
  BOOL _dismissInput;

  NSMutableArray<UIKeyCommand *> *_kbdCommands;
  NSMutableArray<UIKeyCommand *> *_kbdCommandsWithoutAutoRepeat;
  SmartKeysController *_smartKeys;
  
  BOOL _inputEnabled;
  NSString *_cmdModifierSequence;
  
  UndoManager *_undoManager;
  BOOL _skipTextStorageDelete;
  NSString * _markedText;
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
    self.inputAssistantItem.leadingBarButtonGroups = @[];
    self.inputAssistantItem.trailingBarButtonGroups = @[];
    
    
    // Disable Smart Anything introduced within iOS11
    if (@available(iOS 11.0, *)) {
      self.smartDashesType = UITextSmartDashesTypeNo;
      self.smartQuotesType = UITextSmartQuotesTypeNo;
      self.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
    }
    
    self.delegate = self;
    
    _smartKeys = [[SmartKeysController alloc] init];
    _smartKeys.textInputDelegate = self;
    self.inputAccessoryView = [_smartKeys view];
    
    _undoManager = [[UndoManager alloc] init];
    _undoManager.undoManagerDelegate = self;
    
    [self _configureNotifications];
    [self _configureShotcuts];
    
    [self setHidden:YES];
    self.textContainerInset = UIEdgeInsetsZero;
    self.textContainer.lineFragmentPadding = 0;
    self.font = [UIFont fontWithName:@"Menlo" size:0];
    
    [self _configureLangSet];
    
    _skipTextStorageDelete = NO;
    self.textStorage.delegate = self;
  }
  
  return self;
}

// Autocorrection and autocapitalization should be implemented as overrides.
// Fixes #370

- (UITextAutocorrectionType)autocorrectionType
{
  return UITextAutocorrectionTypeNo;
}

- (UITextAutocapitalizationType)autocapitalizationType
{
  return UITextAutocapitalizationTypeNone;
}

- (void)_configureLangSet
{
  _imeLangSet = [NSSet setWithObjects:
                  @"zh-Hans",
                  @"zh-Hant",
                  @"ja-JP",
                  nil];
}

- (void)textStorage:(NSTextStorage *)textStorage
  didProcessEditing:(NSTextStorageEditActions)editedMask
              range:(NSRange)editedRange
     changeInLength:(NSInteger)delta
{
  if (delta == -1 && !_skipTextStorageDelete && !_markedText) {
    [_termDelegate write:@"\x7f"];
  }
}

- (NSUndoManager *)undoManager
{
  return _cmdModifierSequence ? _undoManager : [super undoManager];
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

- (NSString *)textInputContextIdentifier
{
  // Remember current input
  return @"terminput";
}

- (void)_configureNotifications
{
  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
  [defaultCenter removeObserver:self];
  
  [defaultCenter addObserver:self
                    selector:@selector(_configureShotcuts)
                        name:BKKeyboardConfigChanged
                      object:nil];
  
  [defaultCenter addObserver:self
                    selector:@selector(_configureShotcuts)
                        name:BKKeyboardFuncTriggerChanged
                      object:nil];
}

- (BOOL)becomeFirstResponder
{
  BOOL res = [super becomeFirstResponder];
  if (res) {
    // reload input views to get rid of kb input views from other apps.
    dispatch_async(dispatch_get_main_queue(), ^{
      [self reloadInputViews];
    });
    [_termDelegate focus];
  } else {
    [_termDelegate blur];
  }
  return res;
}

- (BOOL)resignFirstResponder
{
  [_termDelegate blur];
  return [super resignFirstResponder];
}

- (void)reset
{
  self.text = @"";
  [self.termDelegate.termView setIme: @"" completionHandler:nil];
  _markedText = nil;
  _skipTextStorageDelete = NO;
}

- (void)textViewDidChange:(UITextView *)textView
{
  if (textView.text.length == 0) {
    _markedText = nil;
    _skipTextStorageDelete = YES;
    [self reset];
    _skipTextStorageDelete = NO;
    return;
  }
  
  if (!self.markedTextRange) {
    if (_markedText) {
      [self _insertText:_markedText];
      [self reset];
      _markedText = nil;
      [self.termDelegate.termView setIme: @"" completionHandler:nil];
      return;
    }
    
    _skipTextStorageDelete = NO;
    _markedText = nil;
    
    return;
  }

  NSString *str = [self textInRange:self.markedTextRange];
  _markedText = str;
  
  [self.termDelegate.termView setIme: str
                   completionHandler:^(id data, NSError * _Nullable error) {
    if (!data) {
      return;
    }
    
    CGRect rect = CGRectFromString(data[@"markedRect"]);

    CGFloat suggestionsHeight = 44;
    CGFloat maxY = CGRectGetMaxY(rect);
    CGFloat minY = CGRectGetMinY(rect);
    if (maxY - suggestionsHeight < 0) {
      rect.origin.y = maxY;
    } else {
      rect.origin.y = minY - suggestionsHeight;
    }
    rect.size.height = 0;
    self.frame = rect;
  }];
}

- (void)_insertText:(NSString *)text
{
  if (_disableAccents) {
    // If the accent switch is on, the next character should remove them.
    //CFStringTransform((__bridge CFMutableStringRef)mtext, nil, kCFStringTransformStripCombiningMarks, NO);
    text = [[NSString alloc] initWithData:[text dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES]
                                 encoding:NSASCIIStringEncoding];
    _disableAccents = NO;
  }
  
  // Discard CAPS on characters when caps are mapped and there is no SW keyboard.
  BOOL capsWithoutSWKeyboard = !self.softwareKB && [self _capsMapped];
  if (capsWithoutSWKeyboard && text.length == 1 && [text characterAtIndex:0] > 0x1F) {
    text = [text lowercaseString];
  }
  
  if  (_termDelegate.termView.hasSelection) {
    // If the key is a special key, we do not apply modifiers.
    if (text.length > 1) {
      // Check if we have a function key
      NSRange range = [text rangeOfString:@"FKEY"];
      if (range.location == NSNotFound) {
        [self _changeSelectionWithInput:text andFlags: kNilOptions];
      }
    } else {
      NSUInteger modifiers = [[_smartKeys view] modifiers];
      [self _changeSelectionWithInput:text andFlags:modifiers];
    }
    return;
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
    if (modifiers == KbdCtrlModifier) {
      [self _ctrlSeqWithInput:text];
    } else if (modifiers == KbdAltModifier) {
      [self _escSeqWithInput:text];
    } else if (modifiers == (KbdCtrlModifier | KbdAltModifier)) {
      [self _escCtrlSeqWithInput: text];
    } else {
      [_termDelegate write:[CC KEY:text MOD:0 RAW:_raw]];
    }
  }
}

- (void)insertText:(NSString *)text
{
  [self _insertText:text];
  
  if (_markedText) {
    return;
  }
  
  [super insertText:text];
  NSInteger wordsToKeepInLine = 3;
  text = self.text;
  NSArray *comps = [text componentsSeparatedByString:@" "];
  if (comps.count > wordsToKeepInLine) {
    comps = [comps subarrayWithRange:NSMakeRange(comps.count - wordsToKeepInLine, wordsToKeepInLine)];
    _skipTextStorageDelete = YES;
    self.text = [comps componentsJoinedByString:@" "];
    _skipTextStorageDelete = NO;
  }
}

- (void)deleteBackward
{
  // Send a delete backward key to the buffer
  [_termDelegate write:@"\x7f"];
  
  _skipTextStorageDelete = YES;
  [super deleteBackward];
  _skipTextStorageDelete = NO;
}

// Alt+Backspace
- (void)_deleteByWord
{
  if (![self _remapInput:@"\x7f" forModifier:BKKeyboardModifierAlt]) {
    // Default to `^[^?`. See https://github.com/blinksh/blink/issues/117
    [_termDelegate write:[CC ESC:@"\x7f"]];
  }
}

- (void)_escSeqWithInput:(NSString *)input
{
  if (_termDelegate.termView.hasSelection) {
    [self _changeSelectionWithInput:input andFlags:UIKeyModifierAlternate];
  } else {
    [_termDelegate write:[CC ESC:input]];
  }
}
- (void)escSeq:(UIKeyCommand *)cmd
{
  [self _escSeqWithInput:cmd.input];
}

- (void)arrowSeq:(UIKeyCommand *)cmd
{
  if (_termDelegate.termView.hasSelection) {
    [self _changeSelection:cmd];
  } else {
    [_termDelegate write:[CC KEY:cmd.input MOD:cmd.modifierFlags RAW:_raw]];
  }
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

- (void)_ctrlSeqWithInput:(NSString *)input
{
  if (_termDelegate.termView.hasSelection) {
    [self _changeSelectionWithInput:input andFlags:UIKeyModifierControl];
  } else {
    if ([_termDelegate handleControl:input]) {
      return;
    }
    [_termDelegate write:[CC CTRL:input]];
  }
}

- (void)ctrlSeq:(UIKeyCommand *)cmd
{
  [self _ctrlSeqWithInput:cmd.input];
}

- (void)_escCtrlSeqWithInput:(NSString *)input
{
  NSString *seq = [NSString stringWithFormat:@"%@%@", [CC ESC:nil], [CC CTRL:input]];
  [_termDelegate write:seq];
}

- (void)escCtrlSeq:(UIKeyCommand *)cmd
{
  if (_termDelegate.termView.hasSelection) {
    [self _changeSelectionWithInput:cmd.input andFlags:UIKeyModifierControl | UIKeyModifierAlternate];
  } else {
    [self _escCtrlSeqWithInput:cmd.input];
  }
}

- (void)cursorSeq:(UIKeyCommand *)cmd
{
  if  (_termDelegate.termView.hasSelection) {
    [self _changeSelection:cmd];
    return;
  }
  
  if (cmd.input == UIKeyInputUpArrow) {
    [_termDelegate write:[CC KEY:SpecialCursorKeyPgUp MOD:0 RAW:_raw]];
  } else if (cmd.input == UIKeyInputDownArrow) {
    [_termDelegate write:[CC KEY:SpecialCursorKeyPgDown MOD:0 RAW:_raw]];
  } else if (cmd.input == UIKeyInputLeftArrow) {
    [_termDelegate write:[CC KEY:SpecialCursorKeyHome MOD:0 RAW:_raw]];
  } else if (cmd.input == UIKeyInputRightArrow) {
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
  if  (_termDelegate.termView.hasSelection) {
    [self _changeSelection:command];
  } else {
    if (self.inputAccessoryView.hidden) {
      return [_termDelegate write:command.input];
    }
    
    NSString *text = command.input;
    NSUInteger modifiers = [[_smartKeys view] modifiers];
    if (modifiers == KbdCtrlModifier) {
      [self _ctrlSeqWithInput:text];
    } else if (modifiers == KbdAltModifier) {
      [self _escSeqWithInput:text];
    } else if (modifiers == (KbdCtrlModifier | KbdAltModifier)) {
      [self _escCtrlSeqWithInput: text];
    } else {
      [_termDelegate write:text];
    }
  }
}

- (BOOL)_remapCmdSeqWithSender:(id)sender andInput:(NSString *)input
{
  if (!_cmdModifierSequence ||
      [sender isKindOfClass:[UIMenuController class]]) {
    return NO;
  }

  if (_cmdModifierSequence == TermViewCtrlSeq) {
    [self _ctrlSeqWithInput:input];
  } else if (_cmdModifierSequence == TermViewEscSeq) {
    [self _escSeqWithInput:input];
  } else {
    // return NO?
  }
  
  return YES;
}

// This are all key commands capture by UIKeyInput and triggered
// straight to the handler. A different firstresponder than UIKeyInput could
// capture them, but we would not capture normal keys. We remap them
// here as commands to the terminal.

// Cmd+c
- (void)copy:(id)sender
{
  if (![self _remapCmdSeqWithSender:sender andInput:@"c"]) {
    [_termDelegate.termView copy:sender];
  }
}
// Cmd+x
- (void)cut:(id)sender
{
  [self _remapCmdSeqWithSender:sender andInput:@"x"];
}
// Cmd+v
- (void)paste:(id)sender
{
  if (![self _remapCmdSeqWithSender:sender andInput:@"v"]) {
    [self yank:sender];
  }
}

// Cmd+z
- (void)undoWithManager:(UndoManager *)manager
{
  [self _remapCmdSeqWithSender:manager andInput:@"z"];
}

// Cmd+Z
- (void)redoWithManager:(UndoManager *)manager
{
  [self _remapCmdSeqWithSender:manager andInput:@"Z"];
}

// Cmd+a
- (void)selectAll:(id)sender
{
  [self _remapCmdSeqWithSender:sender andInput:@"a"];
}
// Cmd+b
- (void)toggleBoldface:(id)sender
{
  [self _remapCmdSeqWithSender:sender andInput:@"b"];
}
// Cmd+i
- (void)toggleItalics:(id)sender
{
  [self _remapCmdSeqWithSender:sender andInput:@"i"];
}
// Cmd+u
- (void)toggleUnderline:(id)sender
{
  [self _remapCmdSeqWithSender:sender andInput:@"u"];
}

- (void)pasteSelection:(id)sender
{
  NSString *str = _termDelegate.termView.selectedText;
  if (str) {
    [_termDelegate write:str];
  }
  [_termDelegate.termView cleanSelection];
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
        (action == @selector(copy:) && _termDelegate.termView.hasSelection) ||
        (action == @selector(pasteSelection:) && _termDelegate.termView.hasSelection) ||
        (action == @selector(copyLink:) && _termDelegate.termView.detectedLink) ||
        (action == @selector(openLink:) && _termDelegate.termView.detectedLink)
      ) {
      return YES;
    }
    
    return NO;
  }
  
  UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
  
  if (appState != UIApplicationStateActive) {
    return NO;
  }
  
  // super returns NO (No text?), so we check ourselves.
  if (action == @selector(paste:) ||
      action == @selector(cut:) ||
      action == @selector(copy:) ||
      action == @selector(select:) ||
      action == @selector(selectAll:) ||
      action == @selector(delete:) ||
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
  
  for (NSNumber *modifier in _functionKeys.allKeys) {
    [_kbdCommands addObjectsFromArray:_functionKeys[modifier]];
  }
  for (NSNumber *modifier in _functionTriggerKeys.allKeys) {
    [_kbdCommands addObjectsFromArray:_functionTriggerKeys[modifier]];
  }
  
  [_kbdCommands addObjectsFromArray:self._functionModifierKeys];

  // This dummy command to hand stuck cmd key
  [_kbdCommands addObject:[UIKeyCommand keyCommandWithInput:@""
                                              modifierFlags:UIKeyModifierCommand
                                                     action:@selector(_kbCmd:)]];
  
  [_kbdCommands addObject:[UIKeyCommand keyCommandWithInput:@"\t"
                                              modifierFlags:UIKeyModifierShift
                                                     action:@selector(_shiftTab:)]];
  
  if (_controlKeys != _controlKeysWithoutAutoRepeat) {
    _kbdCommandsWithoutAutoRepeat = [_kbdCommands mutableCopy];
    for (NSNumber *modifier in _controlKeysWithoutAutoRepeat.allKeys) {
      [_kbdCommandsWithoutAutoRepeat addObjectsFromArray:_controlKeys[modifier]];
    }
  } else {
    _kbdCommandsWithoutAutoRepeat = _kbdCommands;
  }
  for (NSNumber *modifier in _controlKeys.allKeys) {
    [_kbdCommands addObjectsFromArray:_controlKeys[modifier]];
  }
  
}

- (void)_kbCmd:(UIKeyCommand *)cmd
{
  if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
    [self resignFirstResponder];
  }
}

- (void)_shiftTab:(UIKeyCommand *)cmd
{
  [_termDelegate write:@"\x1b\x5b\x5a"];
}

- (void)_assignSequence:(NSString *)seq toModifier:(UIKeyModifierFlags)modifier
{
  if (!seq) {
    if (modifier == UIKeyModifierCommand) {
      _cmdModifierSequence = nil;
    }
    
    [_controlKeys setObject:@[] forKey:[NSNumber numberWithInteger:modifier]];
  }
  
  NSMutableArray *cmds = [NSMutableArray array];
  NSString *charset;
  if (seq == TermViewCtrlSeq || seq == TermViewEscCtrlSeq) {
    charset = @"qwertyuiopasdfghjklzxcvbnm[\\]^/_ ";
  } else if (seq == TermViewEscSeq) {
    charset = @"qwertyuiopasdfghjklzxcvbnm1234567890`~-=_+[]{}\\|;':\",./<>?";
  } else if (seq == TermViewAutoRepeateSeq) {
    charset = @"qwertyuiopasdfghjklzxcvbnm1234567890";
  } else {
    return;
  }
  
  // Cmd is default for iOS shortcuts, so we control whether or not we are re-mapping those ourselves.
  if (modifier == UIKeyModifierCommand) {
    _cmdModifierSequence = seq;
  }
  
  NSUInteger length = charset.length;
  unichar buffer[length + 1];
  [charset getCharacters:buffer range:NSMakeRange(0, length)];
  SEL action = NSSelectorFromString(seq);
  [charset enumerateSubstringsInRange:NSMakeRange(0, length)
                              options:NSStringEnumerationByComposedCharacterSequences
                           usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                             [cmds addObject:[UIKeyCommand keyCommandWithInput:substring
                                                                 modifierFlags:modifier
                                                                        action:action]];
                             
                             // Capture shift key presses to get transformed and not printed lowercase when CapsLock is Ctrl
                             if (modifier == UIKeyModifierAlphaShift) {
                               [cmds addObjectsFromArray:[self _shiftMaps]];
                             }
                           }];
  
  [_controlKeys setObject:cmds forKey:@(modifier)];
}

- (void)_assignKey:(NSString *)key toModifier:(UIKeyModifierFlags)modifier
{
  NSMutableArray *cmds = [[NSMutableArray alloc] init];
  
  if (key == UIKeyInputEscape) {
    [cmds addObject:[UIKeyCommand keyCommandWithInput:@""
                                        modifierFlags:modifier action:@selector(escSeq:)]];
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
                             [cmds addObject:[UIKeyCommand keyCommandWithInput:substring
                                                                 modifierFlags:UIKeyModifierShift
                                                                        action:@selector(shiftSeq:)]];
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
                                        [functions addObject:[UIKeyCommand keyCommandWithInput:substring
                                                                                 modifierFlags:triggers
                                                                                        action:@selector(fkeySeq:)]];
                                      }];
  }
  
  [_functionTriggerKeys setObject:functions forKey:function];
}

- (NSArray *)_functionModifierKeys
{
  NSMutableArray *f = [NSMutableArray array];
  
  for (NSNumber *modifier in [CC FModifiers]) {
    [f addObject:[UIKeyCommand keyCommandWithInput:UIKeyInputDownArrow
                                     modifierFlags:modifier.intValue
                                            action:@selector(arrowSeq:)]];
    [f addObject:[UIKeyCommand keyCommandWithInput:UIKeyInputUpArrow
                                     modifierFlags:modifier.intValue
                                            action:@selector(arrowSeq:)]];
    [f addObject:[UIKeyCommand keyCommandWithInput:UIKeyInputRightArrow
                                     modifierFlags:modifier.intValue
                                            action:@selector(arrowSeq:)]];
    [f addObject:[UIKeyCommand keyCommandWithInput:UIKeyInputLeftArrow
                                     modifierFlags:modifier.intValue
                                            action:@selector(arrowSeq:)]];
  }
  
  [f addObject:[UIKeyCommand keyCommandWithInput:UIKeyInputEscape
                                   modifierFlags:0
                                          action:@selector(escSeq:)]];
  
  return f;
}

- (NSArray<UIKeyCommand *> *)keyCommands
{
  NSArray<UIKeyCommand *> * commands = _kbdCommands;
  NSString *lang = self.textInputMode.primaryLanguage;
  
  if (lang && [_imeLangSet containsObject:lang]) {
    commands = _kbdCommandsWithoutAutoRepeat;
  }

  return commands;
}

- (BOOL)_capsMapped
{
  NSNumber *key = @(UIKeyModifierAlphaShift);
  
  return ([[_controlKeys objectForKey:key] count] ||
          [[_functionKeys objectForKey:key] count]);
}

- (void)yank:(id)sender
{
  NSString *str = [UIPasteboard generalPasteboard].string;
  
  if (str) {
    [_termDelegate write:str];
  }
  [_termDelegate.termView cleanSelection];
}

- (void)_changeSelection:(UIKeyCommand *) cmd
{
  NSString *input = cmd.input;
  UIKeyModifierFlags flags = cmd.modifierFlags;
  [self _changeSelectionWithInput:input andFlags:flags];
}

- (void)_changeSelectionWithInput:(NSString *)input andFlags: (UIKeyModifierFlags)flags
{
  if ([input isEqualToString:UIKeyInputLeftArrow] || [input isEqualToString:@"h"]) {
    [_termDelegate.termView modifySelectionInDirection:@"left" granularity:
     flags == UIKeyModifierShift ? @"word" : @"character"];
  } else if ([input isEqualToString:UIKeyInputRightArrow] || [input isEqualToString:@"l"]) {
    [_termDelegate.termView modifySelectionInDirection:@"right" granularity:
     flags == UIKeyModifierShift ? @"word" : @"character"];
  } else if ([input isEqualToString:UIKeyInputUpArrow] || [input isEqualToString:@"k"]) {
    [_termDelegate.termView modifySelectionInDirection:@"left" granularity:@"line"];
  } else if ([input isEqualToString:UIKeyInputDownArrow] || [input isEqualToString:@"j"]) {
    [_termDelegate.termView modifySelectionInDirection:@"right" granularity:@"line"];
  } else if ([input isEqualToString:@"o"] || [input isEqualToString:@"x"]) {
    [_termDelegate.termView modifySideOfSelection];
  } else if ([input isEqualToString:@"n"] && flags == UIKeyModifierControl)  {
      [_termDelegate.termView modifySelectionInDirection:@"right" granularity:@"line"];
  } else if ([input isEqualToString:@"p"])  {
    if (flags == UIKeyModifierControl) {
      [_termDelegate.termView modifySelectionInDirection:@"left" granularity:@"line"];
    } else if (flags == kNilOptions) {
      [self pasteSelection:self];
    }
  } else if ([input isEqualToString:@"b"]) {
    if (flags == UIKeyModifierControl) {
      [_termDelegate.termView modifySelectionInDirection:@"left" granularity:@"character"];
    } else if ( (flags & UIKeyModifierAlternate) == UIKeyModifierAlternate) {
      [_termDelegate.termView modifySelectionInDirection:@"left" granularity:@"word"];
    } else {
      [_termDelegate.termView modifySelectionInDirection:@"left" granularity:@"word"];
    }
  } else if ([input isEqualToString:@"w"]) {
    if (flags == UIKeyModifierAlternate)  {
      [_termDelegate.termView copy:self];
    } else {
      [_termDelegate.termView modifySelectionInDirection:@"right" granularity:@"word"];
    }
  } else if ([input isEqualToString:@"f"]) {
    if (flags == UIKeyModifierControl) {
       [_termDelegate.termView modifySelectionInDirection:@"right" granularity:@"character"];
    } else if ((flags & UIKeyModifierAlternate) == UIKeyModifierAlternate) {
      [_termDelegate.termView modifySelectionInDirection:@"right" granularity:@"word"];
    }
  } else if ([input isEqualToString:@"y"]) {
    [_termDelegate.termView copy:self];
  } else if ([input isEqualToString:UIKeyInputEscape]) {
    [_termDelegate.termView cleanSelection];
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

- (BOOL)_remapInput:(NSString *)input forModifier:(const NSString *)modifer {
  NSString *sequence = [BKDefaults keyboardMapping][modifer];
  if ([sequence isEqual:BKKeyboardSeqCtrl]) {
    [self _ctrlSeqWithInput:input];
    return YES;
  } else if ([sequence isEqual:BKKeyboardSeqEsc]) {
    [self _escSeqWithInput:input];
    return YES;
  }
  
  return NO;
}

- (void)_configureShotcuts
{
  [self _resetDefaultControlKeys];
  
  NSMutableArray *ctrls = [[NSMutableArray alloc] init];
  NSMutableArray *escs = [[NSMutableArray alloc] init];
  
  for (NSString *key in [BKDefaults keyboardKeyList]) {
    NSString *sequence = [BKDefaults keyboardMapping][key];
    NSInteger modifier = [bkModifierMaps[key] integerValue];
    
    if ([sequence isEqual:BKKeyboardSeqNone]) {
      [self _assignSequence:nil toModifier:modifier];
    } else if ([sequence isEqual:BKKeyboardSeqCtrl]) {
      [self _assignSequence:TermViewCtrlSeq toModifier:modifier];
      [ctrls addObject:@(modifier)];
    } else if ([sequence isEqual:BKKeyboardSeqEsc]) {
      [self _assignSequence:TermViewEscSeq toModifier:modifier];
      [escs addObject:@(modifier)];
    }
  }
  
  for (NSNumber *ctrl in ctrls) {
    for (NSNumber *esc in escs) {
      NSInteger mod = ctrl.integerValue | esc.integerValue;
      [self _assignSequence:TermViewEscCtrlSeq toModifier:mod];
    }
  }
  
  _controlKeysWithoutAutoRepeat = _controlKeys;
  
  if ([BKDefaults autoRepeatKeys]) {
    _controlKeys = [_controlKeys mutableCopy];
    [self _assignSequence:TermViewAutoRepeateSeq toModifier:kNilOptions];
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
