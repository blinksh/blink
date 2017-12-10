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
#include <sys/stat.h>

#include "linenoise.h"
#include "utf8.h"

#import "MCPSession.h"
#import "MoshSession.h"
#import "BKPubKey.h"
#import "SSHCopyIDSession.h"
#import "SSHSession.h"

extern int ios_system(char* cmd);
extern int curl_static_main(int argc, char** argv);

#define MCP_MAX_LINE 4096

@implementation MCPSession {
  Session *_childSession;
}

static NSString *docsPath;
static NSString *filePath;
static NSString* previousDirectory;

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

- (char **) makeargs:(NSMutableArray*) listArgv argc:(int*) argc
{
  // Assumes the command line has been separated into arguments, parse the arguments if needed
  // does some conversions (~ --> home directory, for example, plus environment variables)
  // Most of the heavy parsing is done in ios_system.m (check if command is a file, etc)
  // If the command is "scp" or "sftp", do not replace "~" on remote file locations, but
  // edit the arguments (we simulate scp and sftp by calling "curl scp://remotefile")
  if ([listArgv count] == 0) { *argc = 0; return NULL; }
  NSString* cmd = [listArgv objectAtIndex:0];
  // Re-concatenate arguments with quotes (' and ")
  for (unsigned i = 0; i < [listArgv count]; i++) {
    NSString *argument = [listArgv objectAtIndex:i];
    if ([argument hasPrefix:@"'"] && !([argument hasSuffix:@"'"])) {
      do {
        // add a space
        [listArgv replaceObjectAtIndex:i withObject:[[listArgv objectAtIndex:i] stringByAppendingString:@" "]];
        // add all arguments that are part of the argument:
        [listArgv replaceObjectAtIndex:i withObject:[[listArgv objectAtIndex:i] stringByAppendingString:[listArgv objectAtIndex:(i+1)]]];
        [listArgv removeObjectAtIndex:(i+1)];
      } while (![[listArgv objectAtIndex:(i+1)] hasSuffix:@"'"]);
      // including the last one
      [listArgv replaceObjectAtIndex:i withObject:[[listArgv objectAtIndex:i] stringByAppendingString:@" "]];
      [listArgv replaceObjectAtIndex:i withObject:[[listArgv objectAtIndex:i] stringByAppendingString:[listArgv objectAtIndex:(i+1)]]];
      [listArgv removeObjectAtIndex:(i+1)];
      argument = [listArgv objectAtIndex:i];
      argument = [argument stringByReplacingOccurrencesOfString:@"'" withString:@""];
      [listArgv replaceObjectAtIndex:i withObject:argument];
    }
    // TODO: "
  }
  *argc = [listArgv count];
  char** argv = (char **)malloc((*argc + 1) * sizeof(char*));
  NSString *fileName = NULL;
  int mustAddMinusTPosition = -1;
  // 1) convert command line to argc / argv
  // 1a) split into elements
  for (unsigned i = 0; i < [listArgv count]; i++)
  {
    // Operations on individual arguments
    NSString *argument = [listArgv objectAtIndex:i];
    // 1b) expand environment variables, + "~" (not wildcards ? and *)
    while ([argument containsString:@"$"]) {
      // It has environment variables inside. Work on them one by one.
      // position of first "$" sign:
      NSRange r1 = [argument rangeOfString:@"$"];
      // position of first "/" after this $ sign:
      NSRange r2 = [argument rangeOfString:@"/" options:NULL range:NSMakeRange(r1.location + r1.length, [argument length] - r1.location - r1.length)];
      // position of first ":" after this $ sign:
      NSRange r3 = [argument rangeOfString:@":" options:NULL range:NSMakeRange(r1.location + r1.length, [argument length] - r1.location - r1.length)];
      if ((r2.location == NSNotFound) && (r3.location == NSNotFound)) r2.location = [argument length];
      else if ((r2.location == NSNotFound) || (r3.location < r2.location)) r2.location = r3.location;

      NSRange  rSub = NSMakeRange(r1.location + r1.length, r2.location - r1.location - r1.length);
      NSString *variable_string = [argument substringWithRange:rSub];
      const char* variable = getenv([variable_string UTF8String]);
      if (variable) {
        // Okay, so this one exists.
        NSString* replacement_string = [NSString stringWithCString:variable encoding:NSASCIIStringEncoding];
        variable_string = [[NSString stringWithCString:"$" encoding:NSASCIIStringEncoding] stringByAppendingString:variable_string];
        argument = [argument stringByReplacingOccurrencesOfString:variable_string withString:replacement_string];
      }
    }
    // Bash spec: only convert "~" if: at the beginning of argument, after a ":" or the first "="
    // ("=" scenario for export, but we use setenv, so no "=").
    // Only 1 possibility: "~" (same as $HOME)
    // If the command is scp or sftp, do not apply this on remote directories
    if (([cmd isEqualToString:@"scp"] || [cmd isEqualToString:@"sftp"]) && (i >= 1)) {
      if ([argument containsString:@":"]) {
        // remote host: [user@]host:[/][~]filepath --> scp://[user@]host/
        // if filepath relative, add ~
        NSRange r1 = [argument rangeOfString:@":"];
        NSRange  rSub = NSMakeRange(0, r1.location);
        NSString* userAndHost = [argument substringWithRange:rSub];
        rSub = NSMakeRange(r1.location + 1, [argument length] - r1.location - 1);
        NSString* fileLocation = [argument substringWithRange:rSub];
        if(![fileLocation hasPrefix:@"/"]) {
          // relative path
          if([fileLocation hasPrefix:@"~"]) {
            fileLocation = [[NSString stringWithCString:"/" encoding:NSASCIIStringEncoding]  stringByAppendingString:fileLocation];
          } else {
            fileLocation = [[NSString stringWithCString:"/~/" encoding:NSASCIIStringEncoding]  stringByAppendingString:fileLocation];
          }
          if (![fileLocation hasSuffix:@"/"]) fileName = fileLocation.lastPathComponent;
          else fileName = @"result.txt";
        }
        NSString *prefix = [cmd stringByAppendingString:[NSString stringWithCString:"://" encoding:NSASCIIStringEncoding]];
        argument = [[prefix stringByAppendingString:userAndHost] stringByAppendingString:fileLocation];
        // avoid ~ conversion:
        argv[i] = [argument UTF8String];
        continue;
      }
      if (![argument hasPrefix:@"-"]) {
        // Not beginning with "-", not containing ":", must be a local filename
        // if it's ".", replace with -O
        // if it's a directory, add name of file from previous argument at the end.
        if (!fileName) {
          // local file before remote file: upload
          mustAddMinusTPosition = i;
        } else if ([argument isEqualToString:@"."]) argument = @"-O";
        else if ([argument hasSuffix:@"/"]) argument = [argument stringByAppendingString:fileName];
        else {
          BOOL isDir;
          if ([[NSFileManager defaultManager] fileExistsAtPath:argument isDirectory:&isDir]) {
            if (isDir)
              argument = [argument stringByAppendingString:fileName];
          }
        }
      }
    }
    // Tilde conversion:
    if([argument hasPrefix:@"~"]) {
      // So it begins with "~"
      argument = [argument stringByExpandingTildeInPath];
      if ([argument hasPrefix:@"~:"]) {
        NSString* test_string = @"~";
        NSString* replacement_string = [NSString stringWithCString:(getenv("HOME")) encoding:NSASCIIStringEncoding];
        argument = [argument stringByReplacingOccurrencesOfString:test_string withString:replacement_string options:NULL range:NSMakeRange(0, 1)];
      }
    }
    // Also convert ":~something" in PATH style variables
    // We don't use these yet, but we could.
    if ([argument containsString:@":~"]) {
      // Only 1 possibility: ":~" (same as $HOME)
      if (getenv("HOME")) {
        if ([argument containsString:@":~/"]) {
          NSString* test_string = @":~/";
          NSString* replacement_string = [[NSString stringWithCString:":" encoding:NSASCIIStringEncoding] stringByAppendingString:[NSString stringWithCString:(getenv("HOME")) encoding:NSASCIIStringEncoding]];
          replacement_string = [replacement_string stringByAppendingString:[NSString stringWithCString:"/" encoding:NSASCIIStringEncoding]];
          argument = [argument stringByReplacingOccurrencesOfString:test_string withString:replacement_string];
        } else if ([argument hasSuffix:@":~"]) {
          NSString* test_string = @":~";
          NSString* replacement_string = [[NSString stringWithCString:":" encoding:NSASCIIStringEncoding] stringByAppendingString:[NSString stringWithCString:(getenv("HOME")) encoding:NSASCIIStringEncoding]];
          argument = [argument stringByReplacingOccurrencesOfString:test_string withString:replacement_string options:NULL range:NSMakeRange([argument length] - 2, 2)];
        } else if ([argument hasSuffix:@":"]) {
          NSString* test_string = @":";
          NSString* replacement_string = [[NSString stringWithCString:":" encoding:NSASCIIStringEncoding] stringByAppendingString:[NSString stringWithCString:(getenv("HOME")) encoding:NSASCIIStringEncoding]];
          argument = [argument stringByReplacingOccurrencesOfString:test_string withString:replacement_string options:NULL range:NSMakeRange([argument length] - 2, 2)];
        }
      }
    }
    if (([cmd isEqualToString:@"scp"] || [cmd isEqualToString:@"sftp"]) && (i == 0))
      argv[i] = [@"curl" UTF8String];
    else
      argv[i] = [argument UTF8String];
  }
  if (mustAddMinusTPosition > 0) {
    // For scp uploads
    // Need to add parameter "-T" before parameter number i.
    *argc += 1;
    argv = (char **)realloc(argv, (*argc + 1) * sizeof(char*));
    for (int i = *argc; i > mustAddMinusTPosition; i--)
      argv[i - 1] = strdup(argv[i - 2]);
    argv[mustAddMinusTPosition] = [@"-T" UTF8String];
  }
  
  argv[*argc] = NULL;
  return argv;
}

