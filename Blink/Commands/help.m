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
    @"  mosh: mosh client.",
    @"  ssh: ssh client.",
    @"  ssh-copy-id: Copy an identity to the server.",
    @"  config: Configure Blink. Add keys, hosts, themes, etc...",
    @"  theme: Switch theme.",
    @"  music: Control music player.",
    @"  history: Manage history.",
    @"  clear: Clear screen.",
    @"  help: Prints this.",
    @"  exit: Close this shell.",
    @"",
    @"Available gestures and keyboard shortcuts:",
    [NSString stringWithFormat:@"  two fingers tap or %@+t: New shell.", flagsStr],
    @"  two fingers swipe up: Show control panel.",
    @"  two fingers drag down dismiss keyboard.",
    [NSString stringWithFormat:@"  one finger swipe left/right or %@+[]: Switch between shells.", shellPrevNextFlagsStr],
    [NSString stringWithFormat:@"  %@+N: Switch to shell number N.", flagsStr],
    [NSString stringWithFormat:@"  %@+w: Close shell.", flagsStr],
    [NSString stringWithFormat:@"  %@+o: Switch to other screen (Airplay mode).", flagsStr],
    [NSString stringWithFormat:@"  %@+O: Move current shell to other screen (Airplay mode).", flagsStr],
    [NSString stringWithFormat:@"  %@+,: Open config.", flagsStr],
    [NSString stringWithFormat:@"  %@+m: Toggle music controls. (Control with %@+npsrb).", flagsStr, flagsStr],
    @"  pinch: Change font size.",
    @"  selection mode:",
    @"    VIM users:",
    @"      h j k l (left, down, up, right)",
    @"      w b (forward/backward by word)",
    @"      o (change selection point)",
    @"      y p (yank, paste)",
    @"    EMACS users:",
    @"      C-f,b,n,p (right, left, down, up)",
    @"      C-M-f,b (forward/backward by word)",
    @"      C-x (change selection point)",
    @"    OTHER: arrows and fingers",
    @""
 ] componentsJoinedByString:@"\n"];
 
  puts(help.UTF8String);
  
  return 0;
}
