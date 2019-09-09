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

#import "BKUserConfigurationManager.h"
#import "BKDefaults.h"

NSString *const BKUserConfigiCloud = @"iCloudSync";
NSString *const BKUserConfigiCloudKeys = @"iCloudKeysSync";
NSString *const BKUserConfigAutoLock = @"autoLock";
NSString *const BKUserConfigShowSmartKeysWithXKeyBoard = @"ShowSmartKeysWithXKeyBoard";
NSString *const BKUserConfigChangedNotification = @"BKUserConfigChangedNotification";


@implementation BKUserConfigurationManager

+ (void)setUserSettingsValue:(BOOL)value forKey:(NSString *)key
{
  NSMutableDictionary *userSettings = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:@"userSettings"]];
  if (userSettings == nil) {
    userSettings = [NSMutableDictionary dictionary];
  }
  [userSettings setObject:[NSNumber numberWithBool:value] forKey:key];
  [[NSUserDefaults standardUserDefaults] setObject:userSettings forKey:@"userSettings"];
  
  [[NSNotificationCenter defaultCenter] postNotificationName:BKUserConfigChangedNotification object:nil];
}

+ (BOOL)userSettingsValueForKey:(NSString *)key
{
  NSDictionary *userSettings = [[NSUserDefaults standardUserDefaults] objectForKey:@"userSettings"];
  if (userSettings != nil) {
    if ([userSettings objectForKey:key]) {
      NSNumber *value = [userSettings objectForKey:key];
      return value.boolValue;
    } else {
      return NO;
    }
  } else {
    return NO;
  }
  return NO;
}


+ (UIKeyModifierFlags)shortCutModifierFlags{
  NSDictionary *bkModifierMaps = @{
                                   BKKeyboardModifierCtrl : [NSNumber numberWithInt:UIKeyModifierControl],
                                   BKKeyboardModifierAlt : [NSNumber numberWithInt:UIKeyModifierAlternate],
                                   BKKeyboardModifierCmd : [NSNumber numberWithInt:UIKeyModifierCommand],
                                   BKKeyboardModifierCaps : [NSNumber numberWithInt:UIKeyModifierAlphaShift],
                                   BKKeyboardModifierShift : [NSNumber numberWithInt:UIKeyModifierShift]
                                   };
  if([[BKDefaults keyboardFuncTriggers]objectForKey:@"Shortcuts"])
  {
    NSArray *shortCutTriggers = [[BKDefaults keyboardFuncTriggers]objectForKey:@"Shortcuts"];
    UIKeyModifierFlags modifiers = 0;
    for (NSString *trigger in shortCutTriggers) {
      NSNumber *modifier = bkModifierMaps[trigger];
      modifiers = modifiers | modifier.intValue;
    }
    return  modifiers;
  }
  return UIKeyModifierCommand;
}

+ (UIKeyModifierFlags)shortCutModifierFlagsForNextPrevShell
{
  return [self shortCutModifierFlags] | UIKeyModifierShift;
}

+ (NSString *)UIKeyModifiersToString:(UIKeyModifierFlags) flags
{
  NSMutableArray *components = [[NSMutableArray alloc] init];
  
  if ((flags & UIKeyModifierShift) == UIKeyModifierShift) {
    [components addObject:@"⇧"];
  }
  
  if ((flags & UIKeyModifierControl) == UIKeyModifierControl) {
    [components addObject:@"⌃"];
  }
  
  if ((flags & UIKeyModifierAlternate) == UIKeyModifierAlternate) {
    [components addObject:@"⌥"];
  }
  
  if ((flags & UIKeyModifierCommand) == UIKeyModifierCommand) {
    [components addObject:@"⌘"];
  }
  
  return [components componentsJoinedByString:@""];
}
@end
