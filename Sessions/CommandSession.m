////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016 Blink Mobile Shell Project
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

#import <Foundation/Foundation.h>
#import "CommandSession.h"
// Shell commands for more interactions.
// ls, rm, rmdir, touch...

// All functions from all commands:
// TODO: merge all these in a single "system.h" file.
#include "file_cmds_ios.h"
#include "shell_cmds_ios.h"
#include "text_cmds_ios.h"
#include "curl_ios.h"
#include "libarchive_ios.h"
#include "Python_ios.h"

static NSDictionary *commandList = nil;

@interface CommandSession ()
@end

@implementation CommandSession {
  const char *_command;
  int _tty_flag;
}
  
+ (void)initialize
{
  commandList = @{
                  // Commands from Apple file_cmds:
                  @"ls" : [NSValue valueWithPointer: ls_main],
                  @"touch" : [NSValue valueWithPointer: touch_main],
                  @"rm" : [NSValue valueWithPointer: rm_main],
                  @"cp" : [NSValue valueWithPointer: cp_main],
                  @"ln" : [NSValue valueWithPointer: ln_main],
                  @"link" : [NSValue valueWithPointer: ln_main],
                  @"mv" : [NSValue valueWithPointer: mv_main],
                  @"mkdir" : [NSValue valueWithPointer: mkdir_main],
                  @"rmdir" : [NSValue valueWithPointer: rmdir_main],
                  @"chown" : [NSValue valueWithPointer: chown_main],
                  @"chgrp" : [NSValue valueWithPointer: chown_main],
                  @"chflags": [NSValue valueWithPointer: chflags_main],
                  @"chmod": [NSValue valueWithPointer: chmod_main],
                  @"du"   : [NSValue valueWithPointer: du_main],
                  @"df"   : [NSValue valueWithPointer: df_main],
                  @"chksum" : [NSValue valueWithPointer: chksum_main],
                  @"sum"    : [NSValue valueWithPointer: chksum_main],
                  @"stat"   : [NSValue valueWithPointer: stat_main],
                  @"readlink": [NSValue valueWithPointer: stat_main],
                  @"compress": [NSValue valueWithPointer: compress_main],
                  @"uncompress": [NSValue valueWithPointer: compress_main],
                  @"gzip"   : [NSValue valueWithPointer: gzip_main],
                  @"gunzip" : [NSValue valueWithPointer: gzip_main],
                  // Commands from Apple shell_cmds:
                  @"printenv": [NSValue valueWithPointer: printenv_main],
                  @"pwd"    : [NSValue valueWithPointer: pwd_main],
                  @"uname"  : [NSValue valueWithPointer: uname_main],
                  @"date"   : [NSValue valueWithPointer: date_main],
                  @"env"    : [NSValue valueWithPointer: env_main],
                  @"id"     : [NSValue valueWithPointer: id_main],
                  @"groups" : [NSValue valueWithPointer: id_main],
                  @"whoami" : [NSValue valueWithPointer: id_main],
                  @"uptime" : [NSValue valueWithPointer: w_main],
                  @"w"      : [NSValue valueWithPointer: w_main],
                  // Commands from Apple text_cmds:
                  @"cat"    : [NSValue valueWithPointer: cat_main],
                  @"wc"     : [NSValue valueWithPointer: wc_main],
                  @"grep"   : [NSValue valueWithPointer: grep_main],
                  @"egrep"  : [NSValue valueWithPointer: grep_main],
                  @"fgrep"  : [NSValue valueWithPointer: grep_main],
                  // From curl:
                  @"curl"   : [NSValue valueWithPointer: curl_main],
                  // scp / sftp arguments were converted earlier in makeargs
                  // @"scp"    : [NSValue valueWithPointer: curl_main],
                  // @"sftp"   : [NSValue valueWithPointer: curl_main],
                  // from libarchive:
                  @"tar"    : [NSValue valueWithPointer: tar_main],
                  // from python:
                  @"python"  : [NSValue valueWithPointer: python_main],
                  };
}
  
  
- (int)main:(int)argc argv:(char **)argv
{
  int (*function)(int ac, char** av) = NULL;
  // 2) re-initialize for getopt:
  optind = 1;
  opterr = 1;
  optreset = 1;
  // 3) call specific commands
  // Redirect all output to console:
  stdin = _stream.control.termin;
  stdout = _stream.control.termout;
  stderr = _stream.control.termout;
  
  NSString* commandName = [NSString stringWithCString:argv[0] encoding:NSASCIIStringEncoding];
  function = [[commandList objectForKey: commandName] pointerValue];
  if (function == nil) {
      [self out:"Unknown command. Type 'help' for a list of available operations"];
    return 0;
  }
      
  int exit_code = 0;
  exit_code = function(argc, argv);
  [self debugMsg:[NSString stringWithFormat:@"command %s finished with code %d", argv[0], exit_code]];
  
  return exit_code;
}

- (void)out:(const char *)str
{
  fprintf(_stream.out, "%s\n", str);
}

- (int)dieMsg:(NSString *)msg
{
  fprintf(_stream.out, "%s\n", [msg UTF8String]);
  return -1;
}

- (void)errMsg:(NSString *)msg
{
  fprintf(_stream.err, "%s\n", [msg UTF8String]);
}

- (void)debugMsg:(NSString *)msg
{
  if (_debug) {
    fprintf(_stream.out, "CommandSession:DEBUG:%s\n", [msg UTF8String]);
  }
}

- (void)sigwinch
{
  pthread_kill(_tid, SIGWINCH);
}

- (void)kill
{
  pthread_kill(_tid, SIGTERM);
}

@end
