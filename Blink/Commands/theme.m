//
//  showkey.m
//  Blink
//
//  Created by Yury Korolev on 5/12/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#include <stdio.h>
#import "BKDefaults.h"
#import "BKTheme.h"
#include "MCPSession.h"

#include "ios_system/ios_system.h"
#include "ios_error.h"


int theme_main(int argc, char *argv[]) {
  MCPSession *session = (__bridge MCPSession *)thread_context;
  NSString *args = @"";
  if (argc == 2) {
    args = [NSString stringWithUTF8String:argv[1]];
  }
  
  if ([args isEqualToString:@""] || [args isEqualToString:@"info"]) {
    NSString *themeName = [BKDefaults selectedThemeName];
    puts([NSString stringWithFormat:@"Current theme: %@", themeName].UTF8String);
    BKTheme *theme = [BKTheme withName:[BKDefaults selectedThemeName]];
    if (!theme) {
      puts("Not found");
    }
    return 0;
  } else {
    BKTheme *theme = [BKTheme withName:args];
    if (!theme) {
      puts("Theme not found");
      return 0;
    }
    
    dispatch_sync(dispatch_get_main_queue(), ^{
      [BKDefaults setThemeName:theme.name];
      [BKDefaults saveDefaults];
      [session.delegate reloadSession];
    });
    exit(10);
  }
  
  
  return 0;
}
