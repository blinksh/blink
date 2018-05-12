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

#include "linenoise.h"
#include "utf8.h"

#import "MCPSession.h"
#import "MoshSession.h"
#import "BKPubKey.h"
#import "SSHCopyIDSession.h"
#import "SSHSession.h"
#import "BKHosts.h"
#import "BKTheme.h"
#import "BKDefaults.h"
#import "MusicManager.h"
#import "BKUserConfigurationManager.h"

// from ios_system:
#include "ios_system/ios_system.h"

#define MCP_MAX_LINE 4096
#define MCP_MAX_HISTORY 1000

NSArray *__commandList;
NSDictionary *__commandHints;

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
    return @[@"help"];
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

char* hints(const char * line, int *color, int *bold)
{
  NSString *hint = nil;
  NSString *prefix = [NSString stringWithUTF8String:line];
  if (prefix.length == 0) {
    return NULL;
  }
  
  NSString *cmd = [commandsByPrefix(prefix) firstObject];
  if (cmd) {
    hint = __commandHints[cmd];
  } else {
    NSArray *cmdAndArgs = splitCommandAndArgs(prefix);
    cmd = cmdAndArgs[0];
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
    *color = 33;
    return (char *)[hint substringFromIndex: prefix.length].UTF8String;
  }
  
  return NULL;
}


@implementation MCPSession {
  Session *_childSession;
}

@dynamic sessionParameters;

- (void)setTitle
{
  fprintf(_stream.control.termout, "\033]0;blink\007");
}

- (void)ssh_save_id:(int)argc argv:(char **)argv {
  // Save specific IDs to ~/Documents/.ssh/...
  // Useful for other Unix tools
  BKPubKey *pk;
  // Path = getenv(SSH_HOME) or ~/Documents
  NSString* keypath;
  if (getenv("SSH_HOME")) keypath = [NSString stringWithUTF8String:getenv("SSH_HOME")];
  else keypath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
  keypath = [keypath stringByAppendingPathComponent:@".ssh"];
  
  for (int i = 1; i < argc; i++) {
    if ((pk = [BKPubKey withID:[NSString stringWithUTF8String:argv[i]]]) != nil) {
      NSString* filename = [keypath stringByAppendingPathComponent:[NSString stringWithUTF8String:argv[i]]];
      // save private key:
      [pk.privateKey writeToFile:filename atomically:NO encoding:NSUnicodeStringEncoding error:nil];
      filename = [filename stringByAppendingString:@".pub"];
      [pk.publicKey writeToFile:filename atomically:NO encoding:NSUnicodeStringEncoding error:nil];
    }
  }
  if (argc < 1) {
    [self out:"Usage: ssh-save-id identity"];
  }
}

// List of all commands available, sorted alphabetically:
// Extracted at runtime from ios_system() plus blinkshell commands:
NSArray* commandList;
// Commands that don't take a file as argument (uname, ssh, mosh...):
NSArray* commandsNoFile;

void initializeCommandListForCompletion() {
  // set up the list of commands for auto-complete:
  // list of commands from ios_system:
  NSMutableArray* combinedCommands = [commandsAsArray() mutableCopy];
  // add commands from Blinkshell:
  [combinedCommands addObjectsFromArray:@[@"help",@"mosh",@"ssh",@"exit",@"ssh-copy-id",@"ssh-save-id",@"config"]];
  // sort alphabetically:
  commandList = [combinedCommands sortedArrayUsingSelector:@selector(compare:)];
  commandsNoFile = @[@"help", @"mosh", @"ssh", @"exit", @"ssh-copy-id", @"ssh-save-id", @"config", @"setenv", @"unsetenv", @"printenv", @"pwd", @"uname", @"date", @"env", @"id", @"groups", @"whoami", @"uptime", @"w"];
}

void completion(const char *command, linenoiseCompletions *lc) {
  // autocomplete command for lineNoise
  BOOL isDir;
  NSString* commandString = [NSString stringWithUTF8String:command];
  if ([commandString rangeOfString:@" "].location == NSNotFound) {
    // No spaces. The user is typing a command
    // check for pre-defined commands:
    for (NSString* existingCommand in commandList) {
      if ([existingCommand hasPrefix:commandString]) linenoiseAddCompletion(lc, existingCommand.UTF8String);
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
          if ([fileName hasPrefix:commandString]) linenoiseAddCompletion(lc,[fileName UTF8String]);
        }
      }
    }
  } else {
    // the user is typing an argument.
    // Is this one the commands that want a file as an argument?
    NSArray* commandArray = [commandString componentsSeparatedByString:@" "];
    if ([commandsNoFile containsObject:commandArray[0]]) return;

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
      if (directory.length == 0) directory = @".";
      file = [argument lastPathComponent];
    }
    directory = [directory stringByExpandingTildeInPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:directory isDirectory:&isDir] && isDir) {
      NSArray* filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:Nil];
      for (NSString *fileName in filenames) {
        if ((file.length == 0) || [fileName hasPrefix:file]) {
          NSString* addition = [fileName substringFromIndex:[file length]];
          NSString * newCommand = [commandString stringByAppendingString:addition];
          linenoiseAddCompletion(lc,[newCommand UTF8String]);
        }
      }
    }
  }
}

