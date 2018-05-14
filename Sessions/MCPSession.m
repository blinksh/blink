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

#include "replxx.h"


#import "MCPSession.h"
#import "MoshSession.h"
#import "BKPubKey.h"
#import "SSHCopyIDSession.h"
#import "SSHSession.h"
#import "SystemSession.h"
//#import "SSHSession2.h"
#import "BKHosts.h"
#import "BKTheme.h"
#import "MusicManager.h"
#import "BKDefaults.h"
#import "BKUserConfigurationManager.h"
#import "BlinkPaths.h"


// from ios_system:

#include <ios_system/ios_system.h>


#define MCP_MAX_LINE 4096
#define MCP_MAX_HISTORY 1000

NSArray *__commandList;
NSDictionary *__commandHints;
// List of all commands available, sorted alphabetically:
// Extracted at runtime from ios_system() plus blinkshell commands:
NSArray* commandList;

// for file completion
// do recompute directoriesInPath only if $PATH has changed
static NSString* fullCommandPath = @"";
static NSArray *directoriesInPath;

NSArray<NSString *> *splitCommandAndArgs(NSString *cmdline)
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

NSArray<NSString *> *commandsByPrefix(NSString *prefix)
{
  if (prefix.length == 0) {
    return commandList;
  }
  NSPredicate * prefixPred = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH[c] %@", prefix];
  return [__commandList filteredArrayUsingPredicate:prefixPred];
}

NSArray<NSString *> *hostsByPrefix(NSString *prefix)
{
  NSMutableArray *hostsNames = [[NSMutableArray alloc] init];
  for (BKHosts *h in [BKHosts all]) {
    [hostsNames addObject:h.host];
  }
  
  if (prefix.length == 0) {
    return hostsNames;
  }
  NSPredicate * prefixPred = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH[c] %@", prefix];
  return [hostsNames filteredArrayUsingPredicate:prefixPred];
}

NSArray<NSString *> *musicActionsByPrefix(NSString *prefix)
{
  NSArray<NSString *> * actions = [[MusicManager shared] commands];
  
  if (prefix.length == 0) {
    return actions;
  }
  NSPredicate * prefixPred = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH[c] %@", prefix];
  return [actions filteredArrayUsingPredicate:prefixPred];
}

NSArray<NSString *> *historyActionsByPrefix(NSString *prefix)
{
  NSPredicate * prefixPred = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH[c] %@", prefix];
  return [@[@"-c", @"10", @"-10"] filteredArrayUsingPredicate:prefixPred];
}


NSArray<NSString *> *themesByPrefix(NSString *prefix) {
  NSMutableArray *themeNames = [[NSMutableArray alloc] init];
  for (BKTheme *theme in [BKTheme all]) {
    [themeNames addObject:theme.name];
  }
  
  if (prefix.length == 0) {
    return themeNames;
  }
  NSPredicate * prefixPred = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH[c] %@", prefix];
  return [themeNames filteredArrayUsingPredicate:prefixPred];
}

void hints(char const* line, int bp, replxx_hints* lc, ReplxxColor* color, void* ud)
{
  * color = 2;
  NSString *hint = nil;
  NSString *prefix = [NSString stringWithUTF8String:line];
  if (prefix.length == 0) {
    return;
  }
  
  NSArray<NSString *> *cmds = commandsByPrefix(prefix);
  if (cmds) {
    for (NSString *cmd in cmds) {
      NSString *hint = __commandHints[cmd];
      replxx_add_hint(lc, [hint substringFromIndex: prefix.length].UTF8String);
    }
//    hint = __commandHints[cmd];
  } else {
    NSArray *cmdAndArgs = splitCommandAndArgs(prefix);
    NSString *cmd = cmdAndArgs[0];
    prefix = cmdAndArgs[1];
    
    if ([cmd isEqualToString:@"ssh"] || [cmd isEqualToString:@"mosh"]) {
      hint = [hostsByPrefix(prefix) componentsJoinedByString:@", "];
    } else if ([cmd isEqualToString:@"theme"]) {
      hint = [themesByPrefix(prefix) componentsJoinedByString:@", "];
    } else if ([cmd isEqualToString:@"music"]) {
      hint = [musicActionsByPrefix(prefix) componentsJoinedByString:@", "];
    }
  }
  
  if ([hint length] > 0) {
    replxx_add_hint(lc, [hint substringFromIndex: prefix.length].UTF8String);
  }
}


