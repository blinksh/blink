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
#include <string.h>
#include <libgen.h>
#include <sys/stat.h>

#import "MCPSession.h"
#import "MoshSession.h"
#import "BKPubKey.h"
#import "SSHCopyIDSession.h"
#import "SSHSession.h"
#import "SystemSession.h"
#import "BKTheme.h"

//#import "SSHSession2.h"


#import "BKDefaults.h"
#import "BKUserConfigurationManager.h"
#import "BlinkPaths.h"


// from ios_system:

#include <ios_system/ios_system.h>

NSArray<NSString *> *_splitCommandAndArgs(NSString *cmdline)
{
  NSRange rng = [cmdline rangeOfString:@" "];
  if (rng.location == NSNotFound) {
    return @[ cmdline, @"" ];
  } else {
    return @[
       [cmdline substringToIndex:rng.location],
       [cmdline substringFromIndex:rng.location + 1]
    ];
  }
}



@implementation MCPSession {
  Session *_childSession;
}

@dynamic sessionParameters;

- (id)initWithDevice:(TermDevice *)device andParametes:(SessionParameters *)parameters
{
  if (self = [super initWithDevice:device andParametes:parameters]) {
    _repl = [[Repl alloc] initWithDevice:device];
  }
  
  return self;
}

- (int)main:(int)argc argv:(char **)argv args:(char *)args
{
  if ([@"mosh" isEqualToString:self.sessionParameters.childSessionType]) {
    _childSession = [[MoshSession alloc] initWithDevice:_device andParametes:self.sessionParameters.childSessionParameters];
    [_childSession executeAttachedWithArgs:@""];
    _childSession = nil;
  }
  
  sideLoading = false; // Turn off extra commands from iOS system
  initializeEnvironment(); // initialize environment variables for iOS system
  replaceCommand(@"curl", @"curl_static_main", true); // replace curl in ios_system with our own, accessing Blink keys.
  replaceCommand(@"help", @"help_main", true);
  replaceCommand(@"config", @"config_main", true);
  replaceCommand(@"music", @"music_main", true);
  replaceCommand(@"clear", @"clear_main", true);
  replaceCommand(@"showkey", @"showkey_main", true);
  replaceCommand(@"history", @"history_main", true);
  replaceCommand(@"open", @"open_main", true);
  ios_setMiniRoot([BlinkPaths documents]);
  ios_setContext((__bridge void*)self);
//  initializeCommandListForCompletion();
  [[NSFileManager defaultManager] changeCurrentDirectoryPath:[BlinkPaths documents]];

  [_repl loopWithCallback:^BOOL(NSString *cmdline) {
    NSArray *arr = _splitCommandAndArgs(cmdline);
    NSString *cmd = arr[0];
    NSString *args = arr[1];
    
    if ([cmd isEqualToString:@"mosh"]) {
      // At some point the parser will be in the JS, and the call will, through JSON, will include what is needed.
      // Probably passing a Server struct of some type.
      [self _runMoshWithArgs:cmdline];
    } else if ([cmd isEqualToString:@"ssh"]) {
      // At some point the parser will be in the JS, and the call will, through JSON, will include what is needed.
      // Probably passing a Server struct of some type.
      [self _runSSHWithArgs:cmdline];
      //    } else if ([cmd isEqualToString:@"ssh2"]) {
      // At some point the parser will be in the JS, and the call will, through JSON, will include what is needed.
      // Probably passing a Server struct of some type.
      //      [self _runSSH2WithArgs:cmdline];
    } else if ([cmd isEqualToString:@"exit"]) {
      return false;
    } else if ([cmd isEqualToString:@"theme"]) {
      BOOL reload = [self _switchTheme: args];
      if (reload) {
        return false;
      }
    } else if ([cmd isEqualToString:@"ssh-copy-id"]) {
      [self _runSSHCopyIDWithArgs:cmdline];
    } else {
      [self _runSystemCommandWithArgs:cmdline];
    }
    
    return YES;
  }];

  [self out:"Bye!"];

  
  return 0;
}




