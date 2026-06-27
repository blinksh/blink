////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2019 Blink Mobile Shell Project
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
#import <BlinkConfig/BlinkPaths.h>
#import "BLKDefaults.h"
#import <BlinkConfig/BKHosts.h>
#import <BlinkConfig/BKPubKey.h>
#import <UserNotifications/UserNotifications.h>
#include "Blink-Swift.h"

#ifdef BLINK_BUILD_ENABLED
extern void build_auto_start_wg_ports(void);
#endif


@import CloudKit;

@interface AppDelegate () <UNUserNotificationCenterDelegate>
@end

@implementation AppDelegate {
  NSTimer *_backgroundExtensionTimer;
  UIBackgroundTaskIdentifier _backgroundExtensionTask;
  BOOL _deviceMayBeLocked;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

  [[ZuseLog app] info:@"Hello, Blink"];

  [Migrator perform];

  if (application.isProtectedDataAvailable) {
    [self _runProtectedBootstrap];
  }

  [AppDelegate reloadDefaults];
  [[UIView appearance] setTintColor:[UIColor blinkTint]];

  signal(SIGPIPE, __on_pipebroken_signal);

  NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
  [nc addObserver:self
         selector:@selector(_onSceneDidEnterBackground:)
             name:UISceneDidEnterBackgroundNotification object:nil];
  [nc addObserver:self
           selector:@selector(_onSceneWillEnterForeground:)
               name:UISceneWillEnterForegroundNotification object:nil];
  [nc addObserver:self
         selector:@selector(_onSceneDidActiveNotification:)
             name:UISceneDidActivateNotification object:nil];
  [nc addObserver:self
         selector: @selector(_onScreenConnect)
             name:UIScreenDidConnectNotification object:nil];

  [KBTracker shared];

  [UNUserNotificationCenter currentNotificationCenter].delegate = self;

//  [nc addObserver:self selector:@selector(_logEvent:) name:nil object:nil];
//  [nc addObserver:self selector:@selector(_active) name:@"UIApplicationSystemNavigationActionChangedNotification" object:nil];

  [UIApplication sharedApplication].applicationSupportsShakeToEdit = NO;

  [_NSFileProviderManager syncWithBKHosts];

  [PurchasesUserModelObjc preparePurchasesUserModel];

#ifdef BLINK_BUILD_ENABLED
  build_auto_start_wg_ports();
#endif

  return YES;
}

void __on_pipebroken_signal(int signum){
  NSLog(@"PIPE is broken");
}

//- (void)_active {
//  [[SmarterTermInput shared] realBecomeFirstResponder];
//}
//- (void)_logEvent:(NSNotification *)n {
//  NSLog(@"event, %@, %@", n.name, n.userInfo);
//  if ([n.name isEqualToString:@"UIApplicationSystemNavigationActionChangedNotification"]) {
//    [[SmarterTermInput shared] realBecomeFirstResponder];
//  }
//
//}

+ (void)reloadDefaults {
  [BLKDefaults loadDefaults];
  [BKPubKey loadIDS];
  [BKHosts loadHosts];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
  [[BKiCloudSyncHandler sharedHandler]checkForReachabilityAndSync:nil];
  // TODO: pass completion handler.
}

- (BOOL)application:(UIApplication *)application shouldAllowExtensionPointIdentifier:(NSString *)extensionPointIdentifier {
  if ([extensionPointIdentifier isEqualToString: UIApplicationKeyboardExtensionPointIdentifier]) {
    return ![BLKDefaults disableCustomKeyboards];
  }
  return YES;
}

#pragma mark - State saving and restoring

- (void)applicationProtectedDataDidBecomeAvailable:(UIApplication *)application
{
  [[ZuseLog machine:@"App"] info:@"protectedDataDidBecomeAvailable"];
  _deviceMayBeLocked = NO;
  [self _runProtectedBootstrap];
  // [SceneDelegate resumeActiveMachines];
}

- (void)_runProtectedBootstrap
{
  // Filesystem and iCloud work runs off-main; iCloud metadata can block.
  // _cleanLostSessions hops back to main, where SessionRegistry is touched
  // by the rest of the codebase.
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    [BlinkPaths linkDocumentsIfNeeded];
    [BlinkPaths linkICloudDriveIfNeeded];
    [[BookmarkedLocationsManager default] activateAccess];
  });
}

- (void)applicationProtectedDataWillBecomeUnavailable:(UIApplication *)application
{
  [[ZuseLog machine:@"App"] info:@"protectedDataWillBecomeUnavailable"];
  // Archives use complete file protection; a write after the device locks fails.
  // Snapshot now — even foreground — while the write still succeeds.
  [SceneDelegate suspendActiveMachines];
  [self _endBackgroundExtension];
  _deviceMayBeLocked = YES;
}

- (void)applicationWillTerminate:(UIApplication *)application
{
  [[ZuseLog machine:@"App"] info:@"willTerminate"];
  [self _suspendAndEndBackgroundExtension];
  [ZuseLog shutdown];
}