@implementation MCPSession {
  Session *_childSession;
  Replxx* _replxx;
}

@dynamic sessionParameters;

- (void)setTitle
{
  fprintf(_stream.out, "\033]0;blink\007");
}


void initializeCommandListForCompletion() {
  // set up the list of commands for auto-complete:
  // list of commands from ios_system:
  NSMutableArray* combinedCommands = [commandsAsArray() mutableCopy];
  // add commands from Blinkshell:
  
  [combinedCommands addObjectsFromArray: __commandList];

  //  combinedCommands
  // sort alphabetically:
  commandList = [[[NSSet setWithArray:combinedCommands] allObjects] sortedArrayUsingSelector:@selector(compare:)];
}

void completion(char const* line, int bp, replxx_completions* lc, void* ud) {
  NSString* prefix = [NSString stringWithUTF8String:line];
  NSArray *commands = commandsByPrefix(prefix);
  
  if (commands.count > 0) {
    NSArray * advancedCompletion = @[@"ssh", @"mosh", @"theme", @"music", @"history"];
    for (NSString * cmd in commands) {
      if ([advancedCompletion indexOfObject:cmd] != NSNotFound) {
        replxx_add_completion(lc, [[cmd stringByAppendingString:@" "] substringFromIndex:bp].UTF8String);
      } else {
        replxx_add_completion(lc, [cmd substringFromIndex:bp].UTF8String);
      }
    }
    system_completion(line, bp, lc, ud);
    return;
  }
  
  NSArray *cmdAndArgs = splitCommandAndArgs(prefix);
  NSString *cmd = cmdAndArgs[0];
  NSString *args = cmdAndArgs[1];
  NSArray *completions = @[];
  
  if ([args isEqualToString:@""]) {
    system_completion(line, bp, lc, ud);
    return;
  }
  
  if ([cmd isEqualToString:@"ssh"] || [cmd isEqualToString:@"mosh"]) {
    completions = hostsByPrefix(args);
  } else if ([cmd isEqualToString:@"music"]) {
    completions = musicActionsByPrefix(args);
  } else if ([cmd isEqualToString:@"theme"]) {
    completions = themesByPrefix(args);
  } else if ([cmd isEqualToString:@"history"]) {
    completions = historyActionsByPrefix(args);
  }
  
  
  for (NSString *c in completions) {
    replxx_add_completion(lc, [[@[cmd, c] componentsJoinedByString:@" "] substringFromIndex:bp].UTF8String);
  }
  
  system_completion(line, bp, lc, ud);
}

