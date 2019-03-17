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
#import "BKFont.h"
#import "UIDevice+DeviceName.h"
#import "BlinkPaths.h"
#import "LayoutManager.h"

BKDefaults *defaults;

NSString const *BKKeyboardModifierCtrl = @"⌃ Ctrl";
NSString const *BKKeyboardModifierAlt  = @"⌥ Alt";
NSString const *BKKeyboardModifierCmd  = @"⌘ Cmd";
NSString const *BKKeyboardModifierCaps = @"⇪ CapsLock";
NSString const *BKKeyboardModifierShift = @"⇧ Shift";

NSString const *BKKeyboardSeqNone = @"None";
NSString const *BKKeyboardSeqCtrl = @"Ctrl";
NSString const *BKKeyboardSeqEsc  = @"Esc";
NSString const *BKKeyboardSeqMeta = @"Meta";

NSString const *BKKeyboardFuncFTriggers = @"Function Keys";
NSString const *BKKeyboardFuncCursorTriggers = @"Cursor Keys";
NSString const *BKKeyboardFuncShortcutTriggers = @"Shortcuts";


@implementation BKDefaults

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)coder
{
  _keyboardMaps = [coder decodeObjectForKey:@"keyboardMaps"];
  _keyboardFuncTriggers = [coder decodeObjectForKey:@"keyboardFuncTriggers"];
  _themeName = [coder decodeObjectForKey:@"themeName"];
  _fontName = [coder decodeObjectForKey:@"fontName"];
  _fontSize = [coder decodeObjectForKey:@"fontSize"];
  _defaultUser = [coder decodeObjectForKey:@"defaultUser"];
  _capsAsEsc = [coder decodeBoolForKey:@"capsAsEsc"];
  _capsAsCtrl = [coder decodeBoolForKey:@"capsAsCtrl"];
  _shiftAsEsc = [coder decodeBoolForKey:@"shiftAsEsc"];
  _backquoteAsEsc = [coder decodeBoolForKey:@"backquoteAsEsc"];
  _autoRepeatKeys = [coder decodeBoolForKey:@"autoRepeatKeys"];
  _grabCtrlSpace = [coder decodeBoolForKey:@"grabCtrlSpace"];
  _cursorBlink = [coder decodeBoolForKey:@"cursorBlink"];
  _enableBold = [coder decodeIntegerForKey:@"enableBold"];
  _boldAsBright = [coder decodeBoolForKey:@"boldAsBright"];
  _lightKeyboard = [coder decodeBoolForKey:@"lightKeyboard"];
  _alternateAppIcon = [coder decodeBoolForKey:@"alternateAppIcon"];
  _layoutMode = (BKLayoutMode)[coder decodeIntegerForKey:@"layoutMode"];
  _xCallBackURLEnabled = [coder decodeBoolForKey:@"xCallBackURLEnabled"];
  _xCallBackURLKey = [coder decodeObjectForKey:@"xCallBackURLKey"];
  return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
  [encoder encodeObject:_keyboardMaps forKey:@"keyboardMaps"];
  [encoder encodeObject:_keyboardFuncTriggers forKey:@"keyboardFuncTriggers"];
  [encoder encodeObject:_themeName forKey:@"themeName"];
  [encoder encodeObject:_fontName forKey:@"fontName"];
  [encoder encodeObject:_fontSize forKey:@"fontSize"];
  [encoder encodeObject:_defaultUser forKey:@"defaultUser"];
  [encoder encodeBool:_capsAsEsc forKey:@"capsAsEsc"];
  [encoder encodeBool:_capsAsCtrl forKey:@"capsAsCtrl"];
  [encoder encodeBool:_shiftAsEsc forKey:@"shiftAsEsc"];
  [encoder encodeBool:_backquoteAsEsc forKey:@"backquoteAsEsc"];
  [encoder encodeBool:_autoRepeatKeys forKey:@"autoRepeatKeys"];
  [encoder encodeBool:_grabCtrlSpace forKey:@"grabCtrlSpace"];
  [encoder encodeBool:_cursorBlink forKey:@"cursorBlink"];
  [encoder encodeInteger:_enableBold forKey:@"enableBold"];
  [encoder encodeBool:_boldAsBright forKey:@"boldAsBright"];
  [encoder encodeBool:_lightKeyboard forKey:@"lightKeyboard"];
  [encoder encodeBool:_alternateAppIcon forKey:@"alternateAppIcon"];
  [encoder encodeInteger:_layoutMode forKey:@"layoutMode"];
  [encoder encodeBool:_xCallBackURLEnabled forKey:@"xCallBackURLEnabled"];
  [encoder encodeObject:_xCallBackURLKey forKey:@"xCallBackURLKey"];
}

