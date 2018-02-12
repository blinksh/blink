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

#import "BKTouchIDAuthManager.h"
#import "BKUserConfigurationManager.h"
#import "Blink-swift.h"

const NSNotificationName BKUserAuthenticated = @"BKUserAuthenticated";

@import LocalAuthentication;

#define MAX_INTERVAL_INACTIVE 10 * 60

static BKTouchIDAuthManager *sharedManager = nil;
static BOOL authRequired = NO;

@implementation BKTouchIDAuthManager {
  NSTimeInterval inactiveTimeStamp;
}

+ (instancetype)sharedManager
{
  if ([BKUserConfigurationManager userSettingsValueForKey:BKUserConfigAutoLock]) {
    if (sharedManager == nil) {
      sharedManager = [[self alloc] init];
    }
    return sharedManager;
  } else {
    //If user settings is turned off, return nil, so that all messages are ignored
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    return nil;
  }
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    authRequired = YES;
  }
  return self;
}
- (void)registerforDeviceLockNotif
{
  //Screen lock notifications
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayStatusChanged:) name:UIApplicationDidEnterBackgroundNotification object:nil];
//  CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), //center
//				  NULL,                                        // observer
//				  displayStatusChanged,                        // callback
//				  CFSTR("com.apple.springboard.lockcomplete"), // event name
//				  NULL,                                        // object
//				  CFNotificationSuspensionBehaviorDeliverImmediately);
//
//  CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), //center
//				  NULL,                                        // observer
//				  displayStatusChanged,                        // callback
//				  CFSTR("com.apple.springboard.lockstate"),    // event name
//				  NULL,                                        // object
//				  CFNotificationSuspensionBehaviorDeliverImmediately);

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
}


- (void)didBecomeActive:(NSNotification *)notification
{
  if (authRequired == NO && inactiveTimeStamp != 0) {
    authRequired = ([[NSDate date] timeIntervalSince1970] - inactiveTimeStamp) > MAX_INTERVAL_INACTIVE;
  }
  inactiveTimeStamp = 0;
  if ([BKTouchIDAuthManager requiresTouchAuth]) {
    [self authenticateUser];
  }
}

//call back
//static void displayStatusChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
- (void) displayStatusChanged:(NSNotification *)notification
{
  // the "com.apple.springboard.lockcomplete" notification will always come after the "com.apple.springboard.lockstate" notification
  inactiveTimeStamp = [[NSDate date] timeIntervalSince1970];
  //authRequired = YES;
}

+ (BOOL)requiresTouchAuth
{
  return authRequired && [BKUserConfigurationManager userSettingsValueForKey:BKUserConfigAutoLock];
}

- (void)authenticateUser
{
  
  if (_lockViewController != nil) {
    return;
  }
  
  UIApplication *app = [UIApplication sharedApplication];
  
  PasscodeLockViewController *ctrl = [[PasscodeLockViewController alloc] initWithStateString:@"EnterPassCode"];

  __weak BKTouchIDAuthManager *weakSelf = self;
  
  ctrl.dismissCompletionCallback = ^{
    authRequired = NO;
    [[app keyWindow] setRootViewController:weakSelf.rootViewController];
    
    weakSelf.lockViewController = nil;
    weakSelf.rootViewController = nil;
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
      [[NSNotificationCenter defaultCenter] postNotificationName:BKUserAuthenticated object:nil];
    }];
  };
  
  _lockViewController = ctrl;
  _rootViewController = [[app keyWindow] rootViewController];
  [[app keyWindow] setRootViewController:_lockViewController];
}


@end