void system_completion(char const* command, int bp, replxx_completions* lc, void* ud) {
  // autocomplete command for lineNoise
  // TODO: get current working directory from ios_system
  BOOL isDir;
  NSString* commandString = [NSString stringWithUTF8String:command];
  if ([commandString rangeOfString:@" "].location == NSNotFound) {
    // No spaces. The user is typing a command
    // check for pre-defined commands:
    for (NSString* existingCommand in commandList) {
      if ([existingCommand hasPrefix:commandString]) replxx_add_completion(lc, existingCommand.UTF8String);
    }
    // Commands in the PATH
    // Do we have an interpreter? (otherwise, there's no point)
    if (ios_executable("python") || ios_executable("lua")) {
      NSString* checkingPath = [NSString stringWithCString:getenv("PATH") encoding:NSASCIIStringEncoding];
      if (! [fullCommandPath isEqualToString:checkingPath]) {
        fullCommandPath = checkingPath;
        directoriesInPath = [fullCommandPath componentsSeparatedByString:@":"];
      }
      for (NSString* path in directoriesInPath) {
        // If the path component doesn't exist, no point in continuing:
        if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir]) continue;
        if (!isDir) continue; // same in the (unlikely) event the path component is not a directory
        NSArray* filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:Nil];
        for (NSString *fileName in filenames) {
          if ([fileName hasPrefix:commandString]) replxx_add_completion(lc,[fileName UTF8String]);
        }
      }
    }
  } else {
    // the user is typing an argument.
    // Is this one the commands that want a file as an argument?
    NSArray* commandArray = [commandString componentsSeparatedByString:@" "];
    if ([__commandList containsObject:commandArray[0]]) {
      return;
    }
    if ([operatesOn(commandArray[0]) isEqualToString:@"no"]) {
      return;
    }
    // If we made it this far, command operates on file or directory:
    // Last position of space in the command.
    // Would be better if I could get position of cursor.
    NSString* argument = commandArray.lastObject;
    // which directory?
    BOOL isDir;
    NSString* directory;
    NSString *file;
    if ([[NSFileManager defaultManager] fileExistsAtPath:argument isDirectory:&isDir] && isDir) {
      directory = argument;
      file = @"";
    } else {
      directory = [argument stringByDeletingLastPathComponent]; // can be empty.
      if (directory.length == 0) {
        directory = @".";
      }
      file = [argument lastPathComponent];
    }
    directory = [directory stringByExpandingTildeInPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:directory isDirectory:&isDir] && isDir) {
      NSArray* filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:Nil];
      for (NSString *fileName in filenames) {
        if ((file.length == 0) || [fileName hasPrefix:file]) {
          NSString* addition = [fileName substringFromIndex:[file length]];
          NSString * newCommand = [commandString stringByAppendingString:addition];
          newCommand = [newCommand substringFromIndex:bp];
          replxx_add_completion(lc, [newCommand UTF8String]);
        }
      }
    }
  }
}

+ (void)initialize
{
  __commandList = [
    @[@"mosh", @"ssh", @"exit", @"ssh-copy-id", @"config", @"theme", @"music", @"history", @"open", @"clear", @"help"]
        sortedArrayUsingSelector:@selector(compare:)
  ];
  
  __commandHints =
  @{
    @"help": @"help - Prints all commands. 🧐 ",
    @"mosh": @"mosh - Runs mosh client. 🦄",
    @"ssh": @"ssh - Runs ssh client. 🐌",
    @"ssh-copy-id": @"ssh-copy-id - Copy an identity to the server. 💌",
    @"config": @"config - Add keys, hosts, themes, etc... 🔧 ",
    @"theme": @"theme - Choose a theme 💅",
    @"music": @"music - Control music player 🎧",
    @"history": @"history - Use -c option to clear history. 🙈 ",
    @"clear": @"clear - Clear screen. 🙊",
    @"open": @"open - open url of file (Experimental). 📤",
    @"exit": @"exit - Exits current session. 👋"
  };
}
  

