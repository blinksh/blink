//
//  Migrator.m
//  Blink
//
//  Created by Yury Korolev on 5/19/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#import "Migrator.h"
#import "BlinkPaths.h"

#define UNKNOWN_VERSION 0
#define BEFORE_BLINK_DIR_VERSION 1
#define BLINK_DIR_VERSION 2


#define TARGET_VERSION BLINK_DIR_VERSION

#define MIGRATION_VERSION_KEY @"blink.migration.v"

NSInteger __getCurrentMigrationVersion() {
  return [[NSUserDefaults standardUserDefaults] integerForKey:MIGRATION_VERSION_KEY];
}

NSInteger __setCurrentMigrationVersion(NSInteger version) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setInteger:version forKey:MIGRATION_VERSION_KEY];
  [defaults synchronize];
  return version;
}

@implementation Migrator

+ (void)migrateIfNeeded
{
  NSInteger currentVersion = __getCurrentMigrationVersion();
  
  if (currentVersion == TARGET_VERSION) {
    NSLog(@"No migration required. Already at %@ version", @(TARGET_VERSION));
    return;
  }
  
  if (currentVersion == UNKNOWN_VERSION) {
    // This is special case.
    // We don't know if the app is just installed and this is firt launch or
    // we just updated. And we need to perform our migrations.
    
    NSString *oldDefaultsPath = [[BlinkPaths documents] stringByAppendingPathComponent:@"defaults"];
    BOOL defaultsExists = [[NSFileManager defaultManager] fileExistsAtPath:oldDefaultsPath];

    NSString *oldKeysPath = [[BlinkPaths documents] stringByAppendingPathComponent:@"keys"];
    BOOL keysExists = [[NSFileManager defaultManager] fileExistsAtPath:oldKeysPath];

    if (defaultsExists || keysExists) {
      currentVersion = __setCurrentMigrationVersion(BEFORE_BLINK_DIR_VERSION);
    } else {
      currentVersion = __setCurrentMigrationVersion(BLINK_DIR_VERSION);
    }
  }
  
  if (currentVersion == BEFORE_BLINK_DIR_VERSION) {
    [self _migrateFolderStructure];
    currentVersion = __setCurrentMigrationVersion(BLINK_DIR_VERSION);
  }
}

+ (void)_migrateFolderStructure
{
  NSLog(@"Migrating folder structure");
  
  NSArray *filesToMoveToDotBlink = @[@"history.txt", @".blink_history", @"keys",
                                     @"hosts", @"syncItems", @"defaults",
                                     @"FontsList", @"ThemesList"];
  
  for (NSString *file in filesToMoveToDotBlink) {
    NSString *srcPath = [[BlinkPaths documents] stringByAppendingPathComponent:file];
    NSString *destPath = [[BlinkPaths blink] stringByAppendingPathComponent:file];
   
    [self _moveFileAtPath:srcPath toPath: destPath];
  }
  
  [self _moveFileAtPath:[[BlinkPaths blink] stringByAppendingPathComponent:@".blink_history"]
                 toPath:[[BlinkPaths blink] stringByAppendingPathComponent:@"history.txt"]];
  
  [self _moveFileAtPath:[[BlinkPaths documents] stringByAppendingPathComponent: @"known_hosts"]
                 toPath:[[BlinkPaths ssh] stringByAppendingPathComponent: @"known_hosts"]];
  
  NSArray *foldersToMoveToDotBlink = @[@"Fonts", @"Themes"];
  
  for (NSString *folder in foldersToMoveToDotBlink) {
    NSString *srcPath = [[BlinkPaths documents] stringByAppendingPathComponent:folder];
    NSString *destPath = [[BlinkPaths blink] stringByAppendingPathComponent:folder];
    
    [self _moveFileAtPath:srcPath toPath: destPath];
  }
}

+ (void)_moveFileAtPath:(NSString *)srcPath toPath:(NSString *)destPath
{
  NSFileManager *fileManager = [NSFileManager defaultManager];
  if ([fileManager fileExistsAtPath:srcPath]) {
    NSLog(@"Moving %@", srcPath);
    NSError *error = nil;
    if ([fileManager moveItemAtPath:srcPath toPath:destPath error:&error]) {
      NSLog(@"Moved to %@", destPath);
    } else {
      NSLog(@"Failed moving %@. Error: %@", srcPath, error);
    }
  } else {
    NSLog(@"No %@. skipping", srcPath);
  }
}

@end
