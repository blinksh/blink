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

- (int)main:(int)argc argv:(char **)argv args:(char *)args
{
  // ios_system operates in auto carriage return mode
  [self setAutoCarriageReturn:YES];
  
  // Re-evalute column number before each command
  setenv("COLUMNS", [@(_device->win.ws_col) stringValue].UTF8String, 1); // force rewrite of value
  // Redirect all output to console:
  ios_setStreams(_stream.in, _stream.out, _stream.err);
  return ios_system(args);
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
