//////////////////////////////////////////////////////////////////////////////////
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


#import "DeviceInfo.h"
#import <UIKit/UIKit.h>

#import <sys/utsname.h>


@implementation DeviceInfo

+ (DeviceInfo *)shared {
  static DeviceInfo *ctrl = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    ctrl = [[self alloc] init];
  });
  return ctrl;
}

- (instancetype)init {
  if (self = [super init]) {
    struct utsname info;
    uname(&info);
    
    _machine = @(info.machine);
    _release_ = @(info.release);
    _sysname = @(info.sysname);
    _nodename = @(info.nodename);
    _version = @(info.version);
    
    NSString *marketingName = self.marketingName;
    
    _hasNotch = [marketingName hasPrefix:@"iPhone X"] || [marketingName hasPrefix:@"iPhone 11"] || [marketingName hasPrefix:@"iPhone 12"];
    _hasCorners = _hasNotch || [_machine hasPrefix:@"iPad8"] || [_machine hasPrefix:@"iPad13"] || [marketingName hasPrefix:@"Mac"];
    
  }
  return self;
}

-(NSString *)marketingName {
  // https://en.wikipedia.org/wiki/List_of_iOS_devices
  
  NSDictionary * codes =
  @{
    @"i386"      : @"Simulator",
    @"arm64"     : @"Simulator",
    @"x86_64"    : @"Simulator",

    @"iPod1,1"   : @"iPod Touch",        // (Original)
    @"iPod2,1"   : @"iPod Touch",        // (Second Generation)
    @"iPod3,1"   : @"iPod Touch",        // (Third Generation)
    @"iPod4,1"   : @"iPod Touch",        // (Fourth Generation)
    @"iPod7,1"   : @"iPod Touch",        // (6th Generation)
    @"iPhone1,1" : @"iPhone",            // (Original)
    @"iPhone1,2" : @"iPhone",            // (3G)
    @"iPhone2,1" : @"iPhone",            // (3GS)
    @"iPad1,1"   : @"iPad",              // (Original)
    @"iPad2,1"   : @"iPad 2",            //
    @"iPad3,1"   : @"iPad",              // (3rd Generation)
    @"iPhone3,1" : @"iPhone 4",          // (GSM)
    @"iPhone3,3" : @"iPhone 4",          // (CDMA/Verizon/Sprint)
    @"iPhone4,1" : @"iPhone 4S",         //
    @"iPhone5,1" : @"iPhone 5",          // (model A1428, AT&T/Canada)
    @"iPhone5,2" : @"iPhone 5",          // (model A1429, everything else)
    @"iPad3,4"   : @"iPad",              // (4th Generation)
    @"iPad2,5"   : @"iPad Mini",         // (Original)
    @"iPhone5,3" : @"iPhone 5c",         // (model A1456, A1532 | GSM)
    @"iPhone5,4" : @"iPhone 5c",         // (model A1507, A1516, A1526 (China), A1529 | Global)
    @"iPhone6,1" : @"iPhone 5s",         // (model A1433, A1533 | GSM)
    @"iPhone6,2" : @"iPhone 5s",         // (model A1457, A1518, A1528 (China), A1530 | Global)
    @"iPhone7,1" : @"iPhone 6 Plus",     //
    @"iPhone7,2" : @"iPhone 6",          //
    @"iPhone8,1" : @"iPhone 6S",         //
    @"iPhone8,2" : @"iPhone 6S Plus",    //
    @"iPhone8,4" : @"iPhone SE",         //
    @"iPhone9,1" : @"iPhone 7",          //
    @"iPhone9,3" : @"iPhone 7",          //
    @"iPhone9,2" : @"iPhone 7 Plus",     //
    @"iPhone9,4" : @"iPhone 7 Plus",     //
    @"iPhone10,1": @"iPhone 8",          // CDMA
    @"iPhone10,4": @"iPhone 8",          // GSM
    @"iPhone10,2": @"iPhone 8 Plus",     // CDMA
    @"iPhone10,5": @"iPhone 8 Plus",     // GSM
    @"iPhone10,3": @"iPhone X",          // CDMA
    @"iPhone10,6": @"iPhone X",          // GSM
    @"iPhone11,2": @"iPhone XS",         //
    @"iPhone11,4": @"iPhone XS Max",     //
    @"iPhone11,6": @"iPhone XS Max",     // China
    @"iPhone11,8": @"iPhone XR",         //
    @"iPhone12,1": @"iPhone 11",
    @"iPhone12,3": @"iPhone 11 Pro",
    @"iPhone12,5": @"iPhone 11 Pro Max",
    
    @"iPhone12,8": @"iPhone SE 2",
    
    @"iPhone13,1": @"iPhone 12 mini",
    @"iPhone13,2": @"iPhone 12",
    @"iPhone13,3": @"iPhone 12 Pro",
    @"iPhone13,4": @"iPhone 12 Pro Max",
                       
    @"iPad4,1"   : @"iPad Air",          // 5th Generation iPad (iPad Air) - Wifi
    @"iPad4,2"   : @"iPad Air",          // 5th Generation iPad (iPad Air) - Cellular
    @"iPad4,4"   : @"iPad Mini",         // (2nd Generation iPad Mini - Wifi)
    @"iPad4,5"   : @"iPad Mini",         // (2nd Generation iPad Mini - Cellular)
    @"iPad4,7"   : @"iPad Mini",         // (3rd Generation iPad Mini - Wifi (model A1599))
    @"iPad6,7"   : @"iPad Pro (12.9\")", // iPad Pro 12.9 inches - (model A1584)
    @"iPad6,8"   : @"iPad Pro (12.9\")", // iPad Pro 12.9 inches - (model A1652)
    @"iPad6,3"   : @"iPad Pro (9.7\")",  // iPad Pro 9.7 inches - (model A1673)
    @"iPad6,4"   : @"iPad Pro (9.7\")",  // iPad Pro 9.7 inches - (models A1674 and A1675)
    
    @"iPad7,1"   : @"iPad Pro (12.9\") 2G (Wi-Fi)",
    @"iPad7,2"   : @"iPad Pro (12.9\") 2G (Cellular)",
    @"iPad7,3"   : @"iPad Pro (10.5\") 1G (Wi-Fi)",
    @"iPad7,4"   : @"iPad Pro (10.5\") 1G (Cellular)",
    
    @"iPad8,1"   : @"iPad Pro (11.0\")",
    @"iPad8,2"   : @"iPad Pro (11.0\")",
    @"iPad8,3"   : @"iPad Pro (11.0\")",
    @"iPad8,4"   : @"iPad Pro (11.0\")",
    
    @"iPad8,5"   : @"iPad Pro (12.9\") 3G",
    @"iPad8,6"   : @"iPad Pro (12.9\") 3G",
    @"iPad8,7"   : @"iPad Pro (12.9\") 3G",
    @"iPad8,8"   : @"iPad Pro (12.9\") 3G",
    
    @"iPad8,9"   : @"iPad Pro (11.0\") 2G",
    @"iPad8,10"  : @"iPad Pro (11.0\") 2G",
    
    @"iPad8,11" : @"iPad Pro (12.9\") 4G",
    @"iPad8,12" : @"iPad Pro (12.9\") 4G",
    
    @"iPad11,1" : @"iPad Mini 5", // wifi
    @"iPad11,2" : @"iPad Mini 5", // cellular
    
    @"iPad11,3" : @"iPad Air 3",  // wifi
    @"iPad11,4" : @"iPad Air 3",  // cellular
    
    @"iPad13,1" : @"iPad Air 4",  // wifi
    @"iPad13,2" : @"iPad Air 4",  // cellular
  };
  
  NSString *value = codes[_machine];
  if (value) {
    if ([value isEqualToString:@"Simulator"]) {
#ifdef TARGET_OS_MACCATALYST
      return @"Mac";
#else
      return [UIDevice currentDevice].name;
#endif
    }
    return value;
  }
  return @"unknown";
}


@end
