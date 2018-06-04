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
#include "MCPSession.h"
#include "ios_system/ios_system.h"
#include "ios_error.h"

int showkey_main(int argc, char *argv[]) {
  MCPSession *session = (__bridge MCPSession *)thread_context;
  
  printf("Press any keys - Ctrl-D will terminate this program.\n");
  
  [session.device setRawMode:YES];
  

  char ch;
  while (1) {
    ssize_t n = read(fileno(thread_stdin), &ch, 1);
    if (n <= 0) {
      break;
    }
    
    if (ch == '\n')
      printf("\\n");
    else if (ch == '\t')
      printf("\\t");
    else if (ch < ' ')
      printf("^%c", ch+64);
    else
      printf("%c", ch);
    
    printf("\t%3d 0%03o 0x%02x\r\n", ch, ch, ch);
    
    fflush(thread_stdout);
    
    if (ch == 4) { // Ctrl-D
      break;
    }
  }
  [session.device setRawMode:NO];

  return 0;
}
