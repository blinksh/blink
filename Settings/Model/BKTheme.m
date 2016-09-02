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

#import "BKTheme.h"

NSMutableArray *Themes;

static NSURL *DocumentsDirectory = nil;
static NSURL *BKSavedThemesURL = nil;
static NSURL *ThemesURL = nil;

@implementation BKTheme

- (instancetype)initWithName:(NSString *)themeName andFileName:(NSString *)fileName
{
  self = [super init];
  if (self) {
    self.name = themeName;
    self.filename = fileName;
  }
  return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
  _name = [coder decodeObjectForKey:@"title"];
  _filename = [coder decodeObjectForKey:@"filename"];
  return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
  [encoder encodeObject:_name forKey:@"title"];
  [encoder encodeObject:_filename forKey:@"filename"];
}

- (NSString *)content
{  
  NSString *filepath = [[BKSavedThemesURL URLByAppendingPathComponent:self.filename] path];

  return [NSString stringWithContentsOfFile:filepath encoding:NSUTF8StringEncoding error:nil];
}

+ (void)initialize
{
  [BKTheme loadThemes];  
}

+ (instancetype)withTheme:(NSString *)themeName
{
  for (BKTheme *theme in Themes) {
    if ([theme->_name isEqualToString:themeName]) {
      return theme;
    }
  }
  return nil;
}

+ (NSMutableArray *)all
{
  return Themes;
}

+ (NSInteger)count
{
  return [Themes count];
}

+ (BOOL)saveThemes
{
  // Save IDs to file
  return [NSKeyedArchiver archiveRootObject:Themes toFile:ThemesURL.path];
}

+ (instancetype)saveTheme:(NSString *)themeName withContent:(NSData *)content error:(NSError * __autoreleasing *)error
{
  NSString *fileName = [[NSUUID UUID] UUIDString];

  NSURL *filePath = [BKSavedThemesURL URLByAppendingPathComponent:fileName];
  [[NSFileManager defaultManager] createDirectoryAtURL:BKSavedThemesURL withIntermediateDirectories:YES attributes:nil error:nil];
    
  [content writeToURL:filePath options:NSDataWritingAtomic error:error];

  if (*error) {
    return nil;
  }

  BKTheme *theme = [[BKTheme alloc] initWithName:themeName andFileName:fileName];
  [Themes addObject:theme];
  
  if (![BKTheme saveThemes]) {
    // This should never fail, but it is kept for testing purposes.
    return nil;
  }
  return theme;
}

+ (void)removeThemeAtIndex:(int)index
{
  [Themes removeObjectAtIndex:index];
}

+ (void)loadThemes
{
  if (DocumentsDirectory == nil) {
    DocumentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    ThemesURL = [DocumentsDirectory URLByAppendingPathComponent:@"themes"];
    BKSavedThemesURL = [DocumentsDirectory URLByAppendingPathComponent:@"ThemesDir"];
  }

  // Load IDs from file
  if ((Themes = [NSKeyedUnarchiver unarchiveObjectWithFile:ThemesURL.path]) == nil) {
    // Initialize the structure if it doesn't exist
    Themes = [[NSMutableArray alloc] init];
  }
}

@end
