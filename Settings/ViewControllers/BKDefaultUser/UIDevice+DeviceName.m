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

#import "UIDevice+DeviceName.h"

#define DEFAULT_USER_NAME @"user"
#define DEFAULT_DEVICE_NAME @"blink"

@implementation UIDevice (DeviceName)

+ (NSString*)getInfoTypeFromDeviceName:(BKDeviceInfoType)type
{
  NSString *deviceName = [[UIDevice currentDevice] name];
  NSCharacterSet* characterSet = [NSCharacterSet characterSetWithCharactersInString:@" '’\\"];
  NSArray* words = [deviceName componentsSeparatedByCharactersInSet:characterSet];
  NSMutableArray* names = [[NSMutableArray alloc] init];
  NSString *deviceType = @"";
  bool foundShortWord = false;
  for (NSString __strong *word in words)
  {
    if ([word length] <= 2)
      foundShortWord = true;
    if([word containsString:@"iPhone"] || [word containsString:@"iPod"] || [word containsString:@"iPad"] || [word containsString:@"Mac"])
    {
      deviceType = word;
    }
    else if ([word length] > 2)
    {
      word = [word stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:[[word substringToIndex:1] uppercaseString]];
      [names addObject:word];
    }
  }
  if (!foundShortWord && [names count] > 1)
  {
    unsigned long lastNameIndex = [names count] - 1;
    NSString* name = [names objectAtIndex:lastNameIndex];
    unichar lastChar = [name characterAtIndex:[name length] - 1];
    if (lastChar == 's')
    {
      [names replaceObjectAtIndex:lastNameIndex withObject:[name substringToIndex:[name length] - 1]];
    }
  }
  if (type == BKDeviceInfoTypeUserName)
  {
    if(names.count > 0 && [names[0]length] > 0)
    {
      return [names[0]lowercaseString];
    }else
    {
      return DEFAULT_USER_NAME;
    }
  }else
  {
    if(deviceType.length > 0)
    {
      return [deviceType lowercaseString];
    }else
    {
      return DEFAULT_DEVICE_NAME;
    }
  }
}


@end