- (bool)executeCommand:(int)argc argv:(char **)argv {
  // Re-evalute column number before each command
  char columnCountString[10];
  sprintf(columnCountString, "%i", self.stream.control.terminal.columnCount);
  setenv("COLUMNS", columnCountString, 1); // force rewrite of value

  if (argc == 0) return false;
  NSString *cmd = [NSString stringWithCString:argv[0] encoding:NSASCIIStringEncoding];
  
  if ([cmd isEqualToString:@"help"]) {
    [self showHelp];
  } else if ([cmd isEqualToString:@"mosh"]) {
    // At some point the parser will be in the JS, and the call will, through JSON, will include what is needed.
    // Probably passing a Server struct of some type.
    
    [self runMoshWithArgs:argc argv:argv];
  } else if ([cmd isEqualToString:@"ssh"]) {
    // At some point the parser will be in the JS, and the call will, through JSON, will include what is needed.
    // Probably passing a Server struct of some type.
    [self runSSHWithArgs:argc argv:argv];
  } else if ([cmd isEqualToString:@"exit"]) {
    return true;
  } else if ([cmd isEqualToString:@"ssh-copy-id"]) {
    [self runSSHCopyIDWithArgs:argc argv:argv];
  } else if ([cmd isEqualToString:@"ssh-save-id"]) {
    [self ssh_save_id:argc argv:argv];
  } else if ([cmd isEqualToString:@"config"]) {
    [self showConfig];
  } else if  ([cmd isEqualToString:@"setenv"]) {
    // Builtin. commands that have to be inside the "shell"
    // setenv VARIABLE value
    setenv(argv[1], argv[2], 1);
  } else if  ([cmd isEqualToString:@"cd"]) {
    NSString* currentDir = [[NSFileManager defaultManager] currentDirectoryPath];
    if (argc > 1) {
      NSString* newDir = @(argv[1]);
      if (strcmp(argv[1], "-") == 0) {
        // "cd -" option to pop back to previous directory
        newDir = previousDirectory;
      }
      BOOL isDir;
      if ([[NSFileManager defaultManager] fileExistsAtPath:newDir isDirectory:&isDir]) {
        if (isDir) {
          [[NSFileManager defaultManager] changeCurrentDirectoryPath:newDir];
          previousDirectory = currentDir;
        }
        else  fprintf(_stream.out, "cd: %s: not a directory\n", [newDir UTF8String]);
      } else {
        fprintf(_stream.out, "cd: %s: no such file or directory\n", [newDir UTF8String]);
      }
    } else { // [cd] Help, I'm lost, bring me back home
      previousDirectory = [[NSFileManager defaultManager] currentDirectoryPath];
      [[NSFileManager defaultManager] changeCurrentDirectoryPath:docsPath];
    }
    // Higher level commands, not from system: curl, tar, scp, sftp
  } else if ([cmd isEqualToString:@"preview"]) {
    // Opening in helper apps (iBooks, in this example)
    NSString* fileLocation = @(argv[1]);
    if (! [fileLocation hasPrefix:@"/"]) {
      // relative path. The most likely.
      fileLocation = [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:fileLocation];
    }
    fileLocation = [@"itms-books://" stringByAppendingString:fileLocation];
    NSURL *actionURL = [NSURL URLWithString:[fileLocation                                               stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLFragmentAllowedCharacterSet]]];
    dispatch_async(dispatch_get_main_queue(), ^{
      [[UIApplication sharedApplication] openURL:actionURL];
    });
  } else {
    // Redirect all output to console:
    stdin = _stream.control.termin;
    stdout = _stream.control.termout;
    stderr = _stream.control.termout;
    // curl gets a special treatment because it uses the keys stored internally by Blink
    if (strcmp(argv[0], "curl") == 0) {
      curl_static_main(argc, argv); // this is the static library version of curl
      // curl_main still exists, will be called by python and lua, for example.
    } else {
      // Not one of our internal commands, so we pass it to ios_system:
      // Re-concatenate everything into a command line
      // We can't take the original command line because we (possibly) changed it.
      int cmdSize = 0;
      for (int i = 0; i < argc; i++) cmdSize += strlen(argv[i] + 3); // at most +3 characters per arg
      char* cmd = (char*) malloc(cmdSize * sizeof(char));
      strcpy(cmd, argv[0]);
      for (int i = 1; i < argc; i++) {
        strcat(cmd, " ");
        // if arguments contain spaces, enclose in quotes:
        if (strstr(argv[i], " ")) strcat(cmd, "'");
        strcat(cmd, argv[i]);
        if (strstr(argv[i], " ")) strcat(cmd, "'");
      }
      ios_system(cmd);
    }
  }
  return false; 
}

