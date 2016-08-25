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

#import "BKFont.h"

NSMutableArray *Fonts;

static NSURL *DocumentsDirectory = nil;
static NSURL *FontsURL = nil;

@implementation BKFont

- (instancetype)initWithName:(NSString *)fontName andFilePath:(NSString *)filePath
{
  self = [super init];
  if (self) {
    self.name = fontName;
    self.filepath = filePath;
  }
  return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
  _name = [coder decodeObjectForKey:@"name"];
  _filepath = [coder decodeObjectForKey:@"filepath"];
  return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
  [encoder encodeObject:_name forKey:@"name"];
  [encoder encodeObject:_filepath forKey:@"filepath"];
}

+ (void)initialize
{
  [BKFont loadFonts];
}

+ (instancetype)withFont:(NSString *)aFontName
{
  for (BKFont *font in Fonts) {
    if ([font->_name isEqualToString:aFontName]) {
      return font;
    }
  }
  return nil;
}
+ (NSMutableArray *)all
{
  return Fonts;
}

+ (NSInteger)count
{
  return [Fonts count];
}

+ (instancetype)saveFont:(NSString *)fontName withFilePath:(NSString *)filePath
{
  BKFont *font = [BKFont withFont:fontName];
  if (!font) {
    font = [[BKFont alloc] initWithName:fontName andFilePath:filePath];
    [Fonts addObject:font];
  } else {
    font->_name = fontName;
    font->_filepath = filePath;
  }

  if (![BKFont saveFonts]) {
    // This should never fail, but it is kept for testing purposes.
    return nil;
  }
  return font;
}

+ (void)removeFontAtIndex:(int)index
{
  [Fonts removeObjectAtIndex:index];
}

+ (BOOL)saveFonts
{
  // Save IDs to file
  return [NSKeyedArchiver archiveRootObject:Fonts toFile:FontsURL.path];
}
+ (void)loadFonts
{
  if (DocumentsDirectory == nil) {
    DocumentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    FontsURL = [DocumentsDirectory URLByAppendingPathComponent:@"fonts"];
  }

  // Load IDs from file
  if ((Fonts = [NSKeyedUnarchiver unarchiveObjectWithFile:FontsURL.path]) == nil) {
    // Initialize the structure if it doesn't exist
    Fonts = [[NSMutableArray alloc] init];
  }
}

@end
