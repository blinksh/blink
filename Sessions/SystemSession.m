//
//  SystemSession.m
//  Blink
//
//  Created by Yury Korolev on 3/5/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#import "SystemSession.h"
#include "ios_system/ios_system.h"

@implementation SystemSession

- (void)_setAutoCarriageReturn:(BOOL)state
{
  dispatch_sync(dispatch_get_main_queue(), ^{
    [_device.view setAutoCarriageReturn:state];
  });
}

- (int)main:(int)argc argv:(char **)argv args:(char *)args
{
  // Is it one of the shell commands?
  // Re-evalute column number before each command
  [self _setAutoCarriageReturn:YES];
  
  char columnCountString[10];
  sprintf(columnCountString, "%i", _device->win.ws_col);
  setenv("COLUMNS", columnCountString, 1); // force rewrite of value
  // Redirect all output to console:
  ios_setStreams(_stream.in, _stream.out, _stream.out);
  int res = ios_system(args);
  return res;
}

- (BOOL)handleControl:(NSString *)control
{
  if ([control isEqualToString:@"c"] || [control isEqualToString:@"d"]) {
    ios_kill();
    return YES;
  }
  
  return NO;
}


@end
