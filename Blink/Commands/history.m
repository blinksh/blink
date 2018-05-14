//
//  showkey.c
//  Blink
//
//  Created by Yury Korolev on 5/12/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#include <stdio.h>
#include "ios_system/ios_system.h"
#include "MCPSession.h"

int history_main(int argc, char *argv[]) {
  return [[(__bridge MCPSession *)thread_context repl] history_main:argc argv:argv];
}
