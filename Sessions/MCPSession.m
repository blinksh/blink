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
#import "BKPubKey.h"

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
  // NOTE After kill, commands already queued on _cmdQueue still run before the device closes.
  // Flag termination here if they ever need to be skipped.
  // BOOL _terminated;
}

@dynamic sessionParams;

- (id)initWithDevice:(TermDevice *)device andParams:(MCPParams *)params {
  if (self = [super initWithDevice:device andParams:params]) {
    _sshClients = [[NSMutableArray alloc] init];
    _sessionUUID = [[NSProcessInfo processInfo] globallyUniqueString];
    _cmdQueue = dispatch_queue_create("mcp.command.queue", DISPATCH_QUEUE_SERIAL);
    _sshQueue = dispatch_queue_create("mcp.sshclients.queue", DISPATCH_QUEUE_SERIAL);
    [self setActiveSession];
    device.readlineListener = self;

    NSString *initialPrompt = [WhatsNewInfo mustDisplayInitialPrompt];
    if (initialPrompt) {
      [device writeOutLn:initialPrompt];
    }
  }

  return self;
}

- (void)executeWithArgs:(NSString *)args {
  dispatch_async(_cmdQueue, ^{
    [self setActiveSession];
    ios_setStreams(_stream.in, _stream.out, _stream.out);

    NSString *homePath = [BlinkPaths homePath];
    if (homePath) {
      ios_setDirectoryURL([NSURL fileURLWithPath:homePath]);
    }

    // We are restoring mosh session if possible first.
    if ([@"mosh" isEqualToString:self.sessionParams.childSessionType] && self.sessionParams.hasEncodedState) {
      MoshParams *moshParams = (MoshParams *)self.sessionParams.childSessionParams;

      BlinkMosh *mosh = [[BlinkMosh alloc] initWithMcpSession: self device:_device andParams:moshParams];
      _childSession = mosh;
      [_childSession executeAttachedWithArgs:@""];
      _childSession = nil;
      if (self.sessionParams.hasEncodedState) {
        return;
      }
    }

    NSString *initialCommand = self.sessionParams.initialCommand;
    if (initialCommand.length > 0) {
      [self enqueueCommand:initialCommand];
      NSURL *successURL = self.sessionParams.initialCommandSuccessURL;
      if (successURL) {
        // _cmdQueue is serial, so this cannot run until the command returns.
        dispatch_async(_cmdQueue, ^{
          blink_openurl(successURL);
        });
      }
      return;
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
    if (_device) {
      [_device prompt:@"blink> " secure:NO shell:YES];
    }
    #endif
  });
}

- (void)enqueueCommand:(NSString *)cmd {
  [self enqueueCommand:cmd skipHistoryRecord:NO];
}

- (void)enqueueCommand:(NSString *)cmd skipHistoryRecord: (BOOL) skipHistoryRecord {
  // NOTE This shouldn't be done this way. The MCP should read from, but not write to the input.
  // The terminal device in this case is acting like a shell, which is not fully wrong, but I don't like it.
  // The terminal view is also receiving requests for "what's being typed" in order to then do Completion, etc...
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

  if ([cmd isEqualToString:@"exit"]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.delegate sessionFinished];
    });
    
    return NO;
  }
  
  // NOTE We don't have a passthrough for all of it.
  // This should be done at a different function
  setenv("LC_ALL", "UTF-8", 1);
  setenv("LC_CTYPE", "UTF-8", 1);
  setlocale(LC_ALL, "UTF-8");
  setlocale(LC_CTYPE, "UTF-8");
  
  if ([cmd isEqualToString:@"mosh"]) {
    [self _runMoshWithArgs:cmdline];
    if (self.sessionParams.hasEncodedState) {
      return NO;
    }
  } else if (![cmd isEqualToString:@""]) {
    // Manually set raw mode for some commands, as we cannot receive control any other way.
    [_device closeReadline];
    if ([cmd isEqualToString:@"less"] || [cmd isEqualToString:@"vim"]) {
      self.device.rawMode = true;
      self.device.autoCR = TRUE;
    }
    [self setActiveSession];

    _currentCmd = cmdline;

    _cmdStream = [_device.stream duplicate];
    ios_setStreams(_cmdStream.in, _cmdStream.out, _cmdStream.out);
    // ios_system provides a get command that returns a "tty" instead of an open.  We can control it here.
    FILE* tty = [_cmdStream openTTY];
    ios_settty(tty);
    ios_setWindowSize((int)self.device.cols, (int)self.device.rows, _sessionUUID.UTF8String);

    pid_t _pid = ios_fork();
    ios_system(cmdline.UTF8String);
    _currentCmd = nil;
    ios_waitpid(_pid);
    ios_releaseThreadId(_pid);
    self.device.autoCR = FALSE;

    fclose(tty);
    tty = nil;
    [_cmdStream close];
    _cmdStream = nil;
    _sshClients = [[NSMutableArray alloc] init];

    setenv("LC_ALL", "UTF-8", 1);
    setenv("LC_CTYPE", "UTF-8", 1);
    setlocale(LC_ALL, "UTF-8");
    setlocale(LC_CTYPE, "UTF-8");
  }
  
  if (_device) {
    // TODO At the moment this is just a prompt instead of a readline. This needs to be fixed.
    // And bc of that, we need to check that there is a device. The MCP may be killed, but the loop here may still
    // try to write to the device.
    [_device prompt:@"blink> " secure:NO shell:YES];
  }
  
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


