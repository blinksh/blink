//
//  UIDevice+DeviceName.h
//  Blink
//
//  Created by Atul M on 31/10/16.
//  Copyright © 2016 Carlos Cabañero Projects SL. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum{
  BKDeviceInfoTypeDeviceName,
  BKDeviceInfoTypeUserName
}BKDeviceInfoType;

@interface UIDevice (DeviceName)

+ (NSString*)getInfoTypeFromDeviceName:(BKDeviceInfoType)type;

@end
