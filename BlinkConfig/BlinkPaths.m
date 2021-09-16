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

NSString *__homePath = nil;
NSString *__documentsPath = nil;
NSString *__iCloudsDriveDocumentsPath = nil;

+ (NSString *)homePath {
  if (__homePath == nil) {
    __homePath = [[self groupContainerPath] stringByAppendingPathComponent:@"home"];
  }
  
  return __homePath;
}

+ (NSString *)documentsPath
{
  if (__documentsPath == nil) {
    __documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    // Linked and resolved files has prefix /private
    if (![__documentsPath hasPrefix:@"/private"]) {
      __documentsPath = [@"/private" stringByAppendingString:__documentsPath];
    }
  }
  return __documentsPath;
}

+ (NSString *)groupContainerPath {
  NSString *groupID = @"group.Com.CarlosCabanero.BlinkShell";
  NSFileManager *fm = [NSFileManager defaultManager];
  return [fm containerURLForSecurityApplicationGroupIdentifier:groupID].path;
}

+ (NSString *)iCloudDriveDocuments
{
  if (__iCloudsDriveDocumentsPath == nil) {
    NSString *iCloudID = @"iCloud.com.carloscabanero.blinkshell";
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *path = [[fm URLForUbiquityContainerIdentifier:iCloudID] URLByAppendingPathComponent:@"Documents"].path;
    [self _ensureFolderAtPath:path];
    __iCloudsDriveDocumentsPath = path;
  }
  
  return __iCloudsDriveDocumentsPath;
}

+ (void)linkICloudDriveIfNeeded
{
  [self _linkAtPath:[[self homePath] stringByAppendingPathComponent:@"iCloud"]
    destinationPath:[self iCloudDriveDocuments]];
}

+ (void)linkDocumentsIfNeeded {
  [self _linkAtPath:[[self homePath] stringByAppendingPathComponent:@"Documents"]
    destinationPath:[self documentsPath]];
}

+ (void)_linkAtPath:(NSString *)atPath destinationPath:(NSString *)destinationPath {
  NSFileManager *fm = [NSFileManager defaultManager];
  if ([fm fileExistsAtPath:atPath]) {
    return;
  }
  
  NSError *error = nil;
  
  BOOL ok = [fm createSymbolicLinkAtPath:atPath
                     withDestinationPath:destinationPath
                                   error:&error];

  if (!ok) {
    NSLog(@"Error: %@", error);
  };
}

+ (NSString *)blink {
  NSString *dotBlink = [[self homePath] stringByAppendingPathComponent:@".blink"];
  [self _ensureFolderAtPath:dotBlink];
  return dotBlink;
}

+ (NSString *)ssh {
  NSString *dotSSH = [[self homePath] stringByAppendingPathComponent:@".ssh"];
  [self _ensureFolderAtPath:dotSSH];
  return dotSSH;
}

+ (void)_ensureFolderAtPath:(NSString *)path {
  BOOL isDir = NO;
  NSFileManager *fm = [NSFileManager defaultManager];
  if ([fm fileExistsAtPath:path isDirectory:&isDir]) {
    if (isDir) {
      return;
    }
    
    [fm removeItemAtPath:path error:nil];
  }
  [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:@{} error:nil];
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

+ (NSString *)blinkDefaultsFile
{
  return [[self blink] stringByAppendingPathComponent:@"defaults"];
}

+ (NSArray<NSString *> *)cleanedSymlinksInHomeDirectory
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSMutableArray<NSString *> *allowedPaths = [[NSMutableArray alloc] init];
  
  NSString *homePath = [BlinkPaths homePath];
  NSArray<NSString *> * files = [fm contentsOfDirectoryAtPath:homePath error:nil];
  
  for (NSString *path in files) {
    NSString *filePath = [homePath stringByAppendingPathComponent:path];
    NSDictionary * attrs = [fm attributesOfItemAtPath:filePath error:nil];
    if (attrs[NSFileType] != NSFileTypeSymbolicLink) {
      continue;
    }
      
    NSString *destPath = [fm destinationOfSymbolicLinkAtPath:filePath error:nil];
    if (!destPath) {
      continue;
    }
    
    if (![fm isReadableFileAtPath:destPath]) {
      
      // We lost access. Remove that symlink
      [fm removeItemAtPath:filePath error:nil];
      continue;
    }
    
    [allowedPaths addObject:destPath];
  }
  return allowedPaths;
}

+ (void)migrateToHomeAtGroupContainer {
  [self cleanedSymlinksInHomeDirectory];
  NSFileManager *fm = NSFileManager.defaultManager;
//  [fm removeItemAtPath:[self homePath] error:nil];
  
  NSString *homePath = [self homePath];
 
  if ([fm fileExistsAtPath:homePath]) {
    return;
  }
  NSError *error = nil;
  BOOL ok = [fm createDirectoryAtPath:homePath
          withIntermediateDirectories:YES
                           attributes:nil
                                error:&error];
  
  if (error || !ok) {
    NSLog(@"Failed to create home folder :%@.", error);
    return;
  }

  NSString *documentsPath = [self documentsPath];
  NSArray<NSString *> *foldersToMove = @[@".blink", @".ssh"];
  
  for (NSString * folder in foldersToMove) {
    NSString *folderDocumentsPath = [documentsPath stringByAppendingPathComponent:folder];
    NSString *folderHomePath = [homePath stringByAppendingPathComponent:folder];
    
    ok = [fm copyItemAtPath:folderDocumentsPath toPath:folderHomePath error:&error];
    if (error || !ok) {
      NSLog(@"Failed to copy folder %@ :%@.", folder, error);
    }
  }
  
  NSDictionary<NSFileAttributeKey, id> *attrs = @{NSFileProtectionKey: NSFileProtectionNone};

  NSArray<NSString *> * pathsToFixPermissions = @[
    BlinkPaths.blinkKeysFile,
    BlinkPaths.blinkHostsFile,
    BlinkPaths.blinkDefaultsFile
  ];
  
  for (NSString *path in pathsToFixPermissions) {
    ok = [fm setAttributes:attrs ofItemAtPath:path error:&error];
    if (error || !ok) {
      NSLog(@"Failed to set attribtues on %@ :%@.", path, error);
    }
  }
}


@end
