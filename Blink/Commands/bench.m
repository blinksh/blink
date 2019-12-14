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

#include "SSHClient.h"
#include <libssh/callbacks.h>


#include "ios_system/ios_system.h"
#include "ios_error.h"
#include "MCPSession.h"

NSString *_encodeString_(NSString *str)
{
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@[ str ] options:0 error:nil];
  return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}


const NSString *term_write_format_string(NSString *data) {
    return [NSString stringWithFormat:@"term_write(%@[0]);", _encodeString_(data)];
}

const NSString *term_write_data(NSString *data) {
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@[ data ] options:0 error:nil];
  
  NSMutableData *result = [[NSMutableData alloc] initWithCapacity:jsonData.length + 11 + 5];
  [result appendBytes:"term_write(" length:11];
  [result appendData:jsonData];
  [result appendBytes:"[0]);" length:5];
  return [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
}

const NSString *term_write_data_fragment(NSString *data) {
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data options:NSJSONWritingFragmentsAllowed error:nil];
  
  NSMutableData *result = [[NSMutableData alloc] initWithCapacity:jsonData.length + 11 + 2];
  [result appendBytes:"term_write(" length:11];
  [result appendData:jsonData];
  [result appendBytes:");" length:2];
  return [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
}


int bench_main(int argc, char *argv[]) {
  NSString *data = @"dklfajasd fkashdfk asjdflkajsdfl;kj asdkfjas;lkdf ja;lksdjf ;lkasjdf ;lkjas;dfs;d fkj alk;sdjf ;aksjdfka;lksdjf ;asjdg;ak sjdg;kajdf;ja;ld fjajdf ;lkasjdf;lkjasdkfja;lksf dj";
  
  int n = 100000;
  NSDate * startDate = [NSDate date];
  for (int i = 0; i < n; i++) {
    term_write_format_string(data);
  }
  
  puts([NSString stringWithFormat:@"term_write_format_string: %@", @(-[startDate timeIntervalSinceNow])].UTF8String);
//  NSLog(@"term_write_format_string: %@", @([startDate timeIntervalSinceNow]));
  
  startDate = [NSDate date];
  for (int i = 0; i < n; i++) {
    term_write_data(data);
  }
  puts([NSString stringWithFormat:@"term_write_data:          %@", @(-[startDate timeIntervalSinceNow])].UTF8String);
  
  startDate = [NSDate date];
  for (int i = 0; i < n; i++) {
    term_write_data_fragment(data);
  }
  puts([NSString stringWithFormat:@"term_write_data_fragment: %@", @(-[startDate timeIntervalSinceNow])].UTF8String);
  return 0;
}
