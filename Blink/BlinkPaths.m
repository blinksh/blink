////////////////////////////////////////////////////////////////////////////////
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

#import "BlinkPaths.h"

@implementation BlinkPaths

NSString *__documentsPath = nil;

+ (NSString *)documents
{
  if (__documentsPath == nil) {
    __documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
  }
  return __documentsPath;
}

+ (NSURL *)documentsURL
{
  return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
}

NSString *__iCloudsDriveDocumentsPath = nil;

+ (NSString *)iCloudDriveDocuments
{
  if (__iCloudsDriveDocumentsPath == nil) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *path = [[fm URLForUbiquityContainerIdentifier:@"iCloud.com.carloscabanero.blinkshell"] URLByAppendingPathComponent:@"Documents"].path;
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:path isDirectory:&isDir]) {
      NSError *error = nil;
      if (![fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"Error: %@", error);
      }
    }
    __iCloudsDriveDocumentsPath = path;
  }
  
  return __iCloudsDriveDocumentsPath;
}

+ (void)linkICloudDriveIfNeeded
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *icloudPath = [[self documents] stringByAppendingPathComponent:@"iCloud"];
  if ([fm fileExistsAtPath:icloudPath isDirectory:nil]) {
    return;
  }
  
  NSError *error = nil;

  if (
      ![fm createSymbolicLinkAtPath:icloudPath withDestinationPath:[self iCloudDriveDocuments] error:&error]
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

+ (NSURL *)blinkKBConfigURL
{
  return [[self blinkURL] URLByAppendingPathComponent:@"kb.json"];
}


+ (NSString *)blinkHostsFile
{
  return [[self blink] stringByAppendingPathComponent:@"hosts"];
}

+ (NSURL *)blinkSSHConfigFileURL
{
  return [[self blinkURL] URLByAppendingPathComponent:@"ssh_config"];
}


+ (NSString *)blinkSyncItemsFile
{
  return [[self blink] stringByAppendingPathComponent:@"syncItems"];
}

+ (NSString *)blinkProfileFile
{
  return [[self blink] stringByAppendingPathComponent:@"profile"];
}


+ (NSString *)historyFile
{
  return [[self blink] stringByAppendingPathComponent:@"history.txt"];
}

+ (NSURL *)historyURL
{
  return [NSURL fileURLWithPath:[self historyFile]];
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
