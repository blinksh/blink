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

#import "BKDefaults.h"

static NSURL *DocumentsDirectory = nil;
static NSURL *DefaultsURL = nil;
BKDefaults *defaults;
@implementation BKDefaults


#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)coder
{
  _keyboardMaps = [coder decodeObjectForKey:@"keyboardMaps"];
  _themeName = [coder decodeObjectForKey:@"themeName"];
  _fontName = [coder decodeObjectForKey:@"fontName"];
  _fontSize = [coder decodeObjectForKey:@"fontSize"];
  _defaultUser = [coder decodeObjectForKey:@"defaultUser"];

  return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
  [encoder encodeObject:_keyboardMaps forKey:@"keyboardMaps"];
  [encoder encodeObject:_themeName forKey:@"themeName"];
  [encoder encodeObject:_fontName forKey:@"fontName"];
  [encoder encodeObject:_fontSize forKey:@"fontSize"];
  [encoder encodeObject:_defaultUser forKey:@"defaultUser"];
}

+ (void)initialize
{
  [BKDefaults loadDefaults];
}
+ (void)loadDefaults
{
  if (DocumentsDirectory == nil) {
    //Hosts = [[NSMutableArray alloc] init];
    DocumentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    DefaultsURL = [DocumentsDirectory URLByAppendingPathComponent:@"defaults"];
  }

  // Load IDs from file
  if ((defaults = [NSKeyedUnarchiver unarchiveObjectWithFile:DefaultsURL.path]) == nil) {
    // Initialize the structure if it doesn't exist
    defaults = [[BKDefaults alloc] init];
    defaults.keyboardMaps = [[NSMutableDictionary alloc] init];
    for (NSString *key in [BKDefaults keyBoardKeyList]) {
      [defaults.keyboardMaps setObject:@"None" forKey:key];
    }
  }
}

+ (BOOL)saveDefaults
{
  // Save IDs to file
  return [NSKeyedArchiver archiveRootObject:defaults toFile:DefaultsURL.path];
}

+ (void)setModifer:(NSString *)modifier forKey:(NSString *)key
{
  if (modifier != nil) {
    [defaults.keyboardMaps setObject:modifier forKey:key];
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


+ (NSMutableArray *)keyboardModifierList
{
  return [NSMutableArray arrayWithObjects:@"None", @"Ctrl", @"Meta", @"Esc", nil];
}

+ (NSMutableArray *)keyBoardKeyList
{
  return [NSMutableArray arrayWithObjects:@"⌃ Ctrl", @"⌘ Cmd", @"⌥ Alt", @"⇪ CapsLock", nil];
}

+ (NSMutableDictionary *)keyBoardMapping
{
  return defaults.keyboardMaps;
}

@end
