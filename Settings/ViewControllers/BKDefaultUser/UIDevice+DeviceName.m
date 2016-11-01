//
//  UIDevice+DeviceName.m
//  Blink
//
//  Created by Atul M on 31/10/16.
//  Copyright © 2016 Carlos Cabañero Projects SL. All rights reserved.
//

#import "UIDevice+DeviceName.h"

@implementation UIDevice (DeviceName)

+ (NSString*)userNameFromDeviceName
{
  NSString *deviceName = [[UIDevice currentDevice] name];
  NSCharacterSet* characterSet = [NSCharacterSet characterSetWithCharactersInString:@" '’\\"];
  NSArray* words = [deviceName componentsSeparatedByCharactersInSet:characterSet];
  NSMutableArray* names = [[NSMutableArray alloc] init];
  
  bool foundShortWord = false;
  for (NSString __strong *word in words)
  {
    if ([word length] <= 2)
      foundShortWord = true;
    if ([word compare:@"iPhone"] != 0 && [word compare:@"iPod"] != 0 && [word compare:@"iPad"] != 0 && [word length] > 2)
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
  return [names[0]lowercaseString];
}


@end
