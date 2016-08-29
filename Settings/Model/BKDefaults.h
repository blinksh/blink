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

#import <Foundation/Foundation.h>

extern NSString const *BKKeyboardModifierCtrl;
extern NSString const *BKKeyboardModifierAlt;
extern NSString const *BKKeyboardModifierCmd;
extern NSString const *BKKeyboardModifierCaps;
extern NSString const *BKKeyboardModifierShift;

extern NSString const *BKKeyboardSeqNone;
extern NSString const *BKKeyboardSeqCtrl;
extern NSString const *BKKeyboardSeqEsc;
extern NSString const *BKKeyboardSeqMeta;

extern NSString const *BKKeyboardFuncFTriggers;
extern NSString const *BKKeyboardFuncCursorTriggers;
extern NSString const *BKKeyboardFuncShortcutTriggers;

@interface BKDefaults : NSObject <NSCoding>

@property (nonatomic, strong) NSMutableDictionary *keyboardMaps;
@property (nonatomic, strong) NSMutableDictionary *keyboardFuncTriggers;
@property (nonatomic, strong) NSString *themeName;
@property (nonatomic, strong) NSString *fontName;
@property (nonatomic, strong) NSNumber *fontSize;
@property (nonatomic, strong) NSString *defaultUser;
@property (nonatomic) BOOL capsAsEsc;
@property (nonatomic) BOOL shiftAsEsc;

+ (void)initialize;
+ (BOOL)saveDefaults;
+ (void)setModifer:(NSString *)modifier forKey:(NSString *)key;
+ (void)setCapsAsEsc:(BOOL)state;
+ (void)setShiftAsEsc:(BOOL)state;
+ (void)setTriggers:(NSArray *)triggers forFunction:(NSString *)func;
+ (void)setFontName:(NSString *)fontName;
+ (void)setThemeName:(NSString *)themeName;
+ (void)setFontSize:(NSNumber *)fontSize;
+ (NSString *)selectedFontName;
+ (NSString *)selectedThemeName;
+ (NSNumber *)selectedFontSize;
+ (NSArray *)keyboardModifierList;
+ (NSArray *)keyboardFuncTriggersList;
+ (NSArray *)keyboardKeyList;
+ (NSDictionary *)keyboardMapping;
+ (NSDictionary *)keyboardFuncTriggers;
+ (BOOL)isCapsAsEsc;
+ (BOOL)isShiftAsEsc;
@end
