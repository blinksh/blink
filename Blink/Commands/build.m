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

#include <libssh/callbacks.h>


#include "ios_system/ios_system.h"
#include "ios_error.h"
#include "MCPSession.h"
#include "TokioSignals.h"
#include "openurl.h"

struct IOSEnv {
  int stdin_fd;
  int stdout_fd;
  int stderr_fd;
  const char * cwd;
  void * open_url_fn;
  void * start_mosh_fn;
};

void tokio_open_url(char *url) {
  NSString * str = @(url);
  blink_openurl([NSURL URLWithString:str]);
}

void tokio_start_mosh(char * key, char * host, char * port) {
  MCPSession *session = (__bridge MCPSession *)thread_context;
  if (!session) {
    return;
  }
  
  NSString * cmd = [NSString stringWithFormat:@"mosh -o -I build -k %@ -p %@ %@", @(key), @(port), @(host)];

  dispatch_async(session.cmdQueue, ^{
    [session enqueueCommand:cmd skipHistoryRecord:YES];
  });
//
}

extern int blink_build_cmd(int argc, char *argv[], struct IOSEnv * env, void ** signals);
  
__attribute__ ((visibility("default")))
int build_main(int argc, char *argv[]) {
  MCPSession *session = (__bridge MCPSession *)thread_context;
  if (!session) {
    return -1;
  }
  
  struct IOSEnv env = {
      .stdin_fd = fileno(ios_stdin()),
      .stdout_fd = fileno(ios_stdout()),
      .stderr_fd = fileno(ios_stderr()),
      .cwd = [NSFileManager.defaultManager currentDirectoryPath].UTF8String,
      .open_url_fn = tokio_open_url,
      .start_mosh_fn = tokio_start_mosh,
  };
  
  TokioSignals *signals = [TokioSignals new];
  session.tokioSignals = signals;
  
  int res = blink_build_cmd(argc, argv, &env, &signals->_signals);
  
  session.tokioSignals = nil;
  
  return res;
}
