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
#include <dispatch/dispatch.h>

#import "MCPSession.h"
#import "MoshSession.h"
#import "BKPubKey.h"
#import "SSHCopyIDSession.h"
#import "SSHSession.h"

#import "BKUserConfigurationManager.h"
#import "BlinkPaths.h"

#include <ios_system/ios_system.h>

#include "ios_error.h"
#include "Blink-Swift.h"


@implementation MCPSession {
  NSString * _sessionUUID;
  Session *_childSession;
  NSString *_currentCmd;
  NSMutableArray *_sshClients;
//  dispatch_queue_t _cmdQueue;
  dispatch_queue_t _sshQueue;
  TermStream *_cmdStream;
  NSString *_currentCmdLine;
}

@dynamic sessionParams;

- (id)initWithDevice:(TermDevice *)device andParams:(MCPParams *)params {
  if (self = [super initWithDevice:device andParams:params]) {
    _sshClients = [[NSMutableArray alloc] init];
    _sessionUUID = [[NSProcessInfo processInfo] globallyUniqueString];
    _cmdQueue = dispatch_queue_create("mcp.command.queue", DISPATCH_QUEUE_SERIAL);
    _sshQueue = dispatch_queue_create("mcp.sshclients.queue", DISPATCH_QUEUE_SERIAL);
    [self setActiveSession];
//    ios_setMiniRoot([BlinkPaths documents]);
//    [self updateAllowedPaths];
//    [[NSFileManager defaultManager] changeCurrentDirectoryPath:[BlinkPaths documents]];
//    ios_setContext((__bridge void*)self);
//
    thread_stdout = nil;
    thread_stdin = nil;
    thread_stderr = nil;
    
    ios_setStreams(_stream.in, _stream.out, _stream.err);
  }
  
  return self;
}

- (void)executeWithArgs:(NSString *)args {
  dispatch_async(_cmdQueue, ^{
    [self setActiveSession];
    NSString *homePath = [BlinkPaths homePath];
    ios_setMiniRoot(homePath);
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:homePath];
    [self updateAllowedPaths];
//    ios_setContext((__bridge void*)self);
//    
    thread_stdout = nil;
    thread_stdin = nil;
    thread_stderr = nil;
    
    ios_setStreams(_stream.in, _stream.out, _stream.err);
    
    // We are restoring mosh session if possible first.
    if ([@"mosh" isEqualToString:self.sessionParams.childSessionType] && self.sessionParams.hasEncodedState) {
      MoshSession *mosh = [[MoshSession alloc] initWithDevice:_device andParams:self.sessionParams.childSessionParams];
      mosh.mcpSession = self;
      _childSession = mosh;
      [_childSession executeAttachedWithArgs:@""];
      _childSession = nil;
      if (self.sessionParams.hasEncodedState) {
        return;
      }
    }
    #if TARGET_OS_MACCATALYST
      BKHosts *localhost = [BKHosts withHost:@"localhost"];
      if (localhost) {
        NSString *sshcmd = [NSString stringWithFormat: @"ssh -A %@", localhost.host];
        [self enqueueCommand:sshcmd];
      } else {
        [_device prompt:@"blink> " secure:NO shell:YES];
      }
    #else
    [_device prompt:@"blink> " secure:NO shell:YES];
    #endif
  });
}

/*!
 @brief Enqueue a new command coming from a x-callback-url. After completing successfully return to the
 @discussion Accepts the x-callback-url and the x-success URL to call after a successful command completion
 @param cmd Command to be executed
 @param xCallbackSuccessUrl Success URL of the original application (like Shortcuts) to return to after reunning the command
*/
- (void)enqueueXCallbackCommand:(NSString *)cmd xCallbackSuccessUrl:(NSURL *)xCallbackSuccessUrl {
  [self enqueueCommand:cmd];
  
  dispatch_async(_cmdQueue, ^{
    blink_openurl(xCallbackSuccessUrl);
  });
  
}

- (void)enqueueCommand:(NSString *)cmd {
  [self enqueueCommand:cmd skipHistoryRecord:NO];
}

