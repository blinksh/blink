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


#import "GeoManager.h"
#import <CoreLocation/CoreLocation.h>
#import <ImageIO/ImageIO.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>

NSString * BLGeoLockNotification = @"BLGeoLockNotification";

@interface GeoManager() <CLLocationManagerDelegate>

@end

// https://gist.github.com/rsattar/b06060df7ea293b398d1
NSDictionary *__locationToJson(CLLocation * location) {
  NSMutableDictionary *gps = [NSMutableDictionary dictionary];
  
  // Example:
  /*
   "{GPS}" =     {
   Altitude = "41.28771929824561";
   AltitudeRef = 0;
   DateStamp = "2014:07:21";
   ImgDirection = "68.2140221402214";
   ImgDirectionRef = T;
   Latitude = "37.74252";
   LatitudeRef = N;
   Longitude = "122.42035";
   LongitudeRef = W;
   TimeStamp = "15:53:24";
   };
   */
  
  // GPS tag version
  // According to http://www.cipa.jp/std/documents/e/DC-008-2012_E.pdf,
  // this value is 2.3.0.0
  [gps setObject:@"2.3.0.0" forKey:(NSString *)kCGImagePropertyGPSVersion];
  
  // Time and date must be provided as strings, not as an NSDate object
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
  formatter.dateFormat = @"HH:mm:ss.SSSSSS";
  gps[(NSString *)kCGImagePropertyGPSTimeStamp] = [formatter stringFromDate:location.timestamp];
  formatter.dateFormat = @"yyyy:MM:dd";
  gps[(NSString *)kCGImagePropertyGPSDateStamp] = [formatter stringFromDate:location.timestamp];
  
  // Latitude
  CLLocationDegrees latitude = location.coordinate.latitude;
  gps[(NSString *)kCGImagePropertyGPSLatitudeRef] = (latitude < 0) ? @"S" : @"N";
  gps[(NSString *)kCGImagePropertyGPSLatitude] = @(fabs(latitude));
  
  // Longitude
  CLLocationDegrees longitude = location.coordinate.longitude;
  gps[(NSString *)kCGImagePropertyGPSLongitudeRef] = (longitude < 0) ? @"W" : @"E";
  gps[(NSString *)kCGImagePropertyGPSLongitude] = @(fabs(longitude));
  
  // Degree of Precision
  gps[(NSString *)kCGImagePropertyGPSDOP] = @(location.horizontalAccuracy);
  
  // Altitude
  CLLocationDistance altitude = location.altitude;
  if (!isnan(altitude)) {
    gps[(NSString *)kCGImagePropertyGPSAltitudeRef] = (altitude < 0) ? @(1) : @(0);
    gps[(NSString *)kCGImagePropertyGPSAltitude] = @(fabs(altitude));
  }
  
  // Speed, must be converted from m/s to km/h
  if (location.speed >= 0) {
    gps[(NSString *)kCGImagePropertyGPSSpeedRef] = @"K";
    gps[(NSString *)kCGImagePropertyGPSSpeed] = @(location.speed * (3600.0/1000.0));
  }
  
  // Direction of movement
  if (location.course >= 0) {
    gps[(NSString *)kCGImagePropertyGPSTrackRef] = @"T";
    gps[(NSString *)kCGImagePropertyGPSTrack] = @(location.course);
  }
  
  
  return gps;
}

@implementation GeoManager {
  CLLocationManager * _locManager;
  NSMutableArray<CLLocation *> *_recentLocations;
  NSNumber *_lockDistanceInMeters;
  CLLocation *_lockCenter;
}

- (instancetype)init {
  if (self = [super init]) {
    _recentLocations = [[NSMutableArray alloc] init];
    _locManager = [[CLLocationManager alloc] init];
    _locManager.delegate = self;
    _traking = NO;
  }
  return self;
}

+ (GeoManager *)shared {
  static GeoManager *manager = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    manager = [[self alloc] init];
  });
  return manager;
}

- (void)authorize {
  [_locManager requestWhenInUseAuthorization];
}

- (void)start {
  if (_traking) {
    return;
  }

  _locManager.desiredAccuracy = 100000;
  _locManager.allowsBackgroundLocationUpdates = YES;
  _locManager.pausesLocationUpdatesAutomatically = NO;
  [_locManager startUpdatingLocation];
  
  _traking = YES;
}

- (void)lockInDistance:(NSNumber *)meters {
  if (_traking) {
    return;
  }
  
  _lockDistanceInMeters = meters;
  _locManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
  _locManager.allowsBackgroundLocationUpdates = YES;
  _locManager.pausesLocationUpdatesAutomatically = NO;
  [_locManager startUpdatingLocation];
  
  _traking = YES;
}

- (void)_postLockNotifications {
  [[NSNotificationCenter defaultCenter] postNotificationName:BLGeoLockNotification object:nil];
  UNUserNotificationCenter * center = [UNUserNotificationCenter currentNotificationCenter];
  [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
    if (settings.authorizationStatus != UNAuthorizationStatusAuthorized) {
      return;
    }
    if (settings.alertSetting != UNNotificationSettingEnabled) {
      return;
    }
    
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = @"Geo lock";
    content.body = @"Your device get out of geo range lock.\nAll session are terminated.";
    UNNotificationRequest *req = [UNNotificationRequest requestWithIdentifier:@"geo.lock" content:content trigger:nil];
    
    [center addNotificationRequest:req withCompletionHandler:^(NSError * _Nullable error) {
      
    }];
  }];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
  [_recentLocations addObjectsFromArray:locations];
  
  if (_lockDistanceInMeters) {

    if (_lockCenter) {
      CLLocationDistance distance = [_lockCenter distanceFromLocation:[_recentLocations lastObject]];
      if (distance > _lockDistanceInMeters.doubleValue) {
        [self stop];
        [self _postLockNotifications];
      }
    } else if (_recentLocations.count > 10) {
      _lockCenter = [_recentLocations lastObject];
    }
  }
  
  int maxHistory = 200;
  if (_recentLocations.count > maxHistory) {
    [_recentLocations removeObjectsInRange:NSMakeRange(0, _recentLocations.count - maxHistory)];
  }
}

- (CLLocation * __nullable)lastLocation {
  return [_recentLocations lastObject];
}

- (NSString *)currentJSON {
  CLLocation * loc = [_recentLocations lastObject];
  if (!loc) {
    return @"{}";
  }
  
  NSData *data = [NSJSONSerialization dataWithJSONObject:__locationToJson(loc) options:NSJSONWritingPrettyPrinted error:nil];
  return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (NSString *)lastJSONN:(int)n {
  if (n <= 0) {
    n = 1;
  }
  NSMutableArray *result = [[NSMutableArray alloc] init];
  NSArray *locs = [_recentLocations copy];
  if (locs.count == 0) {
    return @"[]";
  }
  int i = (int)locs.count;
  while (n > 0 && i > 0) {
    i--;
    n--;
  
    CLLocation *loc = locs[i];
    NSDictionary *json = __locationToJson(loc);
    [result addObject: json];
  }
  
  NSData *data = [NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil];
  return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (void)stop {
  if (_lockCenter) {
    [_recentLocations removeAllObjects];
  }
  _lockDistanceInMeters = nil;
  _lockCenter = nil;
  [_locManager stopUpdatingLocation];
  _traking = NO;
}

@end
