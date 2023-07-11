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

#import <Foundation/Foundation.h>

#import <BlinkConfig/BlinkConfig-Swift.h>


extern NSString *const BKAppearanceChanged;

typedef NS_ENUM(NSInteger, BKLayoutMode) {
  BKLayoutModeDefault = 0,
  BKLayoutModeFill, // Fit screen
  BKLayoutModeCover, //  Cover screen
  BKLayoutModeSafeFit, // Honors safe layout guides
};

typedef NS_ENUM(NSInteger, BKOverscanCompensation) {
  BKBKOverscanCompensationScale = 0,
  BKBKOverscanCompensationInsetBounds,
  BKBKOverscanCompensationNone,
  BKBKOverscanCompensationMirror,
};

typedef NS_ENUM(NSInteger, BKKeyboardStyle) {
  BKKeyboardStyleDark = 0,
  BKKeyboardStyleLight,
  BKKeyboardStyleSystem,
};

@interface BLKDefaults : NSObject <NSSecureCoding>

@property (nonatomic, strong) NSString *themeName;
@property (nonatomic, strong) NSString *fontName;
@property (nonatomic, strong) NSNumber *fontSize;
@property (nonatomic, strong) NSNumber *externalDisplayFontSize;
@property (nonatomic, strong) NSString *defaultUser;
@property (nonatomic, strong) BKGlobalSSHConfig *globalSSHConfig;
@property (nonatomic) BOOL cursorBlink;
@property (nonatomic) NSUInteger enableBold;
@property (nonatomic) BOOL boldAsBright;
@property (nonatomic) BKKeyboardStyle keyboardStyle;
@property (nonatomic) BOOL alternateAppIcon;
@property (nonatomic) BOOL keycasts;
@property (nonatomic) BKLayoutMode layoutMode;
@property (nonatomic) BKOverscanCompensation overscanCompensation;
@property (nonatomic) BOOL xCallBackURLEnabled;
@property (nonatomic) NSString *xCallBackURLKey;
@property (nonatomic) BOOL disableCustomKeyboards;
@property (nonatomic) BOOL playSoundOnBell;
@property (nonatomic) BOOL notificationOnBellUnfocused;
@property (nonatomic) BOOL hapticFeedbackOnBellOff;
@property (nonatomic) BOOL oscNotifications;
@property (nonatomic) BOOL invertVerticalScroll;
@property (nonatomic) BOOL compactQuickActions;

+ (void)loadDefaults;
+ (BOOL)saveDefaults;
+ (void)setCursorBlink:(BOOL)state;
+ (void)setBoldAsBright:(BOOL)state;
+ (void)setEnableBold:(NSUInteger)state;
+ (void)setAlternateAppIcon:(BOOL)state;
+ (void)setKeycasts:(BOOL)state;
+ (void)setXCallBackURLEnabled:(BOOL)state;
+ (void)setXCallBackURLKey:(NSString *)key;
+ (void)setDisableCustomKeyboards:(BOOL)state;
+ (void)setFontName:(NSString *)fontName;
+ (void)setThemeName:(NSString *)themeName;
+ (void)setFontSize:(NSNumber *)fontSize;
+ (void)setExternalDisplayFontSize:(NSNumber *)fontSize;
+ (void)setPlaySoundOnBell:(BOOL)state;
+ (void)setNotificationOnBellUnfocused:(BOOL)state;
+ (void)setHapticFeedbackOnBellOff:(BOOL)state;
+ (void)setOscNotifications:(BOOL)state;
+ (void)setInvertedVerticalScroll:(BOOL) state;
+ (void)setCompactQuickActions:(BOOL)value;
+ (NSString *)selectedFontName;
+ (NSString *)selectedThemeName;
+ (NSNumber *)selectedFontSize;
+ (NSNumber *)selectedExternalDisplayFontSize;
+ (BOOL)isCursorBlink;
+ (NSUInteger)enableBold;
+ (BOOL)isBoldAsBright;
+ (BOOL)isAlternateAppIcon;
+ (BOOL)isKeyCastsOn;
+ (BOOL)isXCallBackURLEnabled;
+ (NSString *)xCallBackURLKey;
+ (BOOL)disableCustomKeyboards;
+ (void)setDefaultUserName:(NSString*)name;
+ (void)saveGlobalSSHConfig;
+ (NSString*)defaultUserName;
+ (BKLayoutMode)layoutMode;
+ (BKOverscanCompensation)overscanCompensation;
+ (BKKeyboardStyle)keyboardStyle;
+ (void)setLayoutMode:(BKLayoutMode)mode;
+ (void)setOversanCompensation:(BKOverscanCompensation)value;
+ (void)setKeyboardStyle:(BKKeyboardStyle)value;
+ (BOOL)isPlaySoundOnBellOn;
+ (BOOL)isNotificationOnBellUnfocusedOn;
+ (BOOL)hapticFeedbackOnBellOff;
+ (BOOL)isOscNotificationsOn;
+ (BOOL)doInvertVerticalScroll;
+ (BOOL)compactQuickActions;

+ (void)applyExternalScreenCompensation:(BKOverscanCompensation)value;
@end
