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

#import "BKUserConfigurationManager.h"
#import "BlinkPaths.h"

#include <ios_system/ios_system.h>

#include "ios_error.h"

@implementation MCPSession {
  Session *_childSession;
  NSString *_currentCmd;
}

@dynamic sessionParameters;

- (id)initWithDevice:(TermDevice *)device andParametes:(SessionParameters *)parameters
{
  if (self = [super initWithDevice:device andParametes:parameters]) {
    _repl = [[Repl alloc] initWithDevice:device andStream: _stream];
  }
  
  return self;
}

- (int)main:(int)argc argv:(char **)argv
{
  [self setActiveSession];
  ios_setMiniRoot([BlinkPaths documents]);
  ios_setStreams(_stream.in, _stream.out, _stream.err);
  ios_setContext((__bridge void*)self);
  
  if ([@"mosh" isEqualToString:self.sessionParameters.childSessionType]) {
    _childSession = [[MoshSession alloc] initWithDevice:_device andParametes:self.sessionParameters.childSessionParameters];
    [_childSession executeAttachedWithArgs:@""];
    _childSession = nil;
  }
  
  replaceCommand(@"curl", @"curl_static_main", true); // replace curl in ios_system with our own, accessing Blink keys.
  replaceCommand(@"help", @"help_main", true);
  replaceCommand(@"config", @"config_main", true);
  replaceCommand(@"music", @"music_main", true);
  replaceCommand(@"clear", @"clear_main", true);
  replaceCommand(@"showkey", @"showkey_main", true);
  replaceCommand(@"history", @"history_main", true);
  replaceCommand(@"open", @"open_main", true);
  replaceCommand(@"link-files", @"link_files_main", true);
  replaceCommand(@"bench", @"bench_main", true);
  replaceCommand(@"geo", @"geo_main", true);
  replaceCommand(@"udptunnel", @"udptunnel_main", true);
//  replaceCommand(@"ssh-agent", @"ssh_agent_main", true);
//  replaceCommand(@"ssh-add", @"ssh_add_main", true);
  // TODO: move all our commands to plist
  addCommandList([[NSBundle mainBundle] pathForResource:@"blinkCommandsDictionary" ofType:@"plist"]);
  
  
  [self updateAllowedPaths];
  
  [[NSFileManager defaultManager] changeCurrentDirectoryPath:[BlinkPaths documents]];
  [_repl loopWithCallback:^BOOL(NSString *cmdline) {
  
    NSArray *arr = [cmdline componentsSeparatedByString:@" "];
    NSString *cmd = arr[0];
    
    if ([cmd isEqualToString:@"exit"]) {
      return NO;
    } else if ([cmd isEqualToString:@"mosh"]) {
      [self _runMoshWithArgs:cmdline];
    } else if ([cmd isEqualToString:@"ssh2"]) {
      [self _runSSHWithArgs:cmdline];
    } else if ([cmd isEqualToString:@"ssh-copy-id"]) {
      [self _runSSHCopyIDWithArgs:cmdline];
    } else {
      [self.delegate indexCommand:cmdline];
      _currentCmd = cmdline;
      thread_stdout = nil;
      thread_stdin = nil;
      thread_stderr = nil;
      
      // Re-evalute column number before each command
      setenv("COLUMNS", [@(_device->win.ws_col) stringValue].UTF8String, 1); // force rewrite of value
      ios_system(cmdline.UTF8String);
      _currentCmd = nil;
    }
    
    return YES;
  }];

  puts("Bye!");
  
  return 0;
}

- (bool)isRunningCmd {
  return _childSession != nil || _currentCmd != nil;
}

- (NSArray<NSString *> *)_symlinksInHomeDirectory
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSMutableArray<NSString *> *allowedPaths = [[NSMutableArray alloc] init];
  
  NSString *documentsPath = [BlinkPaths documents];
  NSArray<NSString *> * files = [fm contentsOfDirectoryAtPath:documentsPath error:nil];
  
  for (NSString *path in files) {
    NSString *filePath = [documentsPath stringByAppendingPathComponent:path];
    NSDictionary * attrs = [fm attributesOfItemAtPath:filePath error:nil];
    if (attrs[NSFileType] != NSFileTypeSymbolicLink) {
      continue;
    }
      
    NSString *destPath = [fm destinationOfSymbolicLinkAtPath:filePath error:nil];
    if (!destPath) {
      continue;
    }
    
    if (![fm isReadableFileAtPath:destPath]) {
      // We lost access. Remove that symlink
      [fm removeItemAtPath:filePath error:nil];
      continue;
    }
    
    [allowedPaths addObject:destPath];
  }
  return allowedPaths;
}

- (void)updateAllowedPaths
{
  ios_setAllowedPaths([self _symlinksInHomeDirectory]);
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

- (void)_runSSHWithArgs:(NSString *)args
{
  self.sessionParameters.childSessionParameters = nil;
  [self.delegate indexCommand:args];
  _childSession = [[SSHSession alloc] initWithDevice:_device andParametes:self.sessionParameters.childSessionParameters];
  self.sessionParameters.childSessionType = @"ssh";
  [_childSession executeAttachedWithArgs:args];
  _childSession = nil;
}

- (void)sigwinch
{
  [_repl sigwinch];
  [_childSession sigwinch];
  [_sshClient sigwinch];
}

- (void)kill
{
  [_childSession kill];

  ios_kill();
  
  // Instruct ios_system to release the data for this shell:
  ios_closeSession((__bridge void*)self);
  
  if (_device.stream.in) {
    fclose(_device.stream.in);
    _device.stream.in = NULL;
  }
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
  
  if (_currentCmd && ([control isEqualToString:@"c"] || [control isEqualToString:@"d"])) {
    if ([_device rawMode]) {
      return NO;
    }
    ios_kill();
    return YES;
  }

  return NO;
}

- (void)setActiveSession {
  FILE * savedStdOut = stdout;
  FILE * savedStdErr = stderr;
  FILE * savedStdIn = stdin;
  stdout = _stream.out;
  stderr = _stream.err;
  stdin = _stream.in;
  ios_switchSession((__bridge void*)self);
  stdout = savedStdOut;
  stderr = savedStdErr;
  stdin = savedStdIn;
}

- (void)dealloc {
  _repl = nil;
}

@end
