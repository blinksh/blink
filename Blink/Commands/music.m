//
//  music.m
//  Blink
//
//  Created by Yury Korolev on 5/12/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#include <stdio.h>
#import "MusicManager.h"
#include "ios_system/ios_system.h"
#include "ios_error.h"

int music_main(int argc, char *argv[]) {
  
  if (argc != 2) {
    NSString *usage = [@[
       @"usage: music info | back | prev | pause | play | resume | next"
    ] componentsJoinedByString:@"\n"];
    puts(usage.UTF8String);
    return 1;
  }
  
  NSString *input = [NSString stringWithUTF8String:argv[1]];
  __block NSString *output = nil;
  dispatch_sync(dispatch_get_main_queue(), ^{
    output = [[MusicManager shared] runWithInput:input];
  });
  
  if (output) {
    puts(output.UTF8String);
  }
  
  return 0;
}