+ (void)loadDefaults
{
  // Load IDs from file
  defaults = [NSKeyedUnarchiver unarchiveObjectWithFile:[BlinkPaths defaultsFile]];
  if (!defaults) {
    // Initialize the structure if it doesn't exist
    defaults = [[BKDefaults alloc] init];
    defaults.autoRepeatKeys = YES;
  }
  
  if (!defaults.keyboardMaps) {
    [defaults setDefaultKeyboardMaps];
  }
  if (!defaults.keyboardFuncTriggers) {
    [defaults setDefaultKeyboardFuncTriggers];
  }
  
  if (defaults.layoutMode == BKLayoutModeDefault) {
    defaults.layoutMode = [LayoutManager deviceDefaultLayoutMode];
  }

  if (!defaults.fontName) {
    if ([BKFont withName:@"Pragmata Pro Mono"] != nil) {
      [defaults setFontName:@"Pragmata Pro Mono"];
    } else {
      [defaults setFontName:@"Source Code Pro"];
    }
  }
  if (!defaults.themeName) {
    [defaults setThemeName:@"Default"];
  }
  
  if (!defaults.fontSize) {
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
      [defaults setFontSize:[NSNumber numberWithInt:18]];
    } else {
      [defaults setFontSize:[NSNumber numberWithInt:10]];
    }
  }
  if(!defaults.defaultUser || ![[defaults.defaultUser stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length]){
    [defaults setDefaultUser:[UIDevice getInfoTypeFromDeviceName:BKDeviceInfoTypeUserName]];
  }
}

- (void)setDefaultKeyboardMaps {
  self.keyboardMaps = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                           BKKeyboardSeqCtrl, BKKeyboardModifierCtrl,
                           BKKeyboardSeqNone, BKKeyboardModifierAlt,
                           BKKeyboardSeqNone, BKKeyboardModifierCmd,
                           BKKeyboardSeqNone, BKKeyboardModifierCaps,
                           nil];
}

- (void)setDefaultKeyboardFuncTriggers {
  self.keyboardFuncTriggers = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                   @[BKKeyboardModifierCmd], BKKeyboardFuncFTriggers,
                                   @[BKKeyboardModifierCmd], BKKeyboardFuncCursorTriggers,
                                   @[BKKeyboardModifierCmd], BKKeyboardFuncShortcutTriggers, nil];
  
  defaults.capsAsEsc = NO;
  defaults.capsAsCtrl = NO;
  defaults.shiftAsEsc = NO;
  defaults.backquoteAsEsc = NO;
}

+ (BOOL)saveDefaults
{
  // Save IDs to file
  return [NSKeyedArchiver archiveRootObject:defaults toFile:[BlinkPaths defaultsFile]];
}

+ (void)setModifer:(NSString *)modifier forKey:(NSString *)key
{
  if (modifier != nil) {
    [defaults.keyboardMaps setObject:modifier forKey:key];
  }
}

+ (void)setCapsAsEsc:(BOOL)state
{
  defaults.capsAsEsc = state;
}

+ (void)setCapsAsCtrl:(BOOL)state
{
  defaults.capsAsCtrl = state;
}

+ (void)setShiftAsEsc:(BOOL)state
{
  defaults.shiftAsEsc = state;
}

+ (void)setBackquoteAsEsc:(BOOL)state
{
  defaults.backquoteAsEsc = state;
}

+ (void)setAutoRepeatKeys:(BOOL)state
{
  defaults.autoRepeatKeys = state;
}

+ (void)setGrabCtrlSpace:(BOOL)state
{
  defaults.grabCtrlSpace = state;
}

