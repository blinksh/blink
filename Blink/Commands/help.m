//
//  help.m
//  Blink
//
//  Created by Yury Korolev on 5/12/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#import "BKDefaults.h"
#import "BKUserConfigurationManager.h"

#include "ios_system/ios_system.h"
#include "ios_error.h"

NSString *__shortVersionString()
{
  NSString *compileDate = [NSString stringWithUTF8String:__DATE__];
  
  NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
  NSString *appDisplayName = [infoDictionary objectForKey:@"CFBundleName"];
  NSString *majorVersion = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
  NSString *minorVersion = [infoDictionary objectForKey:@"CFBundleVersion"];
  
  return [NSString stringWithFormat:@"%@: v%@.%@. %@",
          appDisplayName, majorVersion, minorVersion, compileDate];
}


int help_main(int argc, char *argv[]) {
  
  UIKeyModifierFlags flags = [BKUserConfigurationManager shortCutModifierFlags];
  NSString *flagsStr = [BKUserConfigurationManager UIKeyModifiersToString:flags];
  UIKeyModifierFlags shellPrevNextFlags = [BKUserConfigurationManager shortCutModifierFlagsForNextPrevShell];
  NSString *shellPrevNextFlagsStr = [BKUserConfigurationManager UIKeyModifiersToString:shellPrevNextFlags];
  
  NSString *help = [@[
    @"",
    __shortVersionString(),
    @"",
    @"Available commands:",
    @"  <tab>: list available UNIX commands.",
    @"  mosh: mosh client.",
    @"  ssh: ssh client.",
    @"  config: Setup ssh keys, hosts, keyboard, etc.",
    @"  help: Prints this.",
    @"  exit: Close this shell.",
    @"",
    @"Gestures:",
    @"  ✌️ tap -> New Terminal.",
    @"  ✌️ swipe up -> Show control panel.",
    @"  ✌️ drag down -> Dismiss keyboard.",
    @"  👆 swipe left/right -> Switch Terminals.",
    @"  pinch -> Change font size.",
    @"",
    @"Shortcuts:",
    @"  Press and hold ⌘ to show a list of configured shortcuts.",
    @"  Run config. Go to Keyboard > Shortcuts for configuration.",
    @"",
    @"Selection Control:",
    @"  VIM users:",
    @"    h j k l (left, down, up, right)",
    @"    w b (forward/backward by word)",
    @"    o (change selection point)",
    @"    y p (yank, paste)",
    @"  EMACS users:",
    @"    C-f,b,n,p (right, left, down, up)",
    @"    C-M-f,b (forward/backward by word)",
    @"    C-x (change selection point)",
    @"  OTHER: arrows and fingers",
    @"",
    
 ] componentsJoinedByString:@"\n"];
 
  puts(help.UTF8String);
  
  return 0;
}
