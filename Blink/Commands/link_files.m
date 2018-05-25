//
//  open.m
//  Blink
//
//  Created by Yury Korolev on 5/12/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

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