- (int)main:(int)argc argv:(char **)argv args:(char *)args
{
  _replxx = replxx_init();
  
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
  initializeCommandListForCompletion();
  [[NSFileManager defaultManager] changeCurrentDirectoryPath:[BlinkPaths documents]];

  [_device setRawMode:NO];

  const char *history = [[BlinkPaths historyFile] UTF8String];
  replxx_set_max_history_size(_replxx, MCP_MAX_HISTORY);
  replxx_history_load(_replxx, history);
  replxx_set_completion_callback(_replxx, completion, 0);
  replxx_set_hint_callback(_replxx, hints, 0);
  replxx_set_complete_on_empty(_replxx, 1);
  
  NSString *cmdline = nil;

  while ((cmdline = [self repl_input:"\x1b[1;32mblink\x1b[0m> "]) != nil) {
    if ([cmdline length] == 0) {
      continue;
    }

    replxx_history_add(_replxx, cmdline.UTF8String);
    replxx_history_save(_replxx, history);

    cmdline = [cmdline stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSArray *arr = splitCommandAndArgs(cmdline);
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
      break;
    } else if ([cmd isEqualToString:@"theme"]) {
      BOOL reload = [self _switchTheme: args];
      if (reload) {
        return 0;
      }
    } else if ([cmd isEqualToString:@"ssh-copy-id"]) {
      [self _runSSHCopyIDWithArgs:cmdline];
    } else {
      [self _runSystemCommandWithArgs:cmdline];
    }

    [self setTitle]; // Temporary, until the apps restore the right state.
    [_device setRawMode:NO];
  }
  [self out:"Bye!"];

  replxx_end(_replxx);
  _replxx = nil;
  return 0;
}

- (int)clear_main:(int)argc argv:(char **)argv
{
  blink_replxx_replace_streams(_replxx, _stream.in, _stream.out, _stream.err, &_device->win);
  replxx_clear_screen(_replxx);
  return 0;
}

- (int)showkey_main:(int)argc argv:(char **)argv
{
  BOOL rawMode = _device.rawMode;
  [_device setRawMode:YES];
  replxx_debug_dump_print_codes();
  [_device setRawMode:rawMode];
  return 0;
}

- (int)history_main:(int)argc argv:(char **)argv
{
  NSString *args = @"";
  if (argc == 2) {
    args = [NSString stringWithUTF8String:argv[1]];
  }
  NSInteger number = [args integerValue];
  if (number != 0) {
    NSString *history = [NSString stringWithContentsOfFile:[BlinkPaths historyFile]
                                                  encoding:NSUTF8StringEncoding error:nil];
    NSArray *lines = [history componentsSeparatedByString:@"\n"];
    if (!lines) {
      return 1;
    }
    lines = [lines filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self != ''"]];
    
    NSInteger len = lines.count;
    NSInteger start = 0;
    if (number > 0) {
      len = MIN(len, number);
    } else {
      start = MAX(len + number , 0);
    }
    
    for (NSInteger i = start; i < len; i++) {
      [self out:[NSString stringWithFormat:@"% 4li %@", i + 1, lines[i]].UTF8String];
    }
  } else if ([args isEqualToString:@"-c"]) {
    replxx_set_max_history_size(_replxx, 1);
    replxx_history_add(_replxx, @"".UTF8String);
    replxx_history_save(_replxx, [BlinkPaths historyFile].UTF8String);
    replxx_set_max_history_size(_replxx, MCP_MAX_HISTORY);
  } else {
    NSString *usage = [@[
                         @"history usage:",
                         @"history <number> - Show history",
                         @"history -c       - Clear history",
                         ] componentsJoinedByString:@"\n"];
    [self out:usage.UTF8String];
    return 1;
  }
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

- (NSString *)repl_input:(char *)prompt
{
  if (_stream.in == NULL) {
    return nil;
  }
  FILE * savedStdOut = stdout;
  FILE * savedStdErr = stderr;
  stdout = _stream.out;
  stderr = _stream.err;
  
  thread_stdout = _stream.out;
  thread_stdin = _stream.in;
  thread_stderr = _stream.err;

  char const* result = NULL;
  blink_replxx_replace_streams(_replxx, _stream.in, _stream.out, _stream.err, &_device->win);
  result = replxx_input(_replxx, prompt);
  stdout = savedStdOut;
  stderr = savedStdErr;
  
  if (( result == NULL ) && ( errno == EAGAIN ) ) {
    return nil;
  }
  
  return [NSString stringWithUTF8String:result];;
}

- (void)sigwinch
{
  if (_replxx) {
    replxx_window_changed(_replxx);
  }
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
  if (_replxx) {
    replxx_end(_replxx);
    _replxx = nil;
  }
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