- (BOOL)_switchTheme:(NSString *)args
{
  if ([args isEqualToString:@""] || [args isEqualToString:@"info"]) {
    NSString *themeName = [BKDefaults selectedThemeName];
    [self out:[NSString stringWithFormat:@"Current theme: %@", themeName].UTF8String];
    BKTheme *theme = [BKTheme withName:[BKDefaults selectedThemeName]];
    if (!theme) {
      [self out:@"Not found".UTF8String];
    }
    return NO;
  } else {
    BKTheme *theme = [BKTheme withName:args];
    if (!theme) {
      [self out:@"Theme not found".UTF8String];
      return NO;
    }

    dispatch_sync(dispatch_get_main_queue(), ^{
      [BKDefaults setThemeName:theme.name];
      [BKDefaults saveDefaults];
      [self.delegate reloadSession];
    });
    return YES;
  }
}

- (void)_runSSHCopyIDWithArgs:(NSString *)args
{
  self.sessionParameters.childSessionParameters = nil;
  _childSession = [[SSHCopyIDSession alloc] initWithDevice:_device andParametes:self.sessionParameters.childSessionParameters];
  self.sessionParameters.childSessionType = @"sshcopyid";
  [_childSession executeAttachedWithArgs:args];
  _childSession = nil;
}

- (void)_runMoshWithArgs:(NSString *)args
{
  [self.delegate indexCommand:args];
  self.sessionParameters.childSessionParameters = [[MoshParameters alloc] init];
  self.sessionParameters.childSessionType = @"mosh";
  _childSession = [[MoshSession alloc] initWithDevice:_device andParametes:self.sessionParameters.childSessionParameters];
  [_childSession executeAttachedWithArgs:args];
  
  _childSession = nil;
}

- (void)_runSystemCommandWithArgs:(NSString *)args
{
  self.sessionParameters.childSessionParameters = nil;
  [self.delegate indexCommand:args];
  _childSession = [[SystemSession alloc] initWithDevice:_device andParametes:self.sessionParameters.childSessionParameters];
  self.sessionParameters.childSessionType = @"system";
  [_childSession executeAttachedWithArgs:args];
  _childSession = nil;
}


- (void)_runSSHWithArgs:(NSString *)args
{
  self.sessionParameters.childSessionParameters = nil;
  [self.delegate indexCommand:args];
  _childSession = [[SSHSession alloc] initWithDevice:_device andParametes:self.sessionParameters.childSessionParameters];
  self.sessionParameters.childSessionType = @"ssh";
  [_childSession executeAttachedWithArgs:args];
  _childSession = nil;
}

//- (void)_runSSH2WithArgs:(NSString *)args
//{
//  self.sessionParameters.childSessionParameters = nil;
//  [self.delegate indexCommand:args];
//  _childSession = [[SSHSession2 alloc] initWithDevice:_device andParametes:self.sessionParameters.childSessionParameters];
//  self.sessionParameters.childSessionType = @"ssh2";
//  [_childSession executeAttachedWithArgs:args];
//  _childSession = nil;
//}


- (void)out:(const char *)str
{
  fprintf(_stream.out, "%s\n", str);
}

- (void)sigwinch
{
  [_repl sigwinch];
  [_childSession sigwinch];
}

- (void)kill
{
  [_childSession kill];

  // Close stdin to end the linenoise loop.
  if (_stream.in) {
    fclose(_stream.in);
    _stream.in = NULL;
  }
  [_repl kill];
  
  // Instruct ios_system to release the data for this shell:
  ios_closeSession((__bridge void*)self);
}

- (void)suspend
{
  [_childSession suspend];
}

- (BOOL)handleControl:(NSString *)control
{
  if (_childSession) {
    return [_childSession handleControl:control];
  }

  return NO;
}

- (void)setActiveSession {
  ios_switchSession((__bridge void*)self);
}


@end
