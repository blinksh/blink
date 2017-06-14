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

#include "file_cmds_ios.h"

#define MCP_MAX_LINE 4096

// If you have enabled a shared directory between apps, this is where you put its name
// For sideloading, it will be your developer name
// Remember to also activate it in the other app (e.g. vimIOS) 
#define appGroupFiles @"group.Nicolas-Holzschuch"

@implementation MCPSession {
  Session *childSession;
}

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
  char *line;
  argc = 0;
  argv = nil;

  // Path for application files, including history.txt and keys
  // TODO: give them a name / position
  NSString *docsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
  NSString *filePath = [docsPath stringByAppendingPathComponent:@"history.txt"];
  
#ifdef appGroupFiles
  // Path for access to App Group files (also accessed by Vim)
  NSURL *groupURL = [[NSFileManager defaultManager]
                     containerURLForSecurityApplicationGroupIdentifier:
                     appGroupFiles];
  NSURL *sharedURL = [NSURL URLWithString:@"Documents/" relativeToURL:groupURL];
#else
  NSURL *sharedURL = docsPath;
#endif
  setenv("SHARED", sharedURL.path.UTF8String, 0);
  // iOS already defines "HOME" as the home dir of the application
  
  // Current working directory == shared directory
  [[NSFileManager defaultManager] changeCurrentDirectoryPath:sharedURL.path];

  const char *history = [filePath UTF8String];

  [self.stream.control setRawMode:NO];

  linenoiseSetEncodingFunctions(linenoiseUtf8PrevCharLen,
                                linenoiseUtf8NextCharLen,
                                linenoiseUtf8ReadCode);

  linenoiseHistoryLoad(history);

  while ((line = [self linenoise:"blink> "]) != nil) {
    if (line[0] != '\0' /* && line[0] != '/' */) {
      linenoiseHistoryAdd(line);
      linenoiseHistorySave(history);

      NSString *cmdline = [[NSString alloc] initWithFormat:@"%s", line];
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
        // Shell commands for more interactions.
        // ls, rm, rmdir, touch...
        // 1) convert command line to argc / argv
        // 1a) split into elements
        NSArray *listArgv = [cmdline componentsSeparatedByString:@" "];
        // 1b) convert to argc / argv
        unsigned argc = [listArgv count];
        char **argv = (char **)malloc((argc + 1) * sizeof(char*));
        for (unsigned i = 0; i < argc; i++)
        {
          argv[i] = strdup([[listArgv objectAtIndex:i] UTF8String]);
          // Expand arguments that are environment variables
          if (argv[i][0] == '$') {
            int length = 1;
            for (; length < strlen(argv[i]); length++) if (argv[i][length] == '/') break;
            char* variable_name = strndup(argv[i] + 1, length - 1);
            char* expanded = getenv(variable_name);
            if (expanded) argv[i] = strcat(strdup(expanded), argv[i] + length);
            // free(variable_name);
          }
          // TODO: expand wildcards (* and ?). A lot harder.
        }
        argv[argc] = NULL;
        // 2) re-initialize for getopt:
        optind = 1;
        opterr = 1;
        optreset = 1;
        // 3) call specific commands
        // Redirect all output to console:
        stdout = _stream.control.termout;
        stderr = _stream.control.termout;
        // Commands from GNU coreutils: ls, rm, cp...
        if ([cmd isEqualToString:@"ls"]) {
          ls_main(argc, argv);
        } else if  ([cmd isEqualToString:@"touch"]) {
          touch_main(argc, argv);
        } else if  ([cmd isEqualToString:@"rm"]) {
          rm_main(argc, argv);
        } else if  ([cmd isEqualToString:@"cp"]) {
          cp_main(argc, argv);
        } else if  (([cmd isEqualToString:@"ln"]) || ([cmd isEqualToString:@"link"])) {
          ln_main(argc, argv);
        } else if  ([cmd isEqualToString:@"mv"]) {
            mv_main(argc, argv);
        } else if  ([cmd isEqualToString:@"mkdir"]) {
            mkdir_main(argc, argv);
        } else if  ([cmd isEqualToString:@"rmdir"]) {
            rmdir_main(argc, argv);
        } else if  (([cmd isEqualToString:@"chown"]) || ([cmd isEqualToString:@"chgrp"])) {
          chown_main(argc, argv);
        } else if  ([cmd isEqualToString:@"chflags"]) {
          chflags_main(argc, argv);
        } else if  ([cmd isEqualToString:@"chmod"]) {
          chmod_main(argc, argv);
        } else if  ([cmd isEqualToString:@"du"]) {
          du_main(argc, argv);
        } else if  ([cmd isEqualToString:@"df"]) {
          df_main(argc, argv);
        } else if  (([cmd isEqualToString:@"chksum"]) || ([cmd isEqualToString:@"sum"])) {
          chksum_main(argc, argv);
        } else if  (([cmd isEqualToString:@"stat"]) || ([cmd isEqualToString:@"readlink"])) {
          stat_main(argc, argv);
        } else if  (([cmd isEqualToString:@"compress"]) || ([cmd isEqualToString:@"uncompress"])) {
          compress_main(argc, argv);
        } else if  (([cmd isEqualToString:@"gzip"]) || ([cmd isEqualToString:@"gunzip"])) {
          gzip_main(argc, argv);
        } else if  ([cmd isEqualToString:@"mtree"]) {
          mtree_main(argc, argv);
        } else /* if  ([cmd isEqualToString:@"uname"]) {
            uname_main(argc, argv);
        } else if  ([cmd isEqualToString:@"pwd"]) {
          pwd_main(argc, argv);
        } else if  ([cmd isEqualToString:@"env"]) {
          env_main(argc, argv);
        } else if  ([cmd isEqualToString:@"printenv"]) {
          printenv_main(argc, argv);
        } else if  ([cmd isEqualToString:@"whoami"]) {
          whoami_main(argc, argv);
        } else if  ([cmd isEqualToString:@"id"]) {
            id_main(argc, argv);
          } else if  ([cmd isEqualToString:@"groups"]) {
              groups_main(argc, argv);
          } else
                // Commands that have to be inside the "shell"
                */ if  ([cmd isEqualToString:@"setenv"]) {
          // setenv VARIABLE value
          setenv(argv[1], argv[2], 1);
        } else if  ([cmd isEqualToString:@"cd"]) {
          if (argc > 1) {
            BOOL isDir;
            if ([[NSFileManager defaultManager] fileExistsAtPath:@(argv[1]) isDirectory:&isDir]) {
              if (isDir)
               [[NSFileManager defaultManager] changeCurrentDirectoryPath:@(argv[1])];
              else  fprintf(_stream.out, "cd: %s: not a directory\r\n", argv[1]);
            } else {
              fprintf(_stream.out, "cd: %s: no such file or directory\r\n", argv[1]);
            }
          } else // Help, I'm lost, bring me back home
            [[NSFileManager defaultManager] changeCurrentDirectoryPath:sharedURL.path];
        } else {
          [self out:"Unknown command. Type 'help' for a list of available operations"];
        }
        // Some commands free argv
        // if (![cmd isEqualToString:@"du"]) {
          for (unsigned i = 0; i < argc; i++)
          {
            free(argv[i]);
          }
          free(argv);
        //}
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
  [[UIApplication sharedApplication]
    sendAction:NSSelectorFromString(@"showConfig:") to:nil from:nil forEvent:nil];
}

- (void)runSSHCopyIDWithArgs:(NSString *)args
{
  childSession = [[SSHCopyIDSession alloc] initWithStream:_stream];
  [childSession executeAttachedWithArgs:args];
  childSession = nil;
}

- (void)runMoshWithArgs:(NSString *)args
{
  childSession = [[MoshSession alloc] initWithStream:_stream];
  [childSession executeAttachedWithArgs:args];
  childSession = nil;
}

- (void)runSSHWithArgs:(NSString *)args
{
  childSession = [[SSHSession alloc] initWithStream:_stream];
  [childSession executeAttachedWithArgs:args];
  childSession = nil;
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
    @"  Plus the Unix utilities: cp, ln, ls, mv, rm, mkdir, rmdir, id, whoami, groups, realpath, uname, touch, pwd, env, printenv.",
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
  if (childSession != nil) {
    [childSession sigwinch];
  }
}

- (void)kill
{
  if (childSession != nil) {
    [childSession kill];
  }

  // Close stdin to end the linenoise loop.
  if (_stream.in) {
    fclose(_stream.in);
    _stream.in = NULL;
  }
}

@end
