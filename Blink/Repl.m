//
//  Repl.m
//  Blink
//
//  Created by Yury Korolev on 5/14/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#import "Repl.h"
#import "replxx.h"
#import "BKHosts.h"
#import "BKTheme.h"
#import "MusicManager.h"
#import "BlinkPaths.h"

#import <ios_system/ios_system.h>
#import "ios_error.h"

#define MCP_MAX_LINE 4096
#define MCP_MAX_HISTORY 1000

NSArray<NSString *> *__splitCommandAndArgs(NSString *cmdline)
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

NSArray *__commandList;
NSDictionary *__commandHints;

// for file completion
// do recompute directoriesInPath only if $PATH has changed
static NSString* fullCommandPath = @"";
static NSArray *directoriesInPath;

static NSPredicate *__prefixPredicate;

NSArray<NSString *> *__commandsByPrefix(NSString *prefix)
{
  if (prefix.length == 0) {
    return __commandList;
  }
  NSPredicate * prefixPred = [__prefixPredicate predicateWithSubstitutionVariables:@{@"PREFIX": prefix}];
  return [__commandList filteredArrayUsingPredicate:prefixPred];
}

NSArray<NSString *> *__hostsByPrefix(NSString *prefix)
{
  NSMutableArray *hostsNames = [[NSMutableArray alloc] init];
  for (BKHosts *h in [BKHosts all]) {
    [hostsNames addObject:h.host];
  }
  
  if (prefix.length == 0) {
    return hostsNames;
  }
  NSPredicate * prefixPred = [__prefixPredicate predicateWithSubstitutionVariables:@{@"PREFIX": prefix}];
  return [hostsNames filteredArrayUsingPredicate:prefixPred];
}

NSArray<NSString *> *__musicActionsByPrefix(NSString *prefix)
{
  NSArray<NSString *> * actions = [[MusicManager shared] commands];
  
  if (prefix.length == 0) {
    return actions;
  }
  NSPredicate * prefixPred = [__prefixPredicate predicateWithSubstitutionVariables:@{@"PREFIX": prefix}];
  return [actions filteredArrayUsingPredicate:prefixPred];
}

NSArray<NSString *> *__historyActionsByPrefix(NSString *prefix)
{
  NSPredicate * prefixPred = [__prefixPredicate predicateWithSubstitutionVariables:@{@"PREFIX": prefix}];
  return [@[@"-c", @"10", @"-10"] filteredArrayUsingPredicate:prefixPred];
}


NSArray<NSString *> *__themesByPrefix(NSString *prefix) {
  NSMutableArray *themeNames = [[NSMutableArray alloc] init];
  for (BKTheme *theme in [BKTheme all]) {
    [themeNames addObject:theme.name];
  }
  
  if (prefix.length == 0) {
    return themeNames;
  }
  NSPredicate * prefixPred = [__prefixPredicate predicateWithSubstitutionVariables:@{@"PREFIX": prefix}];
  return [themeNames filteredArrayUsingPredicate:prefixPred];
}

@implementation Repl {
  Replxx* _replxx;
  TermDevice *_device;
}

void __hints(char const* line, int bp, replxx_hints* lc, ReplxxColor* color, void* ud) {
  Repl *repl = (__bridge Repl *)ud;
  [repl _hints:line bp: bp lc: lc color: color ud: ud];
}

void __completion(char const* line, int bp, replxx_completions* lc, void* ud) {
  Repl *repl = (__bridge Repl *)ud;
  [repl _completion: line bp:bp lc: lc ud: ud];
}

- (instancetype)initWithDevice:(TermDevice *)device
{
  if (self = [super init]) {
    _device = device;
    _replxx = replxx_init();
  }
  
  return self;
}

