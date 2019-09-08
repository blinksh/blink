////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2019 Blink Mobile Shell Project
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

#import "Repl.h"
#import "replxx.h"
#import "BKHosts.h"
#import "BKTheme.h"
#import "BlinkPaths.h"
#include <arpa/inet.h>

#import <ios_system/ios_system.h>

#import "ios_error.h"

#define MCP_MAX_LINE 4096
#define MCP_MAX_HISTORY 1000

@implementation NSString (IPValidation)

- (BOOL)isValidIPAddress
{
  const char *utf8 = [self UTF8String];
  int success;
  
  struct in_addr dst;
  success = inet_pton(AF_INET, utf8, &dst);
  if (success != 1) {
    struct in6_addr dst6;
    success = inet_pton(AF_INET6, utf8, &dst6);
  }
  
  return success == 1;
}

@end

@implementation NSString (CompareWithHost)

- (NSComparisonResult)compareWithHost:(NSString *)other
{
  BOOL a = [self isValidIPAddress];
  BOOL b = [other isValidIPAddress];
  
  if (a == b) {
    return [self compare:other];
  }
  if (a) {
    return NSOrderedDescending;
  }
  
  return NSOrderedAscending;
}

@end


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


NSArray<NSString *> *__historyActionsByPrefix(NSString *prefix)
{
  NSPredicate * prefixPred = [__prefixPredicate predicateWithSubstitutionVariables:@{@"PREFIX": prefix}];
  return [@[@"-c", @"10", @"-10"] filteredArrayUsingPredicate:prefixPred];
}

@implementation Repl {
  Replxx* _replxx;
  __weak TermDevice *_device;
  __weak TermStream *_stream;
}

void __hints(char const* line, int bp, replxx_hints* lc, ReplxxColor* color, void* ud) {
  Repl *repl = (__bridge Repl *)ud;
  [repl _hints:line bp: bp lc: lc color: color ud: ud];
}

void __completion(char const* line, int bp, replxx_completions* lc, void* ud) {
  Repl *repl = (__bridge Repl *)ud;
  [repl _completion: line bp:bp lc: lc ud: ud];
}

- (instancetype)initWithDevice:(TermDevice *)device andStream: (TermStream *)stream
{
  if (self = [super init]) {
    _device = device;
    _replxx = nil;
    _stream = stream;
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
      
      @"open": @"open url of file (Experimental). 📤",
      @"link-files": @"link folders from Files.app (Experimental)."
      };
  }
}

