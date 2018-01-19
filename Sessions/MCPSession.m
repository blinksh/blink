////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016 Blink Mobile Shell Project
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

#include "linenoise.h"
#include "utf8.h"

#import "MCPSession.h"
#import "MoshSession.h"
#import "BKPubKey.h"
#import "SSHCopyIDSession.h"
#import "SSHSession.h"

#define MCP_MAX_LINE 4096


@implementation MCPSession {
  Session *_childSession;
}

@dynamic sessionParameters;

- (NSArray *)splitCommandAndArgs:(NSString *)cmdline
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

- (void)setTitle
{
  fprintf(_stream.control.termout, "\033]0;blink\007");
}

- (int)main:(int)argc argv:(char **)argv
{
  if ([@"mosh" isEqualToString:self.sessionParameters.childSessionType]) {
    _childSession = [[MoshSession alloc] initWithStream:_stream andParametes:self.sessionParameters.childSessionParameters];
    [_childSession executeAttachedWithArgs:@""];
    _childSession = nil;
    // If it exits it goes to default
    //return 0;
  }
  
  char *line;
  argc = 0;
  argv = nil;

  NSString *docsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
  NSString *filePath = [docsPath stringByAppendingPathComponent:@"history.txt"];

  const char *history = [filePath UTF8String];

  [self.stream.control setRawMode:NO];

  linenoiseSetEncodingFunctions(linenoiseUtf8PrevCharLen,
                                linenoiseUtf8NextCharLen,
                                linenoiseUtf8ReadCode);

  linenoiseHistoryLoad(history);

  while ((line = [self linenoise:"blink> "]) != nil) {
    if (line[0] != '\0' && line[0] != '/') {
      linenoiseHistoryAdd(line);
      linenoiseHistorySave(history);

      NSString *cmdline = [[NSString alloc] initWithFormat:@"%s", line];
      cmdline = [cmdline stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
      NSArray *arr = [self splitCommandAndArgs:cmdline];
      NSString *cmd = arr[0];

      if ([cmd isEqualToString:@"help"]) {
        [self showHelp];
      } else if ([cmd isEqualToString:@"mosh"]) {
        // At some point the parser will be in the JS, and the call will, through JSON, will include what is needed.
        // Probably passing a Server struct of some type.

        [self runMoshWithArgs:cmdline];
      } else if ([cmd isEqualToString:@"ssh"]) {
        // At some point the parser will be in the JS, and the call will, through JSON, will include what is needed.
        // Probably passing a Server struct of some type.

        [self runSSHWithArgs:cmdline];
      } else if ([cmd isEqualToString:@"exit"]) {
        break;
      } else if ([cmd isEqualToString:@"ssh-copy-id"]) {
        [self runSSHCopyIDWithArgs:cmdline];
      } else if ([cmd isEqualToString:@"config"]) {
        [self showConfig];
      } else {
        [self out:"Unknown command. Type 'help' for a list of available operations"];
      }
    }

    [self setTitle]; // Temporary, until the apps restore the right state.

    free(line);
  }

  [self out:"Bye!"];

  return 0;
}

- (void)showConfig
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [[UIApplication sharedApplication]
     sendAction:NSSelectorFromString(@"showConfig:") to:nil from:nil forEvent:nil];
  });
}

- (void)runSSHCopyIDWithArgs:(NSString *)args
{
  self.sessionParameters.childSessionParameters = nil;
  _childSession = [[SSHCopyIDSession alloc] initWithStream:_stream andParametes:self.sessionParameters.childSessionParameters];
  self.sessionParameters.childSessionType = @"sshcopyid";
  [_childSession executeAttachedWithArgs:args];
  _childSession = nil;
}

- (void)runMoshWithArgs:(NSString *)args
{
  [self.delegate indexCommand:args];
  self.sessionParameters.childSessionParameters = [[MoshParameters alloc] init];
  self.sessionParameters.childSessionType = @"mosh";
  _childSession = [[MoshSession alloc] initWithStream:_stream andParametes:self.sessionParameters.childSessionParameters];
  [_childSession executeAttachedWithArgs:args];
  
  _childSession = nil;
}

- (void)runSSHWithArgs:(NSString *)args
{
  self.sessionParameters.childSessionParameters = nil;
  [self.delegate indexCommand:args];
  _childSession = [[SSHSession alloc] initWithStream:_stream andParametes:self.sessionParameters.childSessionParameters];
  self.sessionParameters.childSessionType = @"ssh";
  [_childSession executeAttachedWithArgs:args];
  _childSession = nil;
}

- (NSString *)shortVersionString
{
  NSString *compileDate = [NSString stringWithUTF8String:__DATE__];

  NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
  NSString *appDisplayName = [infoDictionary objectForKey:@"CFBundleName"];
  NSString *majorVersion = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
  NSString *minorVersion = [infoDictionary objectForKey:@"CFBundleVersion"];

  return [NSString stringWithFormat:@"%@: v%@.%@. %@",
                                    appDisplayName, majorVersion, minorVersion, compileDate];
}

- (void)showHelp
{
  NSString *help = [@[
    @"",
    [self shortVersionString],
    @"",
    @"Available commands:",
    @"  mosh: mosh client.",
    @"  ssh: ssh client.",
    @"  ssh-copy-id: Copy an identity to the server.",
    @"  config: Configure Blink. Add keys, hosts, themes, etc...",
    @"  help: Prints this.",
    @"  exit: Close this shell.",
    @"",
    @"Available gestures and keyboard shortcuts:",
    @"  two fingers tap or cmd+t: New shell.",
    @"  two fingers swipe up or cmd+w: Close shell.",
    @"  two fingers drag down dismiss keyboard.",
    @"  one finger swipe left/right or cmd+shift+[/]: Switch between shells.",
    @"  cmd+alt+N: Switch to shell number N.",
    @"  cmd+o: Switch to other screen (Airplay mode).",
    @"  cmd+shift+o: Move current shell to other screen (Airplay mode).",
    @"  cmd+,: Open config.",
    @"  pinch: Change font size.",
    @""
  ] componentsJoinedByString:@"\r\n"];

  [self out:help.UTF8String];
}

- (void)out:(const char *)str
{
  fprintf(_stream.out, "%s\r\n", str);
}

- (char *)linenoise:(char *)prompt
{
  char buf[MCP_MAX_LINE];
  if (_stream.in == NULL) {
    return nil;
  }

  int count = linenoiseEdit(fileno(_stream.in), _stream.out, buf, MCP_MAX_LINE, prompt, _stream.sz);
  if (count == -1) {
    return nil;
  }

  return strdup(buf);
}

- (void)sigwinch
{
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
}

- (void)suspend
{
  if (_childSession == nil) {
    [self out:@"\r\n".UTF8String];
  } else {
    [_childSession suspend];
  }
}

@end
