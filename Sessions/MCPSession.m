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
#include <libgen.h>
#include <sys/stat.h>

#include "linenoise.h"
#include "utf8.h"

#import "MCPSession.h"
#import "MoshSession.h"
#import "BKPubKey.h"
#import "SSHCopyIDSession.h"
#import "SSHSession.h"

// from ios_system:
#include "ios_system/ios_system.h"
extern int curl_static_main(int argc, char** argv);

#define MCP_MAX_LINE 4096

@implementation MCPSession {
  Session *_childSession;
}

// for file completion
// do recompute directoriesInPath only if $PATH has changed
static NSString* fullCommandPath = @"";
static NSArray *directoriesInPath;

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
      [pk.privateKey writeToFile:filename atomically:NO];
      filename = [filename stringByAppendingString:@".pub"];
      [pk.publicKey writeToFile:filename atomically:NO];
    }
  }
  if (argc < 1) {
    [self out:"Usage: ssh-save-id identity"];
  }
}

// This is a superset of all commands available. We check at runtime whether they are actually available (using ios_executable)
// todo: extract from commandsAsString()
char* commandList[] = {"ls", "touch", "rm", "cp", "ln", "link", "mv", "mkdir", "chown", "chgrp", "chflags", "chmod", "du", "df", "chksum", "sum", "stat", "readlink", "compress", "uncompress", "gzip", "gunzip", "tar", "printenv", "pwd", "uname", "date", "env", "id", "groups", "whoami", "uptime", "w", "cat", "wc", "grep", "egrep", "fgrep", "curl", "python", "lua", "luac", "amstex", "cslatex", "csplain", "eplain", "etex", "jadetex", "latex", "mex", "mllatex", "mltex", "pdflatex", "pdftex", "pdfcslatex", "pdfcstex", "pdfcsplain", "pdfetex", "pdfjadetex", "pdfmex", "pdfxmltex", "texsis", "utf8mex", "xmltex", "lualatex", "luatex", "texlua", "texluac", "dviluatex", "dvilualatex", "bibtex", "setenv", "unsetenv", "cd",
  NULL}; // must end with NULL pointer

// Commands defined outside of ios_executable:
char* localCommandList[] = {"help", "mosh", "ssh", "exit", "ssh-copy-id", "ssh-save-id", "config", "scp", "sftp", NULL}; // must end with NULL pointer

// Commands that don't take a file as argument:
char* commandsNoFileList[] = {"help", "mosh", "ssh", "exit", "ssh-copy-id", "ssh-save-id", "config", "setenv", "unsetenv", "printenv", "pwd", "uname", "date", "env", "id", "groups", "whoami", "uptime", "w", NULL};
// must end with NULL pointer

void completion(const char *command, linenoiseCompletions *lc) {
  // autocomplete command for lineNoise
  // Number of spaces:
  size_t numSpaces = 0;
  BOOL isDir;
  // the number of arguments is *at most* the number of spaces plus one
  char* str = command;
  while(*str) if (*str++ == ' ') ++numSpaces;
  int numCharsTyped = strlen(command);
  if (numSpaces == 0) {
    // No spaces. The user is typing a command
    int i = 0;
    // local commands (ssh, mosh...)
    while (localCommandList[i]) {
      if (strncmp(command, localCommandList[i], numCharsTyped) == 0) linenoiseAddCompletion(lc,localCommandList[i]);
      i++;
    }
    i = 0;
    // commands from ios_system (ls, cp...):
    while (commandList[i]) {
      if (ios_executable(commandList[i]))
          if (strncmp(command, commandList[i], numCharsTyped) == 0) linenoiseAddCompletion(lc,commandList[i]);
      i++;
    }
    // Commands in the PATH
    // Do we have an interpreter? (otherwise, there's no point)
    if (ios_executable("python") || ios_executable("lua")) {
      NSString* checkingPath = [NSString stringWithCString:getenv("PATH") encoding:NSASCIIStringEncoding];
      if (! [fullCommandPath isEqualToString:checkingPath]) {
        fullCommandPath = checkingPath;
        directoriesInPath = [fullCommandPath componentsSeparatedByString:@":"];
      }
      char* newCommand = (char*) malloc(PATH_MAX * sizeof(char));
      for (NSString* path in directoriesInPath) {
        // If the path component doesn't exist, no point in continuing:
        if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir]) continue;
        if (!isDir) continue; // same in the (unlikely) event the path component is not a directory
        NSArray* filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:Nil];
        for (NSString *fileName in filenames) {
          if (strncmp(command, [fileName UTF8String], strlen(command)) == 0) {
            linenoiseAddCompletion(lc,[fileName UTF8String]);
          }
        }
      }
      free(newCommand);
    }
  } else {
    // the user is typing an argument.
    // Is this one the commands that want a file as an argument?
    int i = 0;
    while (commandsNoFileList[i]) {
      if (strncmp(command, commandsNoFileList[i], strlen(commandsNoFileList[i])) == 0) return;
      i++;
    }
    // Last position of space in the command:
    char* argument = strrchr (command, ' ') + 1;
    // which directory?
    char *directory, *file;
    int filePosition;
    if (argument[strlen(argument) - 1] == '/') { // ends with a '/'
      directory = argument;
      file = NULL;
      filePosition = strlen(command);
    } else {
      directory = dirname(argument); // will be "." if empty
      if (strlen(argument) > 0) {
        file = basename(argument);
        filePosition = strlen(command) - strlen(file);
      } else {
        file = NULL;
        filePosition = strlen(command);
      }
    }
    NSString* dirString = [NSString stringWithUTF8String:directory];
    dirString = [dirString stringByExpandingTildeInPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:dirString isDirectory:&isDir]
        && isDir) {
      NSArray* filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dirString error:Nil];
      char* newCommand = (char*) malloc((filePosition + NAME_MAX) * sizeof(char));
      for (NSString *fileName in filenames) {
        if ((!file) || strncmp(file, [fileName UTF8String], strlen(file)) == 0) {
          newCommand = strcpy(newCommand, command);
          sprintf(newCommand + filePosition, "%s", [fileName UTF8String]);
          linenoiseAddCompletion(lc,newCommand);
        }
      }
      free(newCommand);
    }
  }
}