- (void)enqueueCommand:(NSString *)cmd skipHistoryRecord: (BOOL) skipHistoryRecord {
  if (_cmdStream) {
    [_device writeInDirectly:[NSString stringWithFormat: @"%@\n", cmd]];
    return;
  }
  dispatch_async(_cmdQueue, ^{
    self->_currentCmdLine = cmd;
    [self _runCommand:cmd skipHistoryRecord:skipHistoryRecord];
    self->_currentCmdLine = nil;
  });
}

- (BOOL)_runCommand:(NSString *)cmdline skipHistoryRecord: (BOOL) skipHistoryRecord {
  
  cmdline = [cmdline stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  
  if (!skipHistoryRecord) {
    [HistoryObj appendIfNeededWithCommand:cmdline];
  }
  
  
  
  NSString *mayBeURLString = [cmdline stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  
  NSURL *mayBeHttpURL = [NSURL URLWithString:mayBeURLString];
  NSString *scheme = mayBeHttpURL.scheme.lowercaseString;
  if ([@"http" isEqual: scheme] || [@"https" isEqual:scheme]) {
    cmdline = [NSString stringWithFormat:@"browse %@", mayBeURLString];
  }
  
  NSArray *arr = [cmdline componentsSeparatedByString:@" "];
  NSString *cmd = arr[0];
  
  
  [self setActiveSession];
  
//  ios_setContext((__bridge void*)self);
  
  thread_stdout = nil;
  thread_stdin = nil;
  thread_stderr = nil;

  ios_setStreams(_stream.in, _stream.out, _stream.err);
  
  if ([cmd isEqualToString:@"exit"]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.delegate sessionFinished];
    });
    
    return NO;
  }
  
  if ([cmd isEqualToString:@"mosh"]) {
    [self _runMoshWithArgs:cmdline];
    if (self.sessionParams.hasEncodedState) {
      return NO;
    }
  } else if ([cmd isEqualToString:@"ssh2"]) {
    [self _runSSHWithArgs:cmdline];
  } else if ([cmd isEqualToString:@"ssh-copy-id"]) {
    [self _runSSHCopyIDWithArgs:cmdline];
  } else {
    
    _currentCmd = cmdline;
    thread_stdout = nil;
    thread_stdin = nil;
    thread_stderr = nil;
    
    _cmdStream = [_device.stream duplicate];
    [self setActiveSession];
    ios_setStreams(_cmdStream.in, _cmdStream.out, _cmdStream.err);
    
    ios_setWindowSize((int)self.device.cols, (int)self.device.rows, _sessionUUID.UTF8String);

    ios_system(cmdline.UTF8String);
    _currentCmd = nil;
    [_cmdStream close];
    _cmdStream = nil;
    _sshClients = [[NSMutableArray alloc] init];
  }
  
  [_device prompt:@"blink> " secure:NO shell:YES];
  
  return YES;
}

- (int)main:(int)argc argv:(char **)argv
{
  return 0;
}

- (void)registerSSHClient:(id __weak)sshClient {
  dispatch_sync(_sshQueue, ^(void){
    [_sshClients addObject:sshClient];
  });
}

- (void)unregisterSSHClient:(id __weak)sshClient {
  dispatch_sync(_sshQueue, ^(void){
    [_sshClients removeObject:sshClient];
  });
}

- (bool)isRunningCmd {
  return _childSession != nil || _currentCmd != nil || _currentCmdLine != nil;
}


- (void)updateAllowedPaths
{
  NSArray<NSString *>* allowedPaths = [BlinkPaths cleanedSymlinksInHomeDirectory];
  ios_setAllowedPaths(allowedPaths);
}

- (void)_runSSHCopyIDWithArgs:(NSString *)args
{
  self.sessionParams.childSessionParams = nil;
  _childSession = [[SSHCopyIDSession alloc] initWithDevice:_device andParams:self.sessionParams.childSessionParams];
  self.sessionParams.childSessionType = @"sshcopyid";
  
  // duplicate args
  NSString *str = [NSString stringWithFormat:@"%@", args];
  [_childSession executeAttachedWithArgs:str];

  _childSession = nil;
}

