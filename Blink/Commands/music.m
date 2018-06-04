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