+ (void)initialize
{
  __commandList = [
    @[@"help", @"mosh", @"ssh", @"exit", @"ssh-copy-id", @"config", @"theme", @"music", @"history", @"clear"]
        sortedArrayUsingSelector:@selector(compare:)
  ];
  
  __commandHints =
  @{
    @"help": @"help - Prints all commands. 🧐 ",
    @"mosh": @"mosh - Runs mosh client. 🦄",
    @"ssh": @"ssh - Runs ssh client. 🐌",
    @"config": @"config - Add keys, hosts, themes, etc... ⚙️ ",
    @"theme": @"theme - Choose a theme 💅",
    @"music": @"music - Control music player 🎧",
    @"history": @"history - Use -c option to clear history. 🙈 ",
    @"clear": @"clear - Clear screen. 🙊",
    @"exit": @"exit - Exits current session. 👋"
  };
}

- (NSString *)_historyFilePath
{
  NSString *docsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
  return [docsPath stringByAppendingPathComponent:@"history.txt"];
}

- (int)main:(int)argc argv:(char **)argv
{
  if ([@"mosh" isEqualToString:self.sessionParameters.childSessionType]) {
    _childSession = [[MoshSession alloc] initWithStream:_stream
                                           andParametes:self.sessionParameters.childSessionParameters];
    [_childSession executeAttachedWithArgs:@""];
    _childSession = nil;
  }
  
  char *line;
  argc = 0;
  argv = nil;

  NSString *docsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
  initializeEnvironment(); // initialize environment variables for iOS system
  replaceCommand(@"curl", @"curl_static_main", true); // replace curl in ios_system with our own, accessing Blink keys.
  initializeCommandListForCompletion();
  [[NSFileManager defaultManager] changeCurrentDirectoryPath:docsPath];

  [self.stream.control setRawMode:NO];

  linenoiseSetEncodingFunctions(linenoiseUtf8PrevCharLen,
                                linenoiseUtf8NextCharLen,
                                linenoiseUtf8ReadCode);

  const char *history = [[self _historyFilePath] UTF8String];
  linenoiseHistorySetMaxLen(MCP_MAX_HISTORY);
  linenoiseHistoryLoad(history);
  linenoiseSetCompletionCallback(completion);
  linenoiseSetHintsCallback(hints);

  while ((line = [self linenoise:"blink> "]) != nil) {
    if (line[0] != '\0' && line[0] != '/') {
      linenoiseHistoryAdd(line);
      linenoiseHistorySave(history);

      NSString *cmdline = [[NSString alloc] initWithFormat:@"%s", line];
      free(line);

      cmdline = [cmdline stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
      NSArray *arr = splitCommandAndArgs(cmdline);
      NSString *cmd = arr[0];
      NSString *args = arr[1];

      if ([cmd isEqualToString:@"help"]) {
        [self _showHelp];
      } else if ([cmd isEqualToString:@"mosh"]) {
        // At some point the parser will be in the JS, and the call will, through JSON, will include what is needed.
        // Probably passing a Server struct of some type.

        [self _runMoshWithArgs:cmdline];
      } else if ([cmd isEqualToString:@"ssh"]) {
        // At some point the parser will be in the JS, and the call will, through JSON, will include what is needed.
        // Probably passing a Server struct of some type.
        [self _runSSHWithArgs:cmdline];
      } else if ([cmd isEqualToString:@"exit"]) {
        break;
      } else if ([cmd isEqualToString:@"theme"]) {
        BOOL reload = [self _switchTheme: args];
        if (reload) {
          return 0;
        }
      } else if ([cmd isEqualToString:@"music"]) {
        [self _controlMusic: args];
      } else if ([cmd isEqualToString:@"ssh-copy-id"]) {
        [self _runSSHCopyIDWithArgs:cmdline];
      } else if ([cmd isEqualToString:@"config"]) {
        [self _showConfig];
      } else if ([cmd isEqualToString:@"history"]) {
        [self _execHistoryWithArgs: args];
      } else if ([cmd isEqualToString:@"clear"]) {
        [self _execClear];
      } else {
        // Is it one of the shell commands?
        // Re-evalute column number before each command
        char columnCountString[10];
        sprintf(columnCountString, "%i", self.stream.sz->ws_col);
        setenv("COLUMNS", columnCountString, 1); // force rewrite of value
        // Redirect all output to console:
        FILE* saved_out = stdout;
        FILE* saved_err = stderr;
        stdin = _stream.in;
        stdout = _stream.out;
        stderr = stdout;
        ios_system(cmdline.UTF8String);
        // get all output back:
        stdout = saved_out;
        stderr = saved_err;
        stdin = _stream.in;
      }
    }

    [self setTitle]; // Temporary, until the apps restore the right state.
    [self.stream.control setRawMode:NO];
  }

  [self out:"Bye!"];

  return 0;
}

- (void)_execClear
{
  [self.stream.control write:@"\xC"];
}

- (void)_execHistoryWithArgs:(NSString *)args
{
  NSInteger number = [args integerValue];
  if (number != 0) {
    NSString *history = [NSString stringWithContentsOfFile:[self _historyFilePath]
                                                  encoding:NSUTF8StringEncoding error:nil];
    NSArray *lines = [history componentsSeparatedByString:@"\n"];
    if (!lines) {
      return;
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
    linenoiseHistorySetMaxLen(1);
    linenoiseHistoryAdd(@"".UTF8String);
    linenoiseHistorySave([self _historyFilePath].UTF8String);
    linenoiseHistorySetMaxLen(MCP_MAX_HISTORY);
  } else {
    NSString *usage = [@[
                         @"history usage:",
                         @"history <number> - Show history",
                         @"history -c       - Clear history",
                        ] componentsJoinedByString:@"\r\n"];
    [self out:usage.UTF8String];
  }
}

- (void)_showConfig
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [[UIApplication sharedApplication]
     sendAction:NSSelectorFromString(@"showConfig:") to:nil from:nil forEvent:nil];
  });
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
      [_stream.control reload];
    });
    return YES;
  }
}

