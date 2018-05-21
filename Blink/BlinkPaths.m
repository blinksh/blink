//
//  BlinkPaths.m
//  Blink
//
//  Created by Yury Korolev on 5/14/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#import "BlinkPaths.h"

@implementation BlinkPaths

+ (NSString *)documents
{
  return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}

+ (NSURL *)documentsURL
{
  return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
}

+ (NSString *)iCloudDriveDocuments
{
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSString *path = [[fileManager URLForUbiquityContainerIdentifier:@"iCloud.com.carloscabanero.blinkshell"] URLByAppendingPathComponent:@"Documents"].path;
  BOOL isDir = NO;
  if (![fileManager fileExistsAtPath:path isDirectory:&isDir]) {
    NSError *error = nil;
    if (![fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error]) {
      NSLog(@"Error: %@", error);
    }
  }
  
  return path;
}

+ (void)linkICloudDriveIfNeeded
{
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSString *icloudPath = [[self documents] stringByAppendingPathComponent:@"iCloud"];
  if ([fileManager fileExistsAtPath:icloudPath isDirectory:nil]) {
    return;
  }
  
  NSError *error = nil;

  if (
//      ![fileManager linkItemAtPath:[self iCloudDriveDocuments]  toPath: icloudPath error:&error]
      ![fileManager createSymbolicLinkAtPath:icloudPath withDestinationPath:[self iCloudDriveDocuments] error:&error]
      ) {
    NSLog(@"Error: %@", error);
  };
}

+ (NSString *)blink
{
  NSString *dotBlink = [[self documents] stringByAppendingPathComponent:@".blink"];
  NSFileManager *fileManager = [NSFileManager defaultManager];
  BOOL isDir = NO;
  if ([fileManager fileExistsAtPath:dotBlink isDirectory:&isDir]) {
    if (isDir) {
      return dotBlink;
    }
    
    [fileManager removeItemAtPath:dotBlink error:nil];
  }
  
  [fileManager createDirectoryAtPath:dotBlink withIntermediateDirectories:YES attributes:@{} error:nil];
  return dotBlink;
}

+ (NSString *)ssh
{
  NSString *dotSSH = [[self documents] stringByAppendingPathComponent:@".ssh"];
  NSFileManager *fileManager = [NSFileManager defaultManager];
  BOOL isDir = NO;
  if ([fileManager fileExistsAtPath:dotSSH isDirectory:&isDir]) {
    if (isDir) {
      return dotSSH;
    }
    
    [fileManager removeItemAtPath:dotSSH error:nil];
  }
  [fileManager createDirectoryAtPath:dotSSH withIntermediateDirectories:YES attributes:@{} error:nil];
  return dotSSH;
}


+ (NSURL *)blinkURL
{
  return [NSURL fileURLWithPath:[self blink]];
}

+ (NSString *)blinkKeysFile
{
  return [[self blink] stringByAppendingPathComponent:@"keys"];
}

+ (NSString *)blinkHostsFile
{
  return [[self blink] stringByAppendingPathComponent:@"hosts"];
}

+ (NSString *)blinkSyncItemsFile
{
  return [[self blink] stringByAppendingPathComponent:@"syncItems"];
}

+ (NSString *)historyFile
{
  return [[self blink] stringByAppendingPathComponent:@"history.txt"];
}

+ (NSString *)knownHostsFile
{
  return [[self ssh] stringByAppendingPathComponent:@"known_hosts"];
}

+ (NSString *)defaultsFile
{
  return [[self blink] stringByAppendingPathComponent:@"defaults"];
}

@end
