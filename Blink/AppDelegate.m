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
#import "StateManager.h"
@import CloudKit;

#if HOCKEYSDK
@import HockeySDK;
#endif

@interface AppDelegate ()

@end

@implementation AppDelegate


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

  return YES;
}

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  [StateManager shared];
  [[ScreenController shared] setup];
  return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
  NSLog(@"- (void)applicationWillResignActive:(UIApplication *)application");
  // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
  // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
  NSLog(@"- (void)applicationDidEnterBackground:(UIApplication *)application");
  // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
  // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
  NSLog(@"%@", [NSNumber numberWithDouble:application.backgroundTimeRemaining]);
  [[ScreenController shared] suspend];
  
  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    sleep(1);
    [[ScreenController shared] saveStates];
  }];
  
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
  NSLog(@"- (void)applicationWillEnterForeground:(UIApplication *)application");
  [[ScreenController shared] resume];
  // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
  NSLog(@"- (void)applicationDidBecomeActive:(UIApplication *)application");
  // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
  NSLog(@"%@", [NSNumber numberWithDouble:application.backgroundTimeRemaining]);
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    NSLog(@"- (void)applicationWillTerminate:(UIApplication *)application");
  // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (BOOL)application:(UIApplication *)application shouldSaveApplicationState:(nonnull NSCoder *)coder
{
  NSLog(@"- (BOOL)application:(UIApplication *)application shouldSaveApplicationState:(nonnull NSCoder *)coder");
  NSLog(@"%@", [NSNumber numberWithDouble:application.backgroundTimeRemaining]);
  return YES;
}

- (BOOL)application:(UIApplication *)application shouldRestoreApplicationState:(nonnull NSCoder *)coder
{
  NSLog(@"- (BOOL)application:(UIApplication *)application shouldRestoreApplicationState:(nonnull NSCoder *)coder");
  NSLog(@"%@", [NSNumber numberWithDouble:application.backgroundTimeRemaining]);
  return YES;
}

- (void)application:(UIApplication *)application willEncodeRestorableStateWithCoder:(NSCoder *)coder
{
  NSLog(@"- (void)application:(UIApplication *)application willEncodeRestorableStateWithCoder:(NSCoder *)coder");
  NSLog(@"%@", [NSNumber numberWithDouble:application.backgroundTimeRemaining]);
}

- (void)applicationProtectedDataDidBecomeAvailable:(UIApplication *)application
{
  NSLog(@"- (void)applicationProtectedDataDidBecomeAvailable:(UIApplication *)application");
  NSLog(@"%@", [NSNumber numberWithDouble:application.backgroundTimeRemaining]);
}

- (void)applicationProtectedDataWillBecomeUnavailable:(UIApplication *)application
{
  NSLog(@"- (void)applicationProtectedDataWillBecomeUnavailable:(UIApplication *)application");
  NSLog(@"%@", [NSNumber numberWithDouble:application.backgroundTimeRemaining]);
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

@end
