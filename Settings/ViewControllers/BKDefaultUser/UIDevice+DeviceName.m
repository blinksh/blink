//
//  UIDevice+DeviceName.m
//  Blink
//
//  Created by Atul M on 31/10/16.
//  Copyright © 2016 Carlos Cabañero Projects SL. All rights reserved.
//

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
