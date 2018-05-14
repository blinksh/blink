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
// List of all commands available, sorted alphabetically:
// Extracted at runtime from ios_system() plus blinkshell commands:
NSArray* commandList;

// for file completion
// do recompute directoriesInPath only if $PATH has changed
static NSString* fullCommandPath = @"";
static NSArray *directoriesInPath;


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
      replxx_add_hint(lc, [hint substringFromIndex: prefix.length - bp].UTF8String);
    }
    //    hint = __commandHints[cmd];
  } else {
    NSArray *cmdAndArgs = __splitCommandAndArgs(prefix);
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
    replxx_add_hint(lc, [hint substringFromIndex: prefix.length - bp].UTF8String);
  }
}


@implementation Repl {
  Replxx* _replxx;
  TermDevice *_device;
}

- (instancetype)initWithDevice:(TermDevice *)device
{
  if (self = [super init]) {
    _device = device;
    _replxx = replxx_init();
  }
  
  return self;
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
  
  NSArray *cmdAndArgs = __splitCommandAndArgs(prefix);
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

- (void)loopWithCallback:(BOOL(^)(NSString *cmd)) callback
{
  const char *history = [[BlinkPaths historyFile] UTF8String];
  replxx_set_max_history_size(_replxx, MCP_MAX_HISTORY);
  replxx_history_load(_replxx, history);
  replxx_set_completion_callback(_replxx, completion, 0);
  replxx_set_hint_callback(_replxx, hints, 0);
  replxx_set_complete_on_empty(_replxx, 1);
  
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

    fprintf(_device.stream.out, "\033]0;blink\007");
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
      fprintf(thread_stdout, "%s", [NSString stringWithFormat:@"% 4li %@", i + 1, lines[i]].UTF8String);
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
    fprintf(thread_stdout, "%s", usage.UTF8String);
    return 1;
  }
  return 0;
}




@end
