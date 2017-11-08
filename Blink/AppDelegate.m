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
// Required for commands
#import "SpaceController.h"
#import <pthread.h>
@import CloudKit;

#undef HOCKEYSDK
#if HOCKEYSDK
@import HockeySDK;
#endif

@interface AppDelegate ()
@end

@implementation AppDelegate {
  NSString *docsPath;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  [[BKTouchIDAuthManager sharedManager]registerforDeviceLockNotif];
  
  docsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
  
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

- (void)applicationWillResignActive:(UIApplication *)application
{
  // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
  // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
  // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
  // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
  // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
  // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
  // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler{
  [[BKiCloudSyncHandler sharedHandler]checkForReachabilityAndSync:nil];
}


- (NSString*)uniqueFileName:(NSString*)filename {
  NSString* extension = [filename pathExtension];
  NSString* basename = [filename stringByDeletingPathExtension];
  int nameSuffix = 1;
  
  NSURL* target = [NSURL fileURLWithPath:filename];
  /*
   Find a suitable filename that doesn't already exist on disk.
   Do not use `fileManager.fileExistsAtPath(target.path!)` because
   the document might not have downloaded yet.
   */
  NSError* error;
  while ([target checkPromisedItemIsReachableAndReturnError:(&error)]) {
    NSString* suffix = [NSString stringWithFormat:@"-%d.", nameSuffix];
    NSString* newName = [[basename stringByAppendingString:suffix] stringByAppendingString:extension];
    target = [NSURL fileURLWithPath:newName];
    nameSuffix += 1;
  }
  return target.path;
}

- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
  // Two different possibilities:
  // a) we have been sent a file (by "open in Blink").
  //         --> we either save it or copy it in Documents.
  // b) we have been sent a command (by "blinkshell://command%20plus%20arguments").
  //         --> we extract the command and execute it.
  if (url.isFileURL) {
    BOOL shouldOpenInPlace = options[UIApplicationOpenURLOptionsOpenInPlaceKey];
    if (shouldOpenInPlace) [url startAccessingSecurityScopedResource];
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (shouldOpenInPlace) [url stopAccessingSecurityScopedResource];
    // The place where we will write the data:
    NSString* filename = [url lastPathComponent];
    NSString* path = [docsPath stringByAppendingPathComponent:filename];
    NSString* pathUnique = [self uniqueFileName:path];
    
    if (shouldOpenInPlace && (data != nil)) {
      if ([data writeToFile:pathUnique atomically:YES]) {
        // If it worked and it was a file in our Inbox, we delete it:
        if (([url isFileURL]) && (
                                  ([[url path] isEqualToString:[[docsPath stringByAppendingPathComponent:@"Inbox/"] stringByAppendingPathComponent:filename]]) ||
                                  ([[url path] isEqualToString:[@"/private" stringByAppendingPathComponent:[[docsPath stringByAppendingPathComponent:@"Inbox/"] stringByAppendingPathComponent:filename]]])
                                  )) {
          NSError *e;
          if (![[NSFileManager defaultManager] removeItemAtPath:url.path error:&e]) {
            fprintf(stderr, "Could not remove file: %s, reason = %s\n", [url.path UTF8String],  [[e localizedDescription] UTF8String]);
          }
        }
      }
      // TODO? automatic expansion of archives. Should be a preference. Security risk?
      return YES;
    } else {
      // can not open in place. Need to import.
      // HOW can I debug that with iOS11?
      NSFileAccessIntent *readIntent = [NSFileAccessIntent readingIntentWithURL:url options:0];
      NSFileAccessIntent *writeIntent = [NSFileAccessIntent writingIntentWithURL:[NSURL  fileURLWithPath:pathUnique] options:NSFileCoordinatorWritingForReplacing];
      NSFileCoordinator* fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
      NSOperationQueue* queue = [[NSOperationQueue alloc] init];
      [fileCoordinator coordinateAccessWithIntents:@[readIntent] queue:queue byAccessor:^(NSError * _Nullable error) {
        if (error != nil) return;
        [[NSFileManager defaultManager]  copyItemAtURL:readIntent.URL toURL:writeIntent.URL error:0];
      }];
      return YES;
    }
  } else if ([url.scheme isEqualToString:@"blinkshell"]) {
    // extract the command:
    NSString *command = [url.absoluteString stringByReplacingOccurrencesOfString:@"blinkshell://" withString:@""];
    SpaceController*  spaceC = (SpaceController *)ScreenController.shared.mainScreenRootViewController;
    // parse into composants, if needed:
    if ([command containsString:@"%1E"]) {
      // We separated arguments with %1E. Let's parse:
      // Corresponds to programs that create arguments with spaces in them.
      // e.g. python, when calling "python -c vast command with spaces"
      NSArray *listArgvMaybeEmpty = [command componentsSeparatedByString:@"%1E"];
      NSMutableArray *listArgv = [[listArgvMaybeEmpty filteredArrayUsingPredicate:
                                   [NSPredicate predicateWithFormat:@"length > 0"]] mutableCopy];
      for (int i = 0; i < [listArgv count]; i++)
           [listArgv replaceObjectAtIndex:i withObject:[listArgv[i] stringByRemovingPercentEncoding]];
      return [spaceC executeCommand:listArgv];
    } else {
      // no %1E inside. Simpler case.
      // First, remove percent encoding
      command = [command stringByRemovingPercentEncoding];
      // Separate arr into arguments and parse (env vars, ~)
      NSArray *listArgvMaybeEmpty = [command componentsSeparatedByString:@" "];
      // Remove empty strings (extra spaces)
      NSMutableArray* listArgv = [[listArgvMaybeEmpty filteredArrayUsingPredicate:
                                   [NSPredicate predicateWithFormat:@"length > 0"]] mutableCopy];
      if ([listArgv count] == 0) return NULL; // unlikely
      return [spaceC executeCommand:listArgv];
      }
  } else return NO; // Not a scheme we can handle, sorry
}

@end
