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
#import "BKTouchIDAuthManager.h"
#import "BlinkPaths.h"
#import "BKDefaults.h"
#import "BKPubKey.h"
#import "BKHosts.h"
#import <ios_system/ios_system.h>
#include <libssh/callbacks.h>
#include "xcall.h"
#include "Blink-Swift.h"


@import CloudKit;

@interface AppDelegate ()
@end

@implementation AppDelegate {
  NSTimer *_suspendTimer;
  UIBackgroundTaskIdentifier _suspendTaskId;
  BOOL _suspendedMode;
}
  
void __on_pipebroken_signal(int signum){
  NSLog(@"PIPE is broken");
}

void __setupProcessEnv() {
  NSBundle *mainBundle = [NSBundle mainBundle];
  int forceOverwrite = 1;
  NSString *SSL_CERT_FILE = [mainBundle pathForResource:@"cacert" ofType:@"pem"];
  setenv("SSL_CERT_FILE", SSL_CERT_FILE.UTF8String, forceOverwrite);
  
  NSString *locales_path = [mainBundle pathForResource:@"locales" ofType:@"bundle"];
  setenv("PATH_LOCALE", locales_path.UTF8String, forceOverwrite);
  setenv("LC_CTYPE", "UTF-8", forceOverwrite);
  setlocale(LC_CTYPE, "UTF-8");
  setlocale(LC_ALL, "UTF-8");
  setenv("TERM", "xterm-256color", forceOverwrite);
  
  ssh_threads_set_callbacks(ssh_threads_get_pthread());
  ssh_init();
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  signal(SIGPIPE, __on_pipebroken_signal);
  
  dispatch_queue_t bgQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
  dispatch_async(bgQueue, ^{
    [BlinkPaths linkICloudDriveIfNeeded];
  });
  
  [[BKTouchIDAuthManager sharedManager] registerforDeviceLockNotif];

  sideLoading = false; // Turn off extra commands from iOS system
  initializeEnvironment(); // initialize environment variables for iOS system
  dispatch_async(bgQueue, ^{
    addCommandList([[NSBundle mainBundle] pathForResource:@"blinkCommandsDictionary" ofType:@"plist"]); // Load blink commands to ios_system
      __setupProcessEnv(); // we should call this after ios_system initializeEnvironment to override its defaults.
  });

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
  
//  [nc addObserver:self selector:@selector(_logEvent:) name:nil object:nil];
//  [nc addObserver:self selector:@selector(_active) name:@"UIApplicationSystemNavigationActionChangedNotification" object:nil];

  [UIApplication sharedApplication].applicationSupportsShakeToEdit = NO;
  return YES;
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

- (void)_loadProfileVars {
  NSCharacterSet *whiteSpace = [NSCharacterSet whitespaceCharacterSet];
  NSString *profile = [NSString stringWithContentsOfFile:[BlinkPaths blinkProfileFile] encoding:NSUTF8StringEncoding error:nil];
  [profile enumerateLinesUsingBlock:^(NSString * _Nonnull line, BOOL * _Nonnull stop) {
    NSMutableArray<NSString *> *parts = [[line componentsSeparatedByString:@"="] mutableCopy];
    if (parts.count < 2) {
      return;
    }
    
    NSString *varName = [parts.firstObject stringByTrimmingCharactersInSet:whiteSpace];
    if (varName.length == 0) {
      return;
    }
    [parts removeObjectAtIndex:0];
    NSString *varValue = [[parts componentsJoinedByString:@"="] stringByTrimmingCharactersInSet:whiteSpace];
    if ([varValue hasSuffix:@"\""] || [varValue hasPrefix:@"\""]) {
      varValue = [varValue substringWithRange:NSMakeRange(1, varValue.length - 1)];
    }
    if (varValue.length == 0) {
      return;
    }
    BOOL forceOverwrite = 1;
    setenv(varName.UTF8String, varValue.UTF8String, forceOverwrite);
  }];
}

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [BKDefaults loadDefaults];
  [BKPubKey loadIDS];
  [BKHosts loadHosts];
  [self _loadProfileVars];
  
    [[UIView appearance] setTintColor:[UIColor blinkTint]];
//  [[UIView appearance] setTintColor:[UIColor colorWithRed:10.0/255.0f green:224.0/255.0f blue:240.0f/255.0 alpha:1]];
//  [[UIView appearance] setTintColor:[UIColor cyanColor]];
  return YES;
}



- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
  [[BKiCloudSyncHandler sharedHandler]checkForReachabilityAndSync:nil];
  // TODO: pass completion handler.
}

// MARK: NSUserActivity

- (BOOL)application:(UIApplication *)application willContinueUserActivityWithType:(NSString *)userActivityType 
{
  return YES;
}

//- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler {
//    restorationHandler(@[[[ScreenController shared] mainScreenRootViewController]]);
//    return YES;
//}

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray * _Nullable))restorationHandler
{
//  restorationHandler(@[[[ScreenController shared] mainScreenRootViewController]]);
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

- (void)_startMonitoringForSuspending
{
  if (_suspendedMode) {
    return;
  }
  
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

- (void)_cancelApplicationSuspend {
  [_suspendTimer invalidate];
  _suspendedMode = NO;
  if (_suspendTaskId != UIBackgroundTaskInvalid) {
    [[UIApplication sharedApplication] endBackgroundTask:_suspendTaskId];
  }
  _suspendTaskId = UIBackgroundTaskInvalid;
}

// Simple wrappers to get the reason of failure from call stack
- (void)_suspendApplicationWithSuspendTimer {
  [self _suspendApplication];
}

- (void)_suspendApplicationWithExpirationHandler {
  [self _suspendApplication];
}

- (void)_suspendApplicationOnWillTerminate {
  [self _suspendApplication];
}

- (void)_suspendApplicationOnProtectedDataWillBecomeUnavailable {
  [self _suspendApplication];
}

- (void)_suspendApplication {
  [_suspendTimer invalidate];
  
  if (_suspendedMode) {
    return;
  }
  
  [[SessionRegistry shared] suspend];
  _suspendedMode = YES;
  
  if (_suspendTaskId != UIBackgroundTaskInvalid) {
    [[UIApplication sharedApplication] endBackgroundTask:_suspendTaskId];
  }
  
  _suspendTaskId = UIBackgroundTaskInvalid;
}

#pragma mark - LSSupportsOpeningDocumentsInPlace

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
  if ([url.host isEqualToString:@"run"]) {
    if (![BKDefaults isXCallBackURLEnabled]) {
      return NO;
    }
    
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES];
    NSArray * items = components.queryItems;
    NSURLQueryItem *keyItem = [[items filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name == %@", @"key"]] firstObject];
    
    NSString *urlKey = [BKDefaults xCallBackURLKey];

    if (!keyItem.value) {
      return NO;
    }
    
    if (![keyItem.value isEqual:urlKey]) {
      return NO;
    }
    
    NSURLQueryItem *cmdItem = [[items filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name == %@", @"cmd"]] firstObject];
    NSString *cmd = cmdItem.value ?: @"help";
    
    return NO;

//    NSUserActivity * activity = [[NSUserActivity alloc] initWithActivityType:BKUserActivityTypeCommandLine];
//    activity.eligibleForPublicIndexing = NO;
//    [activity setTitle:[NSString stringWithFormat:@"run: %@ ", cmd]];
//    [activity setUserInfo:@{BKUserActivityCommandLineKey: cmd}];
//    [[[ScreenController shared] mainScreenRootViewController] restoreUserActivityState:activity];
    return YES;
  }
  blink_handle_url(url);
  // What we can do useful?
  return YES;
}

#pragma mark - Scenes

- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
  return [UISceneConfiguration configurationWithName:@"main" sessionRole:connectingSceneSession.role];
}

- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
  [SpaceController onDidDiscardSceneSessions: sceneSessions];
}

- (void)_onSceneDidEnterBackground:(NSNotification *)notification {
  NSArray * scenes = UIApplication.sharedApplication.connectedScenes.allObjects;
  for (UIScene *scene in scenes) {
    if (scene.activationState == UISceneActivationStateForegroundActive || scene.activationState == UISceneActivationStateForegroundInactive) {
      return;
    }
  }
  [self _startMonitoringForSuspending];
}

- (void)_onSceneWillEnterForeground:(NSNotification *)notification {
  [self _cancelApplicationSuspend];
}

- (void)_onSceneDidActiveNotification:(NSNotification *)notification {
  [self _cancelApplicationSuspend];
}

- (void)_onScreenConnect {
  [BKDefaults applyExternalScreenCompensation:BKDefaults.overscanCompensation];
}

@end
