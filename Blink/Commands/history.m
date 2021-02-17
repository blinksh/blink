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
#include "BlinkPaths.h"
#include "ios_system/ios_system.h"
#include "ios_error.h"
#include "MCPSession.h"
#include <Blink-Swift.h>

__attribute__ ((visibility("default")))
int history_main(int argc, char *argv[]) {
  NSString *args = @"";
  if (argc == 2) {
    args = [NSString stringWithUTF8String:argv[1]];
  }
  NSInteger number = [args integerValue];
  if (number != 0) {
    NSString *history = [NSString stringWithContentsOfFile:[BlinkPaths historyFile]
                                                  encoding:NSUTF8StringEncoding error:nil];
    NSArray *lines = [history componentsSeparatedByString:@"\n"];
    if (!lines) {
      return 1;
    }
    lines = [lines filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self != ''"]];
    
    NSInteger len = lines.count;
    NSInteger start = 0;
    if (number > 0) {
      len = MIN(len, number);
    } else {
      start = MAX(len + number , 0);
    }
    
    for (NSInteger i = start; i < len; i++) {
      puts([NSString stringWithFormat:@"% 4li %@", i + 1, lines[i]].UTF8String);
    }
  } else if ([args isEqualToString:@"-c"]) {
    [HistoryObj clear];
  } else {
    NSString *usage = [@[
                         @"history usage:",
                         @"history <number> - Show history (can be negative)",
                         @"history -c       - Clear history",
                         @""
                         ] componentsJoinedByString:@"\n"];
    puts(usage.UTF8String);
  }
  return 1;
}
