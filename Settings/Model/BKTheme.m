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

NSMutableArray *CustomThemes;
NSMutableArray *DefaultThemes;

static NSURL *DocumentsDirectory = nil;
static NSURL *BKSavedThemesURL = nil;
static NSURL *BKDefaultThemesURL = nil;
static NSURL *BKCustomThemesURL = nil;

@implementation BKTheme {
  NSURL *_fileURL;
}

- (instancetype)initWithName:(NSString *)themeName andFileName:(NSString *)fileName onURL:(NSURL *)fileURL
{
  self = [super init];
  if (self) {
    self.name = themeName;
    self.filename = fileName;
    _fileURL = fileURL;
  }
  return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
  _name = [coder decodeObjectForKey:@"title"];
  _filename = [coder decodeObjectForKey:@"filename"];
  // Only Custom is initialized with URL
  _fileURL = BKSavedThemesURL;
  return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
  [encoder encodeObject:_name forKey:@"title"];
  [encoder encodeObject:_filename forKey:@"filename"];
}

- (NSString *)content
{
  NSString *filepath = [[_fileURL URLByAppendingPathComponent:self.filename] path];
  return [NSString stringWithContentsOfFile:filepath encoding:NSUTF8StringEncoding error:nil];
}

+ (void)initialize
{
  [BKTheme loadThemes];
}

+ (instancetype)withTheme:(NSString *)themeName
{
  for (BKTheme *theme in [BKTheme all]) {
    if ([theme->_name isEqualToString:themeName]) {
      return theme;
    }
  }
  return nil;
}

+ (NSArray *)all
{
  return [DefaultThemes arrayByAddingObjectsFromArray:CustomThemes];
}

+ (NSInteger)count
{
  return [self.all count];
}

+ (NSInteger)defaultThemesCount
{
  return [DefaultThemes count];
}

+ (BOOL)saveThemes
{
  // Save IDs to file
  return [NSKeyedArchiver archiveRootObject:CustomThemes toFile:BKCustomThemesURL.path];
}

+ (instancetype)saveTheme:(NSString *)themeName withContent:(NSData *)content error:(NSError *__autoreleasing *)error
{
  NSString *fileName = [[NSUUID UUID] UUIDString];

  NSURL *filePath = [BKSavedThemesURL URLByAppendingPathComponent:fileName];
  [[NSFileManager defaultManager] createDirectoryAtURL:BKSavedThemesURL withIntermediateDirectories:YES attributes:nil error:nil];

  [content writeToURL:filePath options:NSDataWritingAtomic error:error];

  if (*error) {
    return nil;
  }

  BKTheme *theme = [[BKTheme alloc] initWithName:themeName andFileName:fileName onURL:BKSavedThemesURL];
  [CustomThemes addObject:theme];

  if (![BKTheme saveThemes]) {
    // This should never fail, but it is kept for testing purposes.
    return nil;
  }
  return theme;
}

+ (void)removeThemeAtIndex:(int)index
{
  [CustomThemes removeObjectAtIndex:index - [BKTheme defaultThemesCount]];
  [BKTheme saveThemes];
}

+ (void)loadThemes
{
  [self loadDefaultThemes];
  [self loadCustomThemes];
}

+ (void)loadDefaultThemes
{
  // Load Default themes
  BKDefaultThemesURL = [[[NSBundle mainBundle] resourceURL] URLByAppendingPathComponent:@"Themes"];
  NSError *error = nil;
  NSArray *properties = [NSArray arrayWithObjects:NSURLLocalizedNameKey, nil];

  NSArray *themeFiles = [[NSFileManager defaultManager]
      contentsOfDirectoryAtURL:BKDefaultThemesURL
    includingPropertiesForKeys:properties
                       options:(NSDirectoryEnumerationSkipsHiddenFiles)
                         error:&error];

  DefaultThemes = [[NSMutableArray alloc] init];
  if (themeFiles != nil) {
    for (NSURL *file in themeFiles) {
      NSString *fileName = [file lastPathComponent];
      BKTheme *theme = [[BKTheme alloc] initWithName:[fileName stringByReplacingOccurrencesOfString:@".js" withString:@""]
                                         andFileName:fileName
                                               onURL:BKDefaultThemesURL];
      [DefaultThemes addObject:theme];
    }
  }
}

+ (void)loadCustomThemes
{
  if (DocumentsDirectory == nil) {
    DocumentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    BKCustomThemesURL = [DocumentsDirectory URLByAppendingPathComponent:@"themes"];
    BKSavedThemesURL = [DocumentsDirectory URLByAppendingPathComponent:@"ThemesDir"];
  }

  // Load IDs from file
  if ((CustomThemes = [NSKeyedUnarchiver unarchiveObjectWithFile:BKCustomThemesURL.path]) == nil) {
    // Initialize the structure if it doesn't exist
    CustomThemes = [[NSMutableArray alloc] init];
  }
}

@end