// Keep the process alive briefly after backgrounding so sessions stay live.
- (void)_beginBackgroundExtension
{
  UIApplication *application = [UIApplication sharedApplication];

  // No point keeping the process alive while the device is locked; the flag also
  // covers the lock window before isProtectedDataAvailable flips.
  if (_deviceMayBeLocked || !application.isProtectedDataAvailable) {
    return;
  }

  [self _endBackgroundExtension];

  _backgroundExtensionTask = [application beginBackgroundTaskWithName:@"BackgroundExtension" expirationHandler:^{
    [self _onBackgroundExtensionExpiration];
  }];

  NSTimeInterval time = MIN(application.backgroundTimeRemaining * 0.9, 5 * 60);
  [[ZuseLog machine:@"BackgroundExtension"] info:[NSString stringWithFormat:@"begin — grace %.0fs", time]];
  _backgroundExtensionTimer = [NSTimer scheduledTimerWithTimeInterval:time
                                                               target:self
                                                             selector:@selector(_onBackgroundExtensionTimer)
                                                             userInfo:nil
                                                                repeats:NO];
}

- (void)_endBackgroundExtension {
  [_backgroundExtensionTimer invalidate];
  if (_backgroundExtensionTask != UIBackgroundTaskInvalid) {
    [[ZuseLog machine:@"BackgroundExtension"] info:@"end"];
    [[UIApplication sharedApplication] endBackgroundTask:_backgroundExtensionTask];
  }
  _backgroundExtensionTask = UIBackgroundTaskInvalid;
}

// Grace expired (all scenes backgrounded): suspend their Machines, then end.
- (void)_suspendAndEndBackgroundExtension {
  [SceneDelegate suspendActiveMachines];
  [self _endBackgroundExtension];
}

// Wrappers so a crash stack shows which trigger fired.
- (void)_onBackgroundExtensionTimer {
  [[ZuseLog machine:@"BackgroundExtension"] info:@"grace timer fired — suspend"];
  [self _suspendAndEndBackgroundExtension];
}
- (void)_onBackgroundExtensionExpiration {
  [[ZuseLog machine:@"BackgroundExtension"] info:@"background time expired — suspend"];
  [self _suspendAndEndBackgroundExtension];
}

#pragma mark - Scenes

- (UISceneConfiguration *) application:(UIApplication *)application
configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
                               options:(UISceneConnectionOptions *)options {
  // for (NSUserActivity * activity in options.userActivities) {  }
  return [UISceneConfiguration configurationWithName:@"main"
                                         sessionRole:connectingSceneSession.role];
}



- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
  [[ZuseLog machine:@"App"] info:[NSString stringWithFormat:@"didDiscardSceneSessions count=%lu", (unsigned long)sceneSessions.count]];
  [SpaceController onDidDiscardSceneSessions: sceneSessions];
}

- (void)_onSceneDidEnterBackground:(NSNotification *)notification {
  [[ZuseLog machine:@"App"] info:@"sceneDidEnterBackground"];
  NSArray * scenes = UIApplication.sharedApplication.connectedScenes.allObjects;
  for (UIScene *scene in scenes) {
    if (scene.activationState == UISceneActivationStateForegroundActive || scene.activationState == UISceneActivationStateForegroundInactive) {
      return;
    }
  }
  [self _beginBackgroundExtension];
}

- (void)_onSceneWillEnterForeground:(NSNotification *)notification {
  [[ZuseLog machine:@"App"] info:@"sceneWillEnterForeground"];
  [self _endBackgroundExtension];
  // Foreground can precede unlock; only re-acquire when data is actually available.
  if (UIApplication.sharedApplication.isProtectedDataAvailable) {
    [[BookmarkedLocationsManager default] activateAccess];
  }
}

- (void)_onSceneDidActiveNotification:(NSNotification *)notification {
  [[ZuseLog machine:@"App"] info:@"sceneDidActivate (notification)"];
  [self _endBackgroundExtension];
}

- (void)_onScreenConnect {
  [BLKDefaults applyExternalScreenCompensation:BLKDefaults.overscanCompensation];
}

#pragma mark - UNUserNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
  UNNotificationPresentationOptions opts = UNNotificationPresentationOptionSound | UNNotificationPresentationOptionList | UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionBadge;
  completionHandler(opts);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
  SceneDelegate *sceneDelegate = (SceneDelegate *)response.targetScene.delegate;

  SpaceController *ctrl = sceneDelegate.spaceController;

  [ctrl moveToShellWithKey:response.notification.request.content.threadIdentifier];

  completionHandler();
}

#pragma mark - Menu Building

- (void)buildMenuWithBuilder:(id<UIMenuBuilder>)builder {
  if (builder.system == UIMenuSystem.mainSystem) {
    [MenuController buildMenuWith:builder];
  }
}

@end