- (void)initCompletions
{
  if (__prefixPredicate == nil) {
    __prefixPredicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH[c] $PREFIX"];
  }
  
  if (__commandList == nil) {
    __commandList = [
                   [@[@"mosh", @"exit", @"ssh-copy-id"]
                      arrayByAddingObjectsFromArray:commandsAsArray()]
                   sortedArrayUsingSelector:@selector(compare:)
                   ];
  }
  
  if (__commandHints == nil) {
    __commandHints =
    @{
      @"awk": @"Select particular records in a file and perform operations upon them.",
      @"cat": @"Concatenate and print files.",
      @"cd": @"Change directory.",
  //    @"chflags": @"chflags", // TODO
  //    @"chksum": @"chksum", // TODO
      @"clear": @"Clear the terminal screen. 🙈",
      @"compress": @"Compress data.",
      @"config": @"Add keys, hosts, themes, etc... 🔧 ",
      @"cp": @"Copy files and directories",
      @"curl": @"Transfer data from or to a server.",
      @"date": @"Display or set date and time.",
      @"diff": @"Compare files line by line.",
      @"dig": @"DNS lookup utility.",
      @"du": @"Disk usage",
      @"echo": @"Write arguments to the standard output.",
      @"egrep": @"Search for a pattern using extended regex.", // https://www.computerhope.com/unix/uegrep.htm
      @"env": @"Set environment and execute command, or print environment.", // fish
      @"exit": @"Exit current session. 👋",
      @"fgrep": @"File pattern searcher.", // fish
      @"find": @"Walk a file hierarchy.", // fish
      @"grep": @"File pattern searcher.", // fish
      @"gunzip": @"Compress or expand files",  // https://linux.die.net/man/1/gunzip
      @"gzip": @"Compression/decompression tool using Lempel-Ziv coding (LZ77)",  // fish
      @"head": @"Display first lines of a file", // fish
      @"help": @"Prints all commands. 🧐 ",
      @"history": @"Use -c option to clear history. 🙈 ",
      @"host": @"DNS lookup utility.", // fish
      @"link": @"Make links.", // fish
      @"ln": @"", // TODO
      @"ls": @"List files and directories",
      @"md5": @"Calculate a message-digest fingerprint (checksum) for a file.", // fish
      @"mkdir": @"Make directories.", // fish
      @"mosh": @"Runs mosh client. 🦄",
      @"music": @"Control music player 🎧",
      @"mv": @"Move files and directories.",
  //    @"nc": @"", // TODO
      @"nslookup": @"Query Internet name servers interactively", // fish
      @"pbcopy": @"Copy to the pasteboard.",
      @"pbpaste": @"Paste from the pasteboard.",
      @"ping": @"Send ICMP ECHO_REQUEST packets to network hosts.", // fish
      @"printenv": @"Print out the environment.", // fish
      @"pwd": @"Return working directory name.", // fish
      @"readlink": @"Display file status.", // fish
  //    @"rlogin": @"", // TODO: REMOVE
      @"rm": @"Remove files and directories.",
      @"rmdir": @"Remove directories.", // fish
      @"scp": @"Secure copy (remote file copy program).", // fish
      @"sed": @"Stream editor.", // fish
  //    @"setenv": @"", // TODO
      @"sftp": @"Secure file transfer program.", // fish
      @"showkey": @"Display typed chars.",
      @"sort": @"Sort or merge records (lines) of text and binary files.", // fish
      @"ssh": @"Runs ssh client. 🐌",
      @"ssh-copy-id": @"Copy an identity to the server. 💌",
  //    @"ssh-keygen": @"", // TODO
      @"stat": @"Display file status.", // fish
      @"sum": @"Display file checksums and block counts.", // fish
      @"tail": @"Display the last part of a file.", // fish
      @"tar": @"Manipulate tape archives.", // fish
      @"tee": @"Pipe fitting.", // fish
      @"telnet": @"User interface to the TELNET protocol.", // fish
      @"theme": @"Choose a theme 💅",
      @"touch": @"Change file access and modification times.", // fish
  //    @"tr": @"", // TODO
      @"uname": @"Print operating system name.", // fish
      @"uncompress": @"Expand data.",
      @"uniq": @"Report or filter out repeated lines in a file.", // fish
      @"unlink": @"Remove directory entries.", // fish
  //    @"unsetenv": @"", // TODO
      @"uptime": @"Show how long system has been running.", // fish
      @"wc": @"Words and lines counter.",
      @"whoami": @"Display effective user id.", // fish
      @"whois": @"Internet domain name and network number directory service.", // fish
      
      @"open": @"open url of file (Experimental). 📤"
      };
  }
}

