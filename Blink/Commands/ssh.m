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


void __thread_ssh_execute_command(const char *command, socket_t in, socket_t out) {
  
//  const char *args[]={command,NULL};
  /* redirect in and out to stdin, stdout and stderr */
  ios_dup2(in,  0);
  ios_dup2(out, 1);
  ios_dup2(out, 2);
//  close(in);
//  close(out);
  ios_system(command);
//  ios_exit(1);
//  ios_execv(args[0],(char * const *)args);
//  exit(1);
}

void __ssh_logging(int priority,
                 const char *function,
                 const char *buffer,
                 void *userdata) {
  fwrite(buffer, strlen(buffer), 1, thread_stderr);
  fwrite("\n", 1, 1, thread_stderr);
}



int ssh_main(int argc, char *argv[]) {
  MCPSession *session = (__bridge MCPSession *)thread_context;
  thread_ssh_execute_command = &__thread_ssh_execute_command;
  
  ssh_set_log_callback(__ssh_logging);
  
  SSHClient *client = [[SSHClient alloc]
                       initWithStdIn: fileno(thread_stdin)
                              stdOut: fileno(thread_stdout)
                              stdErr: fileno(thread_stderr)
                       device: session.device
                       isTTY: ios_isatty(fileno(thread_stdout))];
  session.sshClient = client;
  return [client main:argc argv:argv];
}