- (BOOL)executeCommand:(NSMutableArray*) listArgv {
  int argc;
  char** argv;
  if ([listArgv count] == 0) return false;
  NSString* line = listArgv[0];
  for (int i = 1; i < [listArgv count]; i++) {
    line = [line stringByAppendingString:@" "];
    line = [line stringByAppendingString:listArgv[i]];
  }
  linenoiseHistoryAdd(line.UTF8String);
  linenoiseHistorySave(filePath.UTF8String);
  [self.delegate indexCommand:line];
  argv = [self makeargs:listArgv argc:&argc];
  bool mustExit = [self executeCommand:argc argv:argv];
  free(argv);
  return mustExit;
}

- (int)main:(int)argc argv:(char **)argv
{
  char *line;
  argc = 0;
  argv = nil;

  // Initialize paths for application files, including history.txt and keys
  docsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
  NSString *libPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
  filePath = [docsPath stringByAppendingPathComponent:@"history.txt"];
  
  // Where the executables are stored:
  NSString *binPath = [libPath stringByAppendingPathComponent:@"bin"];
  // Add content of old PATH to this. PATH *is* defined in iOS, surprising as it may be.
  // I'm not going to erase it, so we just add ourselves.
  binPath = [[binPath stringByAppendingString:@":"] stringByAppendingString:[NSString stringWithCString:getenv("PATH") encoding:NSASCIIStringEncoding]];
  
  // We can't write in $HOME so we need to set the position of config files:
  setenv("SSH_HOME", docsPath.UTF8String, 0);  // SSH keys in ~/Documents/.ssh/
  setenv("CURL_HOME", docsPath.UTF8String, 0); // CURL config in ~/Documents/
  setenv("PYTHONHOME", libPath.UTF8String, 0);  // Python scripts in ~/Library/lib/python2.7/
  setenv("SSL_CERT_FILE", [docsPath stringByAppendingPathComponent:@"cacert.pem"].UTF8String, 0); // SLL cacert.pem in ~/Documents/cacert.pem
  // hg config file in ~/Documents/.hgrc
  setenv("HGRCPATH", [docsPath stringByAppendingPathComponent:@".hgrc"].UTF8String, 0);
  setenv("PATH", binPath.UTF8String, 1); // 1 = override existing value
  // iOS already defines "HOME" as the home dir of the application

  [[NSFileManager defaultManager] changeCurrentDirectoryPath:docsPath];
  previousDirectory = docsPath;

  const char *history = [filePath UTF8String];

  [self.stream.control setRawMode:NO];

  linenoiseSetEncodingFunctions(linenoiseUtf8PrevCharLen,
                                linenoiseUtf8NextCharLen,
                                linenoiseUtf8ReadCode);

  linenoiseHistoryLoad(history);

  while ((line = [self linenoise:"blink> "]) != nil) {
    if (line[0] != '\0' /* && line[0] != '/' */) {
      NSString *cmdline = [[NSString alloc] initWithFormat:@"%s", line];
      // separate into arguments, parse and execute:
      NSArray *listArgvMaybeEmpty = [cmdline componentsSeparatedByString:@" "];
      // Remove empty strings (extra spaces)
      NSMutableArray* listArgv = [[listArgvMaybeEmpty filteredArrayUsingPredicate:
                                   [NSPredicate predicateWithFormat:@"length > 0"]] mutableCopy];
      BOOL mustExit = [self executeCommand:listArgv];
      if (mustExit) break;
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

- (void)runSSHCopyIDWithArgs:(int)argc argv:(char **)argv;
{
  _childSession = [[SSHCopyIDSession alloc] initWithStream:_stream];
  [_childSession executeAttachedWithArgs:argc argv:argv];
  _childSession = nil;
}

- (void)runMoshWithArgs:(int)argc argv:(char **)argv;
{
  
  _childSession = [[MoshSession alloc] initWithStream:_stream];
  [_childSession executeAttachedWithArgs:argc argv:argv];
  _childSession = nil;
}

- (void)runSSHWithArgs:(int)argc argv:(char **)argv;
{
  _childSession = [[SSHSession alloc] initWithStream:_stream];
  [_childSession executeAttachedWithArgs:argc argv:argv];
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
    @"  Plus the Unix utilities: cd, setenv, ls, touch, cp, rm, ln, mv, mkdir, rmdir, df, du, chksum, chmod, chflags, chgrp, stat, readlink, compress, uncompress, gzip, gunzip, pwd, env, printenv, date, uname, id, groups, whoami, uptime, cat, grep, wc, curl (includes http, https, scp, sftp...), scp, sftp, tar ",
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