- (void)_runMoshWithArgs:(NSString *)args
{
  self.sessionParams.childSessionParams = [[MoshParams alloc] init];
  self.sessionParams.childSessionType = @"mosh";
  BlinkMosh *mosh = [[BlinkMosh alloc] initWithMcpSession: self device:_device andParams:self.sessionParams.childSessionParams];
  //MoshSession *mosh = [[MoshSession alloc] initWithDevice:_device andParams:self.sessionParams.childSessionParams];
  //mosh.mcpSession = self;
  _childSession = mosh;
  
  // duplicate args
  NSString *str = [NSString stringWithFormat:@"%@", args];
  [_childSession executeAttachedWithArgs:str];
  
  _childSession = nil;
}

- (void)sigwinch
{
  [self setActiveSession];
  ios_setWindowSize((int)self.device.cols, (int)self.device.rows, _sessionUUID.UTF8String);
  
  [_childSession sigwinch];
  dispatch_sync(_sshQueue, ^{
    for (id client in _sshClients) {
      [client sigwinch];
    }
  });
}

// TODO It would be nice if this could be re-used (interrupt children, interrupt yourself).
- (void)kill
{
  if (_sshClients.count > 0) {
    dispatch_sync(_sshQueue, ^{
      for (id client in _sshClients) {
        [client kill];
      }
    });
  } else if (_childSession) {
    [_childSession kill];
  } else if (_cmdStream) {
    [self setActiveSession];
    ios_kill();
  }

  // A kill may be ignored or only land at a cancellation point; EOF on stdin releases
  // commands blocked on input.
  [_device hangup];

  // _cmdQueue is serial, so the device closes once the running command is done.
  dispatch_async(_cmdQueue, ^{
    ios_closeSession(self->_sessionUUID.UTF8String);
    [self->_device close];
    self->_device = NULL;
  });
}

- (void)suspend
{
  [self setActiveSession];
  [_childSession suspend];
}

- (void)handleControl:(NSString *)control
{
  NSString *ctrlC = @"\x03";
  NSString *ctrlD = @"\x04";
  NSString *ctrlL = @"\x0c";

  // Only an unarmed prompt lets ctrl-l through (armed ones handle C-l in the
  // line editor). Must run before the branches below — they kill children or
  // reset stdin on any control.
  if ([control isEqualToString:ctrlL]) {
    if (![self isRunningCmd]) {
      [self enqueueCommand:@"clear" skipHistoryRecord:YES];
    }
    return;
  }

  if (_childSession) {
    if (_sshClients.count > 0) {
      dispatch_sync(_sshQueue, ^{
        for (id client in _sshClients) {
          // TODO We need the kill here because of the Proxy connections, but if we simplify, SSH will just be a
          // regular child session.
          [client kill];
        }
      });
    } else {
      // Send kill signal to child session.
      [_childSession kill];
    }
    return;
  } else if (_currentCmd) {
    if ([control isEqualToString:ctrlD]) {
      // We give a chance to the session to capture the new stdin, as it may have changed.
      [self setActiveSession];
      if (_cmdStream != NULL) {
        [_cmdStream close];
        _cmdStream = NULL;
        _cmdStream = [_device.stream duplicate];
      }
      ios_setStreams(_cmdStream.in, _cmdStream.out, _cmdStream.out);
      return;
    }
    
    if ([control isEqualToString:ctrlC]) {
      if (_sshClients.count > 0) {
        dispatch_sync(_sshQueue, ^{
          for (id client in _sshClients) {
            [client kill];
          }
        });
      } else {
        if (_tokioSignals) {
          [_tokioSignals signalCtrlC];
          _tokioSignals = nil;
        } else {
          [self setActiveSession];
          ios_kill();
        }
      }
      return;
    }
  }

  return;
}

- (void)setActiveSession {
  // Need to reset all thread variables, including context!
  // This fixes "segmentation faults" after a few subsequent session - new command cycles.
  thread_context = NULL;
  ios_switchSession(_sessionUUID.UTF8String);
  ios_setContext((__bridge void*)self);
  thread_stdout = NULL;
  thread_stdin = NULL;
  thread_stderr = NULL;
}

- (void)lineSubmitted:(NSString *)line { 
  [self enqueueCommand:line];
}

@end