- (int)main:(int)argc argv:(char **)argv
{
  char *line;
  argc = 0;
  argv = nil;

  NSString *docsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
  NSString *filePath = [docsPath stringByAppendingPathComponent:@"history.txt"];
  initializeEnvironment();
  replaceCommand(@"curl", curl_static_main, true);
  [[NSFileManager defaultManager] changeCurrentDirectoryPath:docsPath];

  const char *history = [filePath UTF8String];

  [self.stream.control setRawMode:NO];

  linenoiseSetEncodingFunctions(linenoiseUtf8PrevCharLen,
                                linenoiseUtf8NextCharLen,
                                linenoiseUtf8ReadCode);

  linenoiseHistoryLoad(history);
  linenoiseSetCompletionCallback(completion);

  while ((line = [self linenoise:"blink> "]) != nil) {
    if (line[0] != '\0' && line[0] != '/') {
      linenoiseHistoryAdd(line);
      linenoiseHistorySave(history);

      NSString *cmdline = [[NSString alloc] initWithFormat:@"%s", line];
      // separate into arguments, parse and execute:
      NSArray *listArgvMaybeEmpty = [cmdline componentsSeparatedByString:@" "];
      // Remove empty strings (extra spaces)
      NSMutableArray* listArgv = [[listArgvMaybeEmpty filteredArrayUsingPredicate:
                                   [NSPredicate predicateWithFormat:@"length > 0"]] mutableCopy];
      [self.delegate indexCommand:listArgv];
      
      NSString *cmd = listArgv[0];
      
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
        // Is it one of the shell commands?
        // Re-evalute column number before each command
        char columnCountString[10];
        sprintf(columnCountString, "%i", self.stream.control.terminal.columnCount);
        setenv("COLUMNS", columnCountString, 1); // force rewrite of value
        // Redirect all output to console:
        FILE* saved_out = stdout;
        FILE* saved_err = stderr;
        stdin = _stream.in;
        stdout = _stream.out;
        stderr = stdout;
        // Experimental development
        ios_system(cmdline.UTF8String);
        stdout = saved_out;
        stderr = saved_err;
        stdin = _stream.in;
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
  _childSession = [[SSHCopyIDSession alloc] initWithStream:_stream];
  [_childSession executeAttachedWithArgs:args];
  _childSession = nil;
}

- (void)runMoshWithArgs:(NSString *)args
{
  
  _childSession = [[MoshSession alloc] initWithStream:_stream];
  [_childSession executeAttachedWithArgs:args];
  
  _childSession = nil;
}

- (void)runSSHWithArgs:(NSString *)args
{
  _childSession = [[SSHSession alloc] initWithStream:_stream];
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
    @"  two fingers swipe down or cmd+w: Close shell.",
    @"  one finger swipe left/right or cmd+shift+[/]: Switch between shells.",
    @"  cmd+alt+N: Switch to shell number N.",
    @"  cmd+o: Switch to other screen (Airplay mode).",
    @"  cmd+shift+o: Move current shell to other screen (Airplay mode).",
    @"  cmd+,: Open config.",
    @"  pinch: Change font size.",
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

@end
