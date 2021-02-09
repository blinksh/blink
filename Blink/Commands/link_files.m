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

#include <stdio.h>
#import "MCPSession.h"
#import <MobileCoreServices/MobileCoreServices.h>
#include "ios_system/ios_system.h"
#include "BlinkPaths.h"

API_AVAILABLE(ios(11.0))
@interface SyncDirectoryPicker: NSObject <UIDocumentPickerDelegate>
- (NSArray<NSString *> *)pickWithInController:(UIViewController *)ctrl;
@end

@implementation SyncDirectoryPicker {
  dispatch_semaphore_t _dsema;
  NSArray<NSString *> *_pickedPaths;
}

- (NSArray<NSString *> *)pickWithInController:(UIViewController *)ctrl
{
  _dsema = dispatch_semaphore_create(0);
  __block UIDocumentPickerViewController *pickerCtrl = nil;
  dispatch_async(dispatch_get_main_queue(), ^{
    pickerCtrl = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[(NSString *)kUTTypeFolder] inMode:UIDocumentPickerModeOpen];
    pickerCtrl.allowsMultipleSelection = YES;
    pickerCtrl.delegate = self;
    
    [ctrl presentViewController:pickerCtrl animated:YES completion:nil];
  });
  
  dispatch_semaphore_wait(_dsema, DISPATCH_TIME_FOREVER);
  
  return _pickedPaths;
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
  _pickedPaths = nil;
  dispatch_semaphore_signal(_dsema);
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls
{
  NSMutableArray<NSString *> *pickedPaths = [[NSMutableArray alloc] init];
  for (NSURL *url in urls) {
    if ([url startAccessingSecurityScopedResource]) {
      [pickedPaths addObject:url.path];
    }
  }
  _pickedPaths = pickedPaths;
  dispatch_semaphore_signal(_dsema);
}

@end

__attribute__ ((visibility("default")))
int link_files_main(int argc, char *argv[]) {
//  if (argc != 2) {
//    NSString *usage = [@[
//                         @"usage: link-files dest"
//                         ] componentsJoinedByString:@"\n"];
//    fputs(usage.UTF8String, thread_stdout);
//    fputs("\n", thread_stderr);
//    return 1;
//  }
//  NSString *args = [NSString stringWithUTF8String:argv[1]];
//
//  if (args.length == 0) {
//    return 1;
//  }
  
  NSString *arg = nil;
  if (argc == 2) {
    arg = [NSString stringWithUTF8String:argv[1]];
  }
  
  if ([arg isEqualToString:@"-h"] || [arg isEqualToString:@"--help"]) {
    NSString *usage = [@[
                         @"usage: link-files [dest]"
                         ] componentsJoinedByString:@"\n"];
    fputs(usage.UTF8String, thread_stdout);
    fputs("\n", thread_stderr);
    return 0;
  }
  
  MCPSession *session = (__bridge MCPSession *)thread_context;
  if (!session) {
    return 1;
  }
  
  if (@available(iOS 11.0, *)) {
    SyncDirectoryPicker *picker = [[SyncDirectoryPicker alloc] init];
    NSArray<NSString *> *folders = [picker pickWithInController: session.device.delegate.viewController];
    
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSString *documentsPath = [BlinkPaths documents];
    
    for (NSString *path in folders) {
      NSString *linkName = [arg lastPathComponent] ?: [path lastPathComponent];
      arg = nil;
      NSString *linkPath = [documentsPath stringByAppendingPathComponent:linkName];
      NSError *error = nil;
      if (![fm createSymbolicLinkAtPath:linkPath withDestinationPath:path error:&error]) {
        fputs([NSString stringWithFormat:@"Can't create new symbolic link at ~/%@:\n", linkName].UTF8String, thread_stderr);
      }
    }
    [session updateAllowedPaths];
    return 0;
  } else {
    fputs("link-files works only on iOS 11 or higher\n", thread_stderr);
    return 1;
  }
}
