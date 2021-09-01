//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2019 Blink Mobile Shell Project
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


#import "BKMiniLog.h"
#import "BlinkPaths.h"
#import <UIKit/UIKit.h>
#import <BlinkConfig/BlinkConfig-Swift.h>

@implementation BKMiniLog {
  NSString *_name;
  NSMutableArray<NSString *> *_records;
}

- (instancetype)initWithName:(NSString *)name {
  self = [super init];
  if (self) {
    _name = name;
    _records = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)log:(NSString *)record {
  NSLog(@"%@:%@", _name, record);
  [_records addObject:record];
}

- (void)save {

  [_records addObject:@""];
  NSString *log = [_records componentsJoinedByString:@"\n"];
  NSString *name = _name;
  NSString *logPath = [[BlinkPaths blink] stringByAppendingPathComponent:name];
  
  dispatch_after(DISPATCH_TIME_NOW + 1.0 * NSEC_PER_SEC, dispatch_get_main_queue(), ^{
    NSError *err = nil;
    if (![log writeToFile: logPath atomically:YES encoding:NSUTF8StringEncoding error: &err]) {
      NSLog(@"%@: Error writing log %@", name, err);
      
      OwnAlertController *alert = [OwnAlertController
                                   alertControllerWithTitle:@"iOS15 Error Trace. Please report."
                                   message:[NSString stringWithFormat: @"There was an issue storing trace logs. %@", err]
                                   preferredStyle:UIAlertControllerStyleAlert];
      
      UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
      [alert addAction:ok];
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
        [alert presentWithAnimated:true completion:nil];
      });
    }
  });
  
}

@end
