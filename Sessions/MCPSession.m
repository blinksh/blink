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
#include "shell_cmds_ios.h"
#include "text_cmds_ios.h"
#include "curl_ios.h"

#define MCP_MAX_LINE 4096

// If you have enabled a shared directory between apps, this is where you put its name
// For sideloading, it will be your developer name
// Remember to also activate it in the other app (e.g. vimIOS) 
#define appGroupFiles @"group.Nicolas-Holzschuch"

@implementation MCPSession {
  Session *childSession;
}

- (void)setTitle
{
  fprintf(_stream.control.termout, "\033]0;blink\007");
}


- (char **) makeargs:(NSString*) cmdline argc:(int*) argc
{
  // splits the command line into strings, removes empty strings,
  // does some conversions (~ --> home directory, for example,
  // plus environment variables)
#ifdef appGroupFiles
  // Path for access to App Group files (also accessed by Vim)
  NSURL *groupURL = [[NSFileManager defaultManager]
                     containerURLForSecurityApplicationGroupIdentifier:
                     appGroupFiles];
  NSURL *sharedURL = [NSURL URLWithString:@"Documents/" relativeToURL:groupURL];
#else
  NSURL *sharedURL = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
#endif

  // Separate arr into arguments and parse (env vars, ~, ~shared)
  NSArray *listArgvMaybeEmptyStrings = [cmdline componentsSeparatedByString:@" "];
  // Remove empty strings (extra spaces)
  NSArray *listArgv = [listArgvMaybeEmptyStrings filteredArrayUsingPredicate:
                       [NSPredicate predicateWithFormat:@"length > 0"]];
  
  *argc = [listArgv count];
  char** argv = (char **)malloc((*argc + 1) * sizeof(char*));
  // 1) convert command line to argc / argv
  // 1a) split into elements
  for (unsigned i = 0; i < [listArgv count]; i++)
  {
    // Operations on individual arguments
    NSString *argument = [listArgv objectAtIndex:i];
    // 1b) expand environment variables, + "~" (not wildcards ? and *)
    while ([argument containsString:@"$"]) {
      // It has environment variables inside. Work on them one by one.
      NSRange r1 = [argument rangeOfString:@"$"];
      NSRange r2 = [argument rangeOfString:@"/" options:NULL range:NSMakeRange(r1.location + r1.length, [argument length] - r1.location - r1.length)];
      if (r2.location == NSNotFound) r2.location = [argument length];
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
    // Only 2 possibilities: "~" (same as $HOME) and "~shared" (same as $SHARED)
    if([argument hasPrefix:@"~"]) {
      // So it begins with "~"
      NSString* test_string = @"~shared";
      NSString* replacement_string;
      if (sharedURL && [argument hasPrefix:@"~shared"]) {
        replacement_string = sharedURL.path;
        argument = [argument stringByReplacingOccurrencesOfString:test_string withString:replacement_string options:NULL range:NSMakeRange(0, 7)];
      }
      if (getenv("HOME") && [argument hasPrefix:@"~/"]) {
        test_string = @"~/";
        replacement_string = [NSString stringWithCString:(getenv("HOME")) encoding:NSASCIIStringEncoding];
        replacement_string = [replacement_string stringByAppendingString:[NSString stringWithCString:"/" encoding:NSASCIIStringEncoding]];
        argument = [argument stringByReplacingOccurrencesOfString:test_string withString:replacement_string options:NULL range:NSMakeRange(0, 2)];
      } else if (getenv("HOME") && ([argument isEqual:@"~"] || [argument hasPrefix:@"~:"])) {
        test_string = @"~";
        replacement_string = [NSString stringWithCString:(getenv("HOME")) encoding:NSASCIIStringEncoding];
        argument = [argument stringByReplacingOccurrencesOfString:test_string withString:replacement_string options:NULL range:NSMakeRange(0, 1)];
      }
    }
    // Also convert ":~something" in PATH style variables
    // We don't use these yet, but we could.
    if ([argument containsString:@":~"]) {
      // Only 2 possibilities: ":~" (same as $HOME) and ":~shared" (same as $SHARED)
      if ([argument containsString:@":~shared"] && sharedURL) {
        NSString* test_string = @":~shared";
        NSString* replacement_string = [[NSString stringWithCString:":" encoding:NSASCIIStringEncoding] stringByAppendingString:sharedURL.path];
        argument = [argument stringByReplacingOccurrencesOfString:test_string withString:replacement_string];
      }
      if ([argument containsString:@":~/"] && getenv("HOME")) {
        NSString* test_string = @":~/";
        NSString* replacement_string = [[NSString stringWithCString:":" encoding:NSASCIIStringEncoding] stringByAppendingString:[NSString stringWithCString:(getenv("HOME")) encoding:NSASCIIStringEncoding]];
        replacement_string = [replacement_string stringByAppendingString:[NSString stringWithCString:"/" encoding:NSASCIIStringEncoding]];
        argument = [argument stringByReplacingOccurrencesOfString:test_string withString:replacement_string];
      }
      if (getenv("HOME") && [argument hasSuffix:@":~"]) {
        NSString* test_string = @":~";
        NSString* replacement_string = [[NSString stringWithCString:":" encoding:NSASCIIStringEncoding] stringByAppendingString:[NSString stringWithCString:(getenv("HOME")) encoding:NSASCIIStringEncoding]];
        argument = [argument stringByReplacingOccurrencesOfString:test_string withString:replacement_string options:NULL range:NSMakeRange([argument length] - 2, 2)];
      }
    }
    argv[i] = [argument UTF8String];
  }
  argv[*argc] = NULL;
  return argv;
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
  // We can't write in $HOME so for ssh & curl to work, we need other homes for config files:
  setenv("SSH_HOME", docsPath.UTF8String, 0);
  setenv("CURL_HOME", docsPath.UTF8String, 0);
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

      argv = [self makeargs:cmdline argc:&argc];

      NSString *cmd = [NSString stringWithCString:argv[0] encoding:NSASCIIStringEncoding];

      // TODO: move all sessions to receive listArgv instead of cmdline
      // TODO: parsing scp / sftp commands
      
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
        break;
      } else if ([cmd isEqualToString:@"ssh-copy-id"]) {
        [self runSSHCopyIDWithArgs:argc argv:argv];
      } else if ([cmd isEqualToString:@"config"]) {
        [self showConfig];
      } else {
        // Shell commands for more interactions.
        // ls, rm, rmdir, touch...
        // 2) re-initialize for getopt:
        optind = 1;
        opterr = 1;
        optreset = 1;
        // 3) call specific commands
        // Redirect all output to console:
        stdout = _stream.control.termout;
        stderr = _stream.control.termout; 
        // Commands from Apple file_cmds: ls, rm, cp...
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
          // Commands from Apple shell_cmds:
        } else if  ([cmd isEqualToString:@"printenv"]) {
            printenv_main(argc, argv);
        } else if  ([cmd isEqualToString:@"pwd"]) {
          pwd_main(argc, argv);
        } else if  ([cmd isEqualToString:@"uname"]) {
          uname_main(argc, argv);
        } else if  ([cmd isEqualToString:@"date"]) {
          date_main(argc, argv);
        } else if  ([cmd isEqualToString:@"env"]) {
          env_main(argc, argv);
        } else if  (([cmd isEqualToString:@"id"])  || ([cmd isEqualToString:@"groups"]) || ([cmd isEqualToString:@"whoami"])) {
            id_main(argc, argv);
          } else if  (([cmd isEqualToString:@"uptime"]) || ([cmd isEqualToString:@"w"])) {
              w_main(argc, argv);
            // Commands from Apple text_cmds:
          } else if  ([cmd isEqualToString:@"cat"]) {
            cat_main(argc, argv);
          } else if  ([cmd isEqualToString:@"wc"]) {
            wc_main(argc, argv);
          } else if  (([cmd isEqualToString:@"grep"]) || ([cmd isEqualToString:@"egrep"]) || ([cmd isEqualToString:@"fgrep"])){
            grep_main(argc, argv);
          } else
                // Commands that have to be inside the "shell"
                 if  ([cmd isEqualToString:@"setenv"]) {
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
          } else // [cd] Help, I'm lost, bring me back home
            [[NSFileManager defaultManager] changeCurrentDirectoryPath:sharedURL.path];
          // Higher level commands, not from system: curl, tar, scp, sftp
        } else if  ([cmd isEqualToString:@"curl"]) {
          curl_main(argc, argv);
        } else if  (([cmd isEqualToString:@"scp"]) || ([cmd isEqualToString:@"sftp"])) {
          // We have an scp / sftp command. We convert it into a curl command:
          // scp user@host:~/data/file . is equivalent to
          // curl scp://user@host/~/data/file -O
          for (int i = 1; i < argc; i++) {
            /*NSString *scp_option = [listArgv objectAtIndex:i];
            // if it begins with a "-" it's a parameter
            if ([scp_option characterAtIndex:0] == '-') continue;
            // If we're copying into current dir:
            if ([scp_option isEqualToString:@"."]) scp_option = @"-O" ;
            // TODO: what if file exists + is a directory?
            if (![scp_option containsString:@":"]) continue;
            // [scp_option rangeOfCharacterFromSet:[':'] ]
            */
            
          }
          free(argv[0]);
          argv[0] = strdup([@"curl" UTF8String]);

          curl_main(argc, argv);
        } else {
          [self out:"Unknown command. Type 'help' for a list of available operations"];
        }
      }
      free(argv);
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

- (void)runSSHCopyIDWithArgs:(int)argc argv:(char **)argv;
{
  childSession = [[SSHCopyIDSession alloc] initWithStream:_stream];
  [childSession executeAttachedWithArgs:argc argv:argv];
  childSession = nil;
}

- (void)runMoshWithArgs:(int)argc argv:(char **)argv;
{
  childSession = [[MoshSession alloc] initWithStream:_stream];
  [childSession executeAttachedWithArgs:argc argv:argv];
  childSession = nil;
}

- (void)runSSHWithArgs:(int)argc argv:(char **)argv;
{
  childSession = [[SSHSession alloc] initWithStream:_stream];
  [childSession executeAttachedWithArgs:argc argv:argv];
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
    @"  Plus the Unix utilities: cd, pwd, ls, cp, ln, mv, rm, touch, mkdir, rmdir, setenv, env, printenv, ",
    @"      compress, uncompress, gzip, gunzip, cat, wc, grep, egrep, fgrep, date, ",
    @"      df, du, chksum, chmod, chflags, chgrp, stat, readlink, uname, id, groups, whoami, uptime.",
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