+ (void)setCursorBlink:(BOOL)state
{
  defaults.cursorBlink = state;
}

+ (void)setBoldAsBright:(BOOL)state
{
  defaults.boldAsBright = state;
}

+ (void)setLightKeyboard:(BOOL)state
{
  defaults.lightKeyboard = state;
}

+ (void)setAlternateAppIcon:(BOOL)state
{
  defaults.alternateAppIcon = state;
}

+ (void)setEnableBold:(NSUInteger)state
{
  defaults.enableBold = state;
}

+ (void)setTriggers:(NSArray *)triggers forFunction:(NSString *)func
{
  if (triggers.count && [@[BKKeyboardFuncFTriggers, BKKeyboardFuncCursorTriggers, BKKeyboardFuncShortcutTriggers] containsObject:func]) {
    [defaults.keyboardFuncTriggers setObject:triggers forKey:func];
  }
}

+ (void)setFontName:(NSString *)fontName
{
  defaults.fontName = fontName;
}

+ (void)setThemeName:(NSString *)themeName
{
  defaults.themeName = themeName;
}

+ (void)setFontSize:(NSNumber *)fontSize
{
  defaults.fontSize = fontSize;
}

+ (void)setDefaultUserName:(NSString*)name
{
  defaults.defaultUser = name;
}

+ (void)setLayoutMode:(BKLayoutMode)mode {
  defaults.layoutMode = mode;
}

+ (void)setXCallBackURLEnabled:(BOOL)value {
  defaults.xCallBackURLEnabled = value;
}

+ (void)setXCallBackURLKey:(NSString *)key {
  defaults.xCallBackURLKey = key;
}

+ (NSString *)selectedFontName
{
  return defaults.fontName;
}
+ (NSString *)selectedThemeName
{
  return defaults.themeName;
}
+ (NSNumber *)selectedFontSize
{
  return defaults.fontSize;
}

+ (NSArray *)keyboardModifierList
{
  return @[BKKeyboardSeqNone, BKKeyboardSeqCtrl, BKKeyboardSeqEsc];
}

+ (NSArray *)keyboardFuncTriggersList
{
  return @[BKKeyboardModifierCtrl, BKKeyboardModifierAlt, BKKeyboardModifierCmd, BKKeyboardModifierShift];
}


+ (NSArray *)keyboardKeyList
{
  return @[BKKeyboardModifierCtrl, BKKeyboardModifierAlt,
			 BKKeyboardModifierCmd, BKKeyboardModifierCaps];
}

+ (NSDictionary *)keyboardMapping
{
  return defaults.keyboardMaps;
}

+ (NSDictionary *)keyboardFuncTriggers
{
  return defaults.keyboardFuncTriggers;
}

+ (BOOL)isCapsAsEsc
{
  return defaults.capsAsEsc;
}

+ (BOOL)isCapsAsCtrl
{
  return defaults.capsAsCtrl;
}

+ (BOOL)isShiftAsEsc
{
  return defaults.shiftAsEsc;
}

+ (BOOL)isBackquoteAsEsc
{
  return defaults.backquoteAsEsc;
}

+ (BOOL)autoRepeatKeys
{
  return defaults.autoRepeatKeys;
}

+ (BOOL)grabCtrlSpace
{
  return defaults.grabCtrlSpace;
}

+ (BOOL)isCursorBlink
{
  return defaults.cursorBlink;
}

+ (NSUInteger)enableBold
{
  return defaults.enableBold;
}

+ (BOOL)isBoldAsBright
{
  return defaults.boldAsBright;
}

+ (BOOL)isLightKeyboard
{
  return defaults.lightKeyboard;
}

+ (BOOL)isAlternateAppIcon
{
  return defaults.alternateAppIcon;
}

+ (NSString*)defaultUserName
{
  return defaults.defaultUser;
}

+ (BKLayoutMode)layoutMode
{
  return defaults.layoutMode;
}

+ (BOOL)isXCallBackURLEnabled
{
  return defaults.xCallBackURLEnabled;
}

+ (NSString *)xCallBackURLKey
{
  return defaults.xCallBackURLKey;
}

@end