- (void)_runMoshWithArgs:(NSString *)args
{
  self.sessionParams.childSessionParams = [[MoshParams alloc] init];
  self.sessionParams.childSessionType = @"mosh";
  MoshSession *mosh = [[MoshSession alloc] initWithDevice:_device andParams:self.sessionParams.childSessionParams];
  mosh.mcpSession = self;
  _childSession = mosh;
  
  // duplicate args
  NSString *str = [NSString stringWithFormat:@"%@", args];
  [_childSession executeAttachedWithArgs:str];
  
  _childSession = nil;
}

- (void)_runSSHWithArgs:(NSString *)args
{
  self.sessionParams.childSessionParams = nil;
  _childSession = [[SSHSession alloc] initWithDevice:_device andParams:self.sessionParams.childSessionParams];
  self.sessionParams.childSessionType = @"ssh";
  [_childSession executeAttachedWithArgs:args];
  _childSession = nil;
}

- (void)sigwinch
{
  ios_setWindowSize((int)self.device.cols, (int)self.device.rows, _sessionUUID.UTF8String);
  [_childSession sigwinch];
  dispatch_sync(_sshQueue, ^{
    for (id client in _sshClients) {
      [client sigwinch];
    }
  });
}

- (void)kill
{
  if (_sshClients.count > 0) {
    dispatch_sync(_sshQueue, ^{
      for (id client in _sshClients) {
        [client kill];
      }
      [_device writeIn:@"\x03"];
    });
    
    return;
  } else if (_childSession) {
    [_childSession kill];
  } else { 
    ios_kill();
  }
  
  ios_closeSession(_sessionUUID.UTF8String);
  
  [_device writeIn:@"\x03"];
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
  NSString *ctrlC = @"\x03";
  NSString *ctrlD = @"\x04";
  
  if (_childSession) {
    if ([control isEqualToString:ctrlC] || [control isEqualToString:ctrlD]) {
      [_device closeReadline];
    }
    
    if (_sshClients.count > 0) {
      [_device closeReadline];
      dispatch_sync(_sshQueue, ^{
        for (id client in _sshClients) {
          [client kill];
        }
      });
    }
    return [_childSession handleControl:control];
  }
  
  if ([control isEqualToString:ctrlC] || [control isEqualToString:ctrlD]) {
    if (_currentCmd) {
      if ([_device rawMode]) {
        return NO;
      }
      if (_sshClients.count > 0) {
        [_device closeReadline];
        dispatch_sync(_sshQueue, ^{
          for (id client in _sshClients) {
            [client kill];
          }
        });
      } else {
        if ([control isEqualToString:ctrlD]) {
          [_device closeReadline];
          [_cmdStream closeIn];
          return NO;
        }
        [self setActiveSession];
//        ios_setStreams(_cmdStream.in, _cmdStream.out, _cmdStream.err);
          if (_tokioSignals) {
            [_tokioSignals signalCtrlC];
              _tokioSignals = nil;
          } else {
            ios_kill();
        }
      }
      return YES;
    } else {
      if ([_device rawMode]) {
        return YES;
      }
      return NO;
    }
    return YES;
  }

  return NO;
}


- (void)setActiveSession {
//  thread_stdout = nil;
//    thread_stdin = nil;
//    thread_stderr = nil;
//
//    FILE * savedStdOut = stdout;
//    FILE * savedStdErr = stderr;
//    FILE * savedStdIn = stdin;
//
//    if (_cmdStream) {
//      stdout = _cmdStream.out;
//      stderr = _cmdStream.err;
//      stdin = _cmdStream.in;
//    } else {
//      stdout = _stream.out;
//      stderr = _stream.err;
//      stdin = _stream.in;
//  //    ios_setStreams(_stream.in, _stream.out, _stream.err);
//    }
    
    ios_switchSession(_sessionUUID.UTF8String);
    ios_setContext((__bridge void*)self);
    
//    stdout = savedStdOut;
//    stderr = savedStdErr;
//    stdin = savedStdIn;
//
  
  
}


@end
