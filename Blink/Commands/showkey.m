//
//  showkey.m
//  Blink
//
//  Created by Yury Korolev on 5/12/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

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
      printf("%c",ch);
    
    printf("\t%3d 0%03o 0x%02x\n\r", ch, ch, ch);
    
    fflush(thread_stdout);
    
    if (ch == 4) { // Ctrl-D
      break;
    }
  }
  [session.device setRawMode:NO];

  return 0;
}
