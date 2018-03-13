//
//  SystemSession.m
//  Blink
//
//  Created by Yury Korolev on 3/5/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#import "SystemSession.h"
#include "ios_system/ios_system.h"

@interface SystemSession ()

- (void)_captureCommandThreadID:(pthread_t) commandThreadID;

@end

void __command_callback(const void *context, pthread_t command_thread_id) {
  SystemSession *session = (__bridge SystemSession *)context;
  [session _captureCommandThreadID: command_thread_id];
}

@implementation SystemSession
{
  pthread_t _commandThreadID;
}

- (void)_captureCommandThreadID:(pthread_t) commandThreadID
{
  _commandThreadID = commandThreadID;
}

- (void)_setAutoCarriageReturn:(BOOL)state
{
  dispatch_sync(dispatch_get_main_queue(), ^{
    [_stream.control.termView setAutoCarriageReturn:state];
  });
}

- (int)main:(int)argc argv:(char **)argv args:(char *)args
{
  // Is it one of the shell commands?
  // Re-evalute column number before each command
  [self _setAutoCarriageReturn:YES];
  NSString *SSL_CERT_FILE = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"cacert.pem"];
  setenv("SSL_CERT_FILE", SSL_CERT_FILE.UTF8String, 1); // force rewrite of value
  char columnCountString[10];
  sprintf(columnCountString, "%i", self.stream.sz->ws_col);
  setenv("COLUMNS", columnCountString, 1); // force rewrite of value
  // Redirect all output to console:
  FILE* saved_out = stdout;
  FILE* saved_err = stderr;
  stdin = _stream.in;
  stdout = _stream.out;
  stderr = stdout;
  int res = ios_system_with_callback(args, &__command_callback, (__bridge void *) self);
  _commandThreadID = 0;
  // get all output back:
  stdout = saved_out;
  stderr = saved_err;
  stdin = _stream.in;
  unsetenv("SSL_CERT_FILE");
  //        [self _setAutoCarriageReturn:NO];
  return res;
}

- (BOOL)handleControl:(NSString *)control
{
  if ([control isEqualToString:@"c"] || [control isEqualToString:@"d"]) {
    ios_kill_with_thread_id(_commandThreadID);
    return YES;
  }
  
  return NO;
}


@end
