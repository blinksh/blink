//
//  open.m
//  Blink
//
//  Created by Yury Korolev on 5/12/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#include <stdio.h>
#import "MCPSession.h"
#include "ios_system/ios_system.h"

int open_main(int argc, char *argv[]) {
  if (argc != 2) {
    NSString *usage = [@[
                         @"usage: open file"
                         ] componentsJoinedByString:@"\n"];
    fputs(usage.UTF8String, thread_stdout);
    fputs("\n", thread_stderr);
    return 1;
  }
  NSString *args = [NSString stringWithUTF8String:argv[1]];
  
  if (args.length == 0) {
    return 1;
  }
  
  
  MCPSession *session = (__bridge MCPSession *)thread_context;
  
  bool isDir = NO;
  if ([[NSFileManager defaultManager] fileExistsAtPath:args isDirectory:&isDir]) {
    if (!isDir) {
      NSURL * currentDir = [NSURL fileURLWithPath: [[NSFileManager defaultManager] currentDirectoryPath]];
      NSURL * url = [currentDir URLByAppendingPathComponent:args isDirectory:NO];
      
      dispatch_async(dispatch_get_main_queue(), ^{
        if (url) {
          NSNotification *n = [[NSNotification alloc] initWithName:@"BlinkShare" object:session userInfo:@{@"url": url}];
          [[NSNotificationCenter defaultCenter] postNotification:n];
        }
      });
    }
  } else {
    NSURL *url = [NSURL URLWithString:args];
    dispatch_async(dispatch_get_main_queue(), ^{
      if (url) {
        NSNotification *n = [[NSNotification alloc] initWithName:@"BlinkShare" object:session userInfo:@{@"url": url}];
        [[NSNotificationCenter defaultCenter] postNotification:n];
      }
    });
  }
  
  return 0;
}
