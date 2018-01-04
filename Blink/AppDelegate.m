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

#import "AppDelegate.h"
#import "BKiCloudSyncHandler.h"
#import "BKTouchIDAuthManager.h"
#import "ScreenController.h"

@import CloudKit;

#if HOCKEYSDK
@import HockeySDK;
#endif

@interface AppDelegate ()

@end

@implementation AppDelegate {
  NSTimer *_suspendTimer;
  UIBackgroundTaskIdentifier _suspendTaskId;
  BOOL _suspendedMode;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  [[BKTouchIDAuthManager sharedManager]registerforDeviceLockNotif];
  // Override point for customization after application launch.
#if HOCKEYSDK
  NSString *hockeyID = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"HockeyID"];
  [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:hockeyID];
  // Do some additional configuration if needed here
  [[BITHockeyManager sharedHockeyManager].crashManager setCrashManagerStatus:BITCrashManagerStatusAutoSend];
  [[BITHockeyManager sharedHockeyManager].crashManager setEnableAppNotTerminatingCleanlyDetection:YES];
  //[[BITHockeyManager sharedHockeyManager] setDebugLogEnabled: YES];
  [[BITHockeyManager sharedHockeyManager] startManager];
  [[BITHockeyManager sharedHockeyManager].authenticator authenticateInstallation]; // This line is obsolete in the crash only build
#endif 

  [[ScreenController shared] setup];
  return YES;
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
  [[BKiCloudSyncHandler sharedHandler]checkForReachabilityAndSync:nil];
  // TODO: pass completion handler.
}

// MARK: NSUserActivity

- (BOOL)application:(UIApplication *)application willContinueUserActivityWithType:(NSString *)userActivityType {
  return YES;
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray * _Nullable))restorationHandler
{
  restorationHandler(@[[[ScreenController shared] mainScreenRootViewController]]);
  return YES;
}

// MARK: State saving and restoring

- (void)applicationDidEnterBackground:(UIApplication *)application
{
  [self _startMonitoringForSuspending];
}

- (void)_startMonitoringForSuspending
{
  _suspendedMode = NO;
  UIApplication *application = [UIApplication sharedApplication];
  
  if (_suspendTaskId != UIBackgroundTaskInvalid) {
    [application endBackgroundTask:_suspendTaskId];
  }
  
  _suspendTaskId = [application beginBackgroundTaskWithName:@"Suspend" expirationHandler:^{
    [self _suspendApplication];
  }];
  
  NSTimeInterval time = MIN(application.backgroundTimeRemaining * 0.9, 5 * 60);
  [_suspendTimer invalidate];
  _suspendTimer = [NSTimer scheduledTimerWithTimeInterval:time
                                                   target:self
                                                 selector:@selector(_suspendApplication)
                                                 userInfo:nil
                                                  repeats:NO];
}

- (void)_suspendApplication
{
  [_suspendTimer invalidate];
  
  if (_suspendedMode) {
    return;
  }
  
  if (_suspendTaskId == UIBackgroundTaskInvalid) {
    return;
  }
  
  dispatch_async(dispatch_get_main_queue(), ^{
    [[ScreenController shared] suspend];
    _suspendedMode = YES;
    UIApplication *application = [UIApplication sharedApplication];
    [application endBackgroundTask:_suspendTaskId];
    _suspendTaskId = UIBackgroundTaskInvalid;
  });
}

- (void)_cancelApplicationSuspend
{
  [_suspendTimer invalidate];
  _suspendedMode = NO;
  UIApplication *application = [UIApplication sharedApplication];
  [application endBackgroundTask:_suspendTaskId];
  _suspendTaskId = UIBackgroundTaskInvalid;
}

- (void)applicationWillTerminate:(UIApplication *)application
{
  if (!_suspendedMode) {
    [self _startMonitoringForSuspending];
    [self _suspendApplication];
  }
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
  if (_suspendedMode) {
    [[ScreenController shared] resume];
  }
  [self _cancelApplicationSuspend];
}

- (BOOL)application:(UIApplication *)application shouldSaveApplicationState:(nonnull NSCoder *)coder
{
  return YES;
}

- (BOOL)application:(UIApplication *)application shouldRestoreApplicationState:(nonnull NSCoder *)coder
{
  return YES;
}

- (void)applicationProtectedDataWillBecomeUnavailable:(UIApplication *)application
{
  if (!_suspendedMode) {
    [self _startMonitoringForSuspending];
    [self _suspendApplication];
  }
}


@end