- (void)_controlMusic:(NSString *)input
{
  __block NSString *output = nil;
  dispatch_sync(dispatch_get_main_queue(), ^{
    output = [[MusicManager shared] runWithInput:input];
  });

  if (output) {
    [self out:output.UTF8String];
  }
}

- (void)_runSSHCopyIDWithArgs:(NSString *)args
{
  self.sessionParameters.childSessionParameters = nil;
  _childSession = [[SSHCopyIDSession alloc] initWithStream:_stream andParametes:self.sessionParameters.childSessionParameters];
  self.sessionParameters.childSessionType = @"sshcopyid";
  [_childSession executeAttachedWithArgs:args];
  _childSession = nil;
}

- (void)_runMoshWithArgs:(NSString *)args
{
  [self.delegate indexCommand:args];
  self.sessionParameters.childSessionParameters = [[MoshParameters alloc] init];
  self.sessionParameters.childSessionType = @"mosh";
  _childSession = [[MoshSession alloc] initWithStream:_stream andParametes:self.sessionParameters.childSessionParameters];
  [_childSession executeAttachedWithArgs:args];
  
  _childSession = nil;
}

- (void)_runSSHWithArgs:(NSString *)args
{
  self.sessionParameters.childSessionParameters = nil;
  [self.delegate indexCommand:args];
  _childSession = [[SSHSession alloc] initWithStream:_stream andParametes:self.sessionParameters.childSessionParameters];
  self.sessionParameters.childSessionType = @"ssh";
  [_childSession executeAttachedWithArgs:args];
  _childSession = nil;
}

- (NSString *)_shortVersionString
{
  NSString *compileDate = [NSString stringWithUTF8String:__DATE__];

  NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
  NSString *appDisplayName = [infoDictionary objectForKey:@"CFBundleName"];
  NSString *majorVersion = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
  NSString *minorVersion = [infoDictionary objectForKey:@"CFBundleVersion"];

  return [NSString stringWithFormat:@"%@: v%@.%@. %@",
                                    appDisplayName, majorVersion, minorVersion, compileDate];
}

- (void)_showHelp
{
  UIKeyModifierFlags flags = [BKUserConfigurationManager shortCutModifierFlags];
  NSString *flagsStr = [BKUserConfigurationManager UIKeyModifiersToString:flags];
  NSString *help = [@[
    @"",
    [self _shortVersionString],
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
    [NSString stringWithFormat:@"  one finger swipe left/right or %@+[]: Switch between shells.", flagsStr],
    [NSString stringWithFormat:@"  %@+N: Switch to shell number N.", flagsStr],
    [NSString stringWithFormat:@"  %@+w: Close shell.", flagsStr],
    [NSString stringWithFormat:@"  %@+o: Switch to other screen (Airplay mode).", flagsStr],
    [NSString stringWithFormat:@"  %@+O: Move current shell to other screen (Airplay mode).", flagsStr],
    [NSString stringWithFormat:@"  %@+,: Open config.", flagsStr],
    [NSString stringWithFormat:@"  %@+m: Toggle music controls. (Control with %@+npsrb).", flagsStr, flagsStr],
    @"  pinch: Change font size.",
    @"  selection mode: VIM users: hjklwboyp, EMACS: ⌃-fbnpx, OTHER: arrows and fingers",
    @""
  ] componentsJoinedByString:@"\n"];

  [self out:help.UTF8String];
}

- (void)out:(const char *)str
{
  fprintf(_stream.out, "%s\n", str);
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
  [_childSession suspend];
}

- (BOOL)handleControl:(NSString *)control
{
  if (_childSession) {
    return NO;
  }

  if ([control isEqualToString:@"c"] || [control isEqualToString:@"d"]) {
    ios_kill();
    return YES;
  }

  return NO;
}
@end