void system_completion(char const* command, int bp, replxx_completions* lc, void* ud) {

  // TODO: get current working directory from ios_system
  BOOL isDir;
  NSString* commandString = [NSString stringWithUTF8String:command];
  if ([commandString rangeOfString:@" "].location == NSNotFound) {
    // No spaces. The user is typing a command
    // check for pre-defined commands:
    for (NSString* existingCommand in __commandList) {
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

- (void)_completion:(char const*) line bp:(int)bp lc:(replxx_completions*)lc ud:(void*)ud {
  NSLog(@"comp bp: %@", @(bp));
  NSString* prefix = [NSString stringWithUTF8String:line];
  NSArray *commands = __commandsByPrefix(prefix);
  
  if (commands.count > 0) {
    for (NSString * cmd in commands) {
      replxx_add_completion(lc, [cmd substringFromIndex:bp].UTF8String);
    }
    return;
  }
  
  NSArray *cmdAndArgs = __splitCommandAndArgs(prefix);
  NSString *cmd = cmdAndArgs[0];
  NSString *args = cmdAndArgs[1];
  NSArray *completions = @[];
  
  if ([cmd isEqualToString:@"ssh"] || [cmd isEqualToString:@"mosh"]) {
    completions = __hostsByPrefix(args);
  } else if ([cmd isEqualToString:@"music"]) {
    completions = __musicActionsByPrefix(args);
  } else if ([cmd isEqualToString:@"theme"]) {
    completions = __themesByPrefix(args);
  } else if ([cmd isEqualToString:@"history"]) {
    completions = __historyActionsByPrefix(args);
  } else {
    system_completion(line, bp, lc, ud);
    return;
  }
  
  for (NSString *c in completions) {
    replxx_add_completion(lc, c.UTF8String);
  }
}

- (void)_hints:(char const*)line bp:(int)bp lc:(replxx_hints *) lc color:(ReplxxColor*)color ud:(void*) ud {
  NSLog(@"hint bp: %@", @(bp));
  NSString *hint = nil;
  NSString *prefix = [NSString stringWithUTF8String:line];
  if (prefix.length == 0) {
    return;
  }
  
  NSArray<NSString *> *cmds = __commandsByPrefix(prefix);
  if (cmds.count > 0) {
    for (NSString *cmd in cmds) {
      NSString *description = __commandHints[cmd];
      if (description.length > 0) {
        NSString *hint = [cmd stringByAppendingFormat:@" - %@", description];
        replxx_add_hint(lc, [hint substringFromIndex: prefix.length - bp].UTF8String);
      } else {
        replxx_add_hint(lc, [cmd substringFromIndex: prefix.length - bp].UTF8String);
      }
      
      return;
    }
  } else {
    NSArray *cmdAndArgs = __splitCommandAndArgs(prefix);
    NSString *cmd = cmdAndArgs[0];
    prefix = cmdAndArgs[1];
    
    if ([cmd isEqualToString:@"ssh"] || [cmd isEqualToString:@"mosh"]) {
      hint = [__hostsByPrefix(prefix) componentsJoinedByString:@", "];
    } else if ([cmd isEqualToString:@"theme"]) {
      hint = [__themesByPrefix(prefix) componentsJoinedByString:@", "];
    } else if ([cmd isEqualToString:@"music"]) {
      hint = [__musicActionsByPrefix(prefix) componentsJoinedByString:@", "];
    }
  }
  
  if ([hint length] > 0) {
    replxx_add_hint(lc, [hint substringFromIndex: prefix.length].UTF8String);
  }
}

- (void)loopWithCallback:(BOOL(^)(NSString *cmd)) callback
{
  const char *history = [[BlinkPaths historyFile] UTF8String];
  replxx_set_max_history_size(_replxx, MCP_MAX_HISTORY);
  replxx_history_load(_replxx, history);
  replxx_set_completion_callback(_replxx, __completion, (__bridge void*)self);
  replxx_set_hint_callback(_replxx, __hints, (__bridge void*)self);
  replxx_set_complete_on_empty(_replxx, 1);
  
  [self initCompletions];
  NSString *cmdline = nil;
  [_device setRawMode:NO];
  
  while ((cmdline = [self _input:"\x1b[1;32mblink\x1b[0m> "]) != nil) {
    cmdline = [cmdline stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    if ([cmdline length] == 0) {
      continue;
    }
    
    replxx_history_add(_replxx, cmdline.UTF8String);
    replxx_history_save(_replxx, history);
    
    if (!callback(cmdline)) {
      break;
    }

    printf("\033]0;blink\007");
    [_device setRawMode:NO];
  }
  
  replxx_end(_replxx);
  _replxx = nil;
}

- (NSString *)_input:(char *)prompt
{
  if (_device.stream.in == NULL) {
    return nil;
  }
  FILE * savedStdOut = stdout;
  FILE * savedStdErr = stderr;
  stdout = _device.stream.out;
  stderr = _device.stream.err;
  
  thread_stdout = _device.stream.out;
  thread_stdin = _device.stream.in;
  thread_stderr = _device.stream.err;
  
  char const* result = NULL;
  blink_replxx_replace_streams(_replxx, thread_stdin, thread_stdout, thread_stderr, &_device->win);
  result = replxx_input(_replxx, prompt);
  stdout = savedStdOut;
  stderr = savedStdErr;
  
  if ( result == NULL ) {
    return nil;
  }
  
  return [NSString stringWithUTF8String:result];
}

- (void)kill
{
  if (_replxx) {
    replxx_end(_replxx);
    _replxx = nil;
  }
}

- (void)sigwinch
{
  if (_replxx) {
    replxx_window_changed(_replxx);
  }
}

- (int)clear_main:(int)argc argv:(char **)argv
{
  blink_replxx_replace_streams(_replxx, thread_stdin, thread_stdout, thread_stderr, &_device->win);
  replxx_clear_screen(_replxx);
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
      printf("%s\n", [NSString stringWithFormat:@"% 4li %@", i + 1, lines[i]].UTF8String);
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
                         @""
                         ] componentsJoinedByString:@"\n"];
    printf("%s", usage.UTF8String);
    return 1;
  }
  return 0;
}




@end
