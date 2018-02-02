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

#pragma mark - State saving and restoring

- (void)applicationProtectedDataWillBecomeUnavailable:(UIApplication *)application
{
  
  [self _suspendApplicationOnProtectedDataWillBecomeUnavailable];
}

- (void)applicationWillTerminate:(UIApplication *)application
{

  [self _suspendApplicationOnWillTerminate];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
  if (_suspendedMode) {
    [[ScreenController shared] resume];
  }

  [self _cancelApplicationSuspend];
}


- (void)applicationDidEnterBackground:(UIApplication *)application
{
  [self _startMonitoringForSuspending];
}

- (void)_startMonitoringForSuspending
{
  if (_suspendedMode) {
    return;
  }
  
  NSLog(@"_startMonitoringForSuspending");
  
  UIApplication *application = [UIApplication sharedApplication];
  
  if (_suspendTaskId != UIBackgroundTaskInvalid) {
    [application endBackgroundTask:_suspendTaskId];
  }
  
  _suspendTaskId = [application beginBackgroundTaskWithName:@"Suspend" expirationHandler:^{
    [self _suspendApplicationWithExpirationHandler];
  }];
  
  NSTimeInterval time = MIN(application.backgroundTimeRemaining * 0.9, 5 * 60);
  [_suspendTimer invalidate];
  _suspendTimer = [NSTimer scheduledTimerWithTimeInterval:time
                                                   target:self
                                                 selector:@selector(_suspendApplicationWithSuspendTimer)
                                                 userInfo:nil
                                                  repeats:NO];
}


- (BOOL)application:(UIApplication *)application shouldSaveApplicationState:(nonnull NSCoder *)coder
{
  return YES;
}

- (BOOL)application:(UIApplication *)application shouldRestoreApplicationState:(nonnull NSCoder *)coder
{
  return YES;
}

- (void) application:(UIApplication *)application didDecodeRestorableStateWithCoder:(NSCoder *)coder
{
  [[ScreenController shared] finishRestoring];
}

- (void)_cancelApplicationSuspend
{
  [_suspendTimer invalidate];
  _suspendedMode = NO;
  if (_suspendTaskId != UIBackgroundTaskInvalid) {
    [[UIApplication sharedApplication] endBackgroundTask:_suspendTaskId];
  }
  _suspendTaskId = UIBackgroundTaskInvalid;
}

// Simple wrappers to get the reason of failure from call stack
- (void)_suspendApplicationWithSuspendTimer
{
  NSLog(@"_suspendApplicationWithSuspendTimer");
  [self _suspendApplication];
}

- (void)_suspendApplicationWithExpirationHandler
{
  NSLog(@"_suspendApplicationWithExpirationHandler");
  [self _suspendApplication];
}

- (void)_suspendApplicationOnWillTerminate
{
  NSLog(@"_suspendApplicationOnWillTerminate");
  [self _suspendApplication];
}

- (void)_suspendApplicationOnProtectedDataWillBecomeUnavailable
{
  NSLog(@"_suspendApplicationOnProtectedDataWillBecomeUnavailable");
  [self _suspendApplication];
}

- (void)_suspendApplication
{
  [_suspendTimer invalidate];
  
  if (_suspendedMode) {
    return;
  }
  
  [[ScreenController shared] suspend];
  _suspendedMode = YES;
  
  if (_suspendTaskId != UIBackgroundTaskInvalid) {
    [[UIApplication sharedApplication] endBackgroundTask:_suspendTaskId];
  }
  
  _suspendTaskId = UIBackgroundTaskInvalid;
}


@end