// If we got `cat nice.txt | grep n ` it will return `grep n `
- (NSString *)_extractCmdWithArgs:(NSString *) line {
  
  NSUInteger len = [line lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
  const char *buf = line.UTF8String;
  int bp = 0;
  
  for(int i = 0; i < len; ++i) {
    char ch = buf[i];
    
    if (ch == '"') {
      i++;
      while (i < len && buf[i] != '"') {
        i++;
      }
    }

    if (ch == '\'') {
      i++;
      while (i < len && buf[i] != '\'') {
        i++;
      }
    }
    
    if (ch == '|') {
      bp = i;
    }
  }
  
  while (bp < len) {
    if (buf[bp] == ' ' || buf[bp] == '|') {
      bp++;
    } else {
      break;
    }
  }
  
  return [NSString stringWithUTF8String:&buf[bp]];
}

-(NSArray<NSString *> *)_allBlinkHosts
{
  NSMutableSet *hostsSet = [[NSMutableSet alloc] init];
  for (BKHosts *h in [BKHosts all]) {
    [hostsSet addObject:h.host];
  }
  
  return [hostsSet.allObjects sortedArrayUsingSelector:@selector(compare:)];
}

-(NSArray<NSString *> *)_allHosts
{
  NSMutableSet *hostsSet = [[NSMutableSet alloc] init];
  for (BKHosts *h in [BKHosts all]) {
    [hostsSet addObject:h.hostName];
  }
  
  [hostsSet addObjectsFromArray:[self _allKnownHosts]];
  
  return [hostsSet.allObjects sortedArrayUsingSelector:@selector(compareWithHost:)];
}

-(NSArray<NSString *> *)_allKnownHosts
{
  NSString * str = [NSString stringWithContentsOfFile:[BlinkPaths knownHostsFile] encoding:NSUTF8StringEncoding error:nil];
  NSArray<NSString *> * lines = [str componentsSeparatedByString:@"\n"];
  NSMutableSet *hostsSet = [[NSMutableSet alloc] init];
  for (NSString *line in lines) {
    NSArray<NSString *> * comps = [line componentsSeparatedByString:@" "];
    if ([comps firstObject].length > 0 ) {
      [hostsSet addObject:comps.firstObject];
    }
  }
  return [hostsSet.allObjects sortedArrayUsingSelector:@selector(compare:)];
}

-(NSArray<NSString *> *)_allDirectories:(NSString *)argument
{
  BOOL isDir;
  NSString* directory;
  NSFileManager *fileManager = [NSFileManager defaultManager];
  if ([fileManager fileExistsAtPath:argument isDirectory:&isDir] && isDir) {
    if ([[argument lastPathComponent] isEqualToString:@"."] && ![argument isEqualToString:@"."]) {
      directory = [argument stringByDeletingLastPathComponent];
    } else {
      directory = argument;
    }
  } else {
    directory = [argument stringByDeletingLastPathComponent]; // can be empty.
    if (directory.length == 0) {
      directory = @".";
    }
  }
  directory = [directory stringByExpandingTildeInPath];
  if ([fileManager fileExistsAtPath:directory isDirectory:&isDir] && isDir) {
    NSArray *filesAndFolders = [fileManager contentsOfDirectoryAtPath:directory error:nil];
    NSMutableArray *result = [[NSMutableArray alloc] init];
    BOOL deeper = ![directory isEqualToString:@"."];
    for (NSString *fileOrFolder in filesAndFolders) {
      NSString *folder = deeper ?  [directory stringByAppendingPathComponent:fileOrFolder] : fileOrFolder;
      if ([fileManager fileExistsAtPath:folder isDirectory:&isDir] && isDir) {
        [result addObject:folder];
      }
    }
    return [self _escapePaths:result];
  }
  return @[];
}

-(NSArray<NSString *> *)_allFiles:(NSString *)argument
{
  BOOL isDir;
  NSString* directory;
  NSFileManager *fileManager = [NSFileManager defaultManager];
  if ([fileManager fileExistsAtPath:argument isDirectory:&isDir] && isDir) {
    if ([[argument lastPathComponent] isEqualToString:@"."] && ![argument isEqualToString:@"."]) {
      directory = [argument stringByDeletingLastPathComponent];
    } else {
      directory = argument;
    }
  } else {
    directory = [argument stringByDeletingLastPathComponent]; // can be empty.
    if (directory.length == 0) {
      directory = @".";
    }
  }
  directory = [directory stringByExpandingTildeInPath];
  if ([fileManager fileExistsAtPath:directory isDirectory:&isDir] && isDir) {
    NSArray *filesAndFolders = [fileManager contentsOfDirectoryAtPath:directory error:nil];
    NSMutableArray *result = [[NSMutableArray alloc] init];
    BOOL deeper = ![directory isEqualToString:@"."];
    for (NSString *fileOrFolder in filesAndFolders) {
      NSString *file = deeper ? [directory stringByAppendingPathComponent:fileOrFolder] : fileOrFolder;
      [result addObject:file];
    }
    return [self _escapePaths:result];
  }
  return @[];
}

- (NSArray<NSString *> *)_escapePaths:(NSArray<NSString *> *)paths {
  NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:paths.count];
  for (NSString * path in paths) {
    if ([path containsString:@" "]) {
      NSString *escapedPath = [path stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
      [result addObject:escapedPath];
    } else {
      [result addObject:path];
    }
  }
  return result;
}

-(NSArray<NSString *> *)_completionsByType:(NSString *)completionType andPrefix:(NSString *)prefix {
  NSArray<NSString *> *completions = @[];
  
  if ([@"command" isEqualToString:completionType]) {
    completions = __commandList;
  } else if ([@"blink-host" isEqualToString:completionType]) {
    completions = [self _allBlinkHosts];
  } else if ([@"host" isEqualToString:completionType]) {
    completions = [self _allHosts];
  } else if ([@"blink-geo" isEqualToString:completionType]) {
    completions = @[@"track", @"lock", @"stop", @"current", @"authorize", @"last"];
  } else if ([@"file" isEqualToString:completionType]) {
    completions = [self _allFiles:prefix];
  } else if ([@"directory" isEqualToString:completionType]) {
    completions = [self _allDirectories:prefix];
  }
  
  if (prefix.length == 0 || completions.count == 0) {
    return completions;
  }
  
  NSPredicate *prefixPred = [__prefixPredicate predicateWithSubstitutionVariables:@{@"PREFIX": prefix}];
  return [completions filteredArrayUsingPredicate:prefixPred];
}

-(NSString *)_commandCompletionType:(NSString *)command {
  if ([@[@"ssh", @"mosh", @"ssh2"] indexOfObject:command] != NSNotFound) {
    return @"blink-host";
  } else if ([@"ping" isEqualToString:command]) {
    return @"host";
  } else if ([@"ls" isEqualToString:command]) {
    return @"directory";
  } else if ([@"open" isEqualToString:command]) {
    return @"file";
  } else if ([@"geo" isEqualToString:command]) {
    return @"blink-geo";
  } else if ([@[@"help", @"exit", @"whoami", @"config", @"clear", @"history", @"link-files"] indexOfObject:command] != NSNotFound) {
    return @"";
  }
  
  return operatesOn(command);
}

- (void)_completion:(char const*) line bp:(int)bp lc:(replxx_completions*)lc ud:(void*)ud {
  NSString *prefix = [self _extractCmdWithArgs:[NSString stringWithUTF8String:line]];
  
  NSArray *completions = [self _completionsByType:@"command" andPrefix:prefix];
  
  if (completions.count > 0) {
    for (NSString * c in completions) {
      replxx_add_completion(lc, c.UTF8String);
    }
    return;
  }
  
  NSArray *cmdAndArgs = __splitCommandAndArgs(prefix);
  NSString *cmd = cmdAndArgs[0];
  NSString *args = [self _extractCmdWithArgs:cmdAndArgs[1]];
  NSString *arg = args;
  
  NSArray<NSString *> *arguments = [args componentsSeparatedByString:@" "];
  if (arguments > 0) {
    arg = [arguments lastObject];
  }
  
  NSString *completionType = [self _commandCompletionType:cmd];
  completions = [self _completionsByType:completionType andPrefix:arg];
  
  for (NSString *c in completions) {
    replxx_add_completion(lc, c.UTF8String);
  }
}


- (void)_hints:(char const*)line bp:(int)bp lc:(replxx_hints *) lc color:(ReplxxColor*)color ud:(void*) ud {
  NSString *prefix = [NSString stringWithUTF8String:line];
  prefix = [self _extractCmdWithArgs:prefix];
  if (prefix.length == 0) {
    return;
  }
  
  NSArray<NSString *> *cmds = [self _completionsByType:@"command" andPrefix:prefix];
  if (cmds.count > 0) {
    for (NSString *cmd in cmds) {
      NSString *description = __commandHints[cmd];
      if (description.length > 0) {
        NSString *hint = [cmd stringByAppendingFormat:@" - %@", description];
        replxx_add_hint(lc, [hint substringFromIndex: prefix.length].UTF8String);
      } else {
        replxx_add_hint(lc, [cmd substringFromIndex: prefix.length].UTF8String);
      }
      
      return;
    }
  }
  
  NSArray *cmdAndArgs = __splitCommandAndArgs(prefix);
  NSString *cmd = cmdAndArgs[0];
  prefix = cmdAndArgs[1];
  NSString *arg = prefix;
  
  NSArray<NSString *> *arguments = [prefix componentsSeparatedByString:@" "];
  if (arguments > 0) {
    arg = [arguments lastObject];
  }
  
  NSString *completionType = [self _commandCompletionType:cmd];
  NSArray<NSString *> *completions = [self _completionsByType:completionType andPrefix:arg];

  if (completions.count == 0) {
    return;
  }
  NSString *hint = nil;
  if (completions.count < 6) {
     hint = [completions componentsJoinedByString:@", "];
  } else {
    completions = [completions subarrayWithRange:NSMakeRange(0, 6)];
    hint = [[completions componentsJoinedByString:@", "] stringByAppendingString:@", …"];
  }
  
  if ([hint length] > 0) {
    replxx_add_hint(lc, [hint substringFromIndex: arg.length].UTF8String);
  }
}

- (void)loopWithCallback:(BOOL(^)(NSString *cmd)) callback
{
  const char *history = [[BlinkPaths historyFile] UTF8String];
  _replxx = replxx_init();
  replxx_set_max_history_size(_replxx, MCP_MAX_HISTORY);
  replxx_history_load(_replxx, history);
  replxx_set_completion_callback(_replxx, __completion, (__bridge void*)self);
  replxx_set_hint_callback(_replxx, __hints, (__bridge void*)self);
  replxx_set_complete_on_empty(_replxx, 1);
  
  [self initCompletions];
  NSString *cmdline = nil;
  [_device setRawMode:NO];
  __weak TermView *termView = _device.view;
  
  while ((cmdline = [self _input:"blink> "]) != nil) {
    
    cmdline = [cmdline stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    if ([cmdline length] == 0) {
      continue;
    }
    
    replxx_history_add(_replxx, cmdline.UTF8String);
    replxx_history_save(_replxx, history);
    
    if (!callback(cmdline)) {
      break;
    }
    
    if (!_stream) {
      return;
    }
    
    dispatch_sync(dispatch_get_main_queue(), ^{
      // We have strange crash here
      // [termView restore];
      // so we need to check if we can restore
      if ([termView canPerformAction:@selector(restore) withSender:nil]) {
        [termView restore];
      }
    });
    
    if (!_stream) {
      return;
    }
    
    replxx_clear_screen_to_end(_replxx);
    
    printf("\033]0;blink\007");
    [_device setRawMode:NO];
  }
  
//  replxx_end(_replxx);
//  _replxx = nil;
}

- (NSString *)_input:(char *)prompt
{
  if (_replxx == nil || _stream.in == NULL) {
    return nil;
  }
  
  char const* result = NULL;
  blink_replxx_replace_streams(_replxx, _stream.in, _stream.out, _stream.err, &_device->win);
  result = replxx_input(_replxx, prompt);
  
  if ( result == NULL ) {
    return nil;
  }
  
  return [NSString stringWithUTF8String:result];
}

- (void)dealloc
{
  if (_replxx) {
    replxx_end(_replxx);
    _replxx = nil;
  }
  _device = nil;
  _stream = nil;
}

- (void)sigwinch
{
  if (_replxx) {
    replxx_window_changed(_replxx);
  }
}

- (int)clear_main:(int)argc argv:(char **)argv
{
  if (!_replxx) {
    return -1;
  }
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
                         @"history <number> - Show history (can be negative)",
                         @"history -c       - Clear history",
                         @""
                         ] componentsJoinedByString:@"\n"];
    printf("%s", usage.UTF8String);
    return 1;
  }
  return 0;
}




@end
