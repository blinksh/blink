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

#include <getopt.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>

#include "libmoshios/moshiosbridge.h"

#import "BKHosts.h"
#import "MoshSession.h"
#import "SSHSession.h"
#import <ios_system/ios_system.h>


static NSDictionary *predictionModeStrings = nil;

static const char *usage_format =
"Usage: mosh [options] [user@]host|IP [--] [command]"
"\r\n"
"        --server=PATH        mosh server on remote machine\r\n"
"                             (default: mosh-server)\r\n"
"        --predict=adaptive   local echo for slower links [default]\r\n"
"-a      --predict=always     use local echo even on fast links\r\n"
"-n      --predict=never      never use local echo\r\n"
"\r\n"
"-k      --key=<MOSH_KEY>     MOSH_KEY to connect without ssh\r\n"
"-p NUM  --port=NUM           server-side UDP port\r\n"
"-P NUM                       ssh connection port\r\n"
"-I id                        ssh authentication identity name\r\n"
//  "        --ssh=COMMAND        ssh command to run when setting up session\r\n"
//  "                                (example: \"ssh -p 2222\")\r\n"
//  "                                (default: \"ssh\")\r\n"
"\r\n"
"        --verbose            verbose mode\r\n"
"        --help               this message\r\n"
"\r\n";


@interface MoshSession ()
- (void) onStateEncoded:(NSData *) encodedState;
@end

void __state_callback(const void *context, const void *buffer, size_t size) {
  NSData * data = [NSData dataWithBytes:buffer length:size];
  MoshSession *session = (__bridge MoshSession *)context;
  [session onStateEncoded: data];
}


@implementation MoshSession {
  int _debug;
  NSLock * _lock;
}

@dynamic sessionParameters;

+ (void)initialize
{
  predictionModeStrings = @{
    @(BKMoshPredictionAdaptive): @"adaptive",
    @(BKMoshPredictionAlways): @"always",
    @(BKMoshPredictionNever): @"never",
    @(BKMoshPredictionExperimental): @"experimental",
    @(BKMoshPredictionUnknown): @"adaptive"
  };
}

- (int)initParamaters:(int)argc argv:(char **)argv
{
  NSString *ssh, *sshPort, *sshIdentity;
  int help = 0;
  NSString *colors;
  
  struct option long_options[] =
  {
    {"server", required_argument, 0, 's'},
    {"predict", required_argument, 0, 'r'},
    {"port", required_argument, 0, 'p'},
    {"ip", optional_argument, 0, 'i'},
    {"key", optional_argument, 0, 'k'},
    //{"ssh", required_argument, 0, 'S'},
    {"verbose", no_argument, &_debug, 1},
    {"help", no_argument, &help, 1},
    {0, 0, 0, 0}};
  
  optind = 0;
  if (self.sessionParameters == nil) {
    self.sessionParameters = [[MoshParameters alloc] init];
  }
  
  while (1) {
    int option_index = 0;
    int c = getopt_long(argc, argv, "anp:I:P:k:", long_options, &option_index);
    if (c == -1) {
      break;
    }
    
    if (c == 0) {
      // Already parsed param
      continue;
    }
    
    switch (c) {
      case 's':
      self.sessionParameters.serverPath = [NSString stringWithFormat:@"%s", optarg];
      break;
      case 'r':
      self.sessionParameters.predictionMode = [NSString stringWithFormat:@"%s", optarg];
      break;
      case 'p':
      self.sessionParameters.port = [NSString stringWithFormat:@"%s", optarg];
      break;
      case 'k':
      self.sessionParameters.key = [NSString stringWithFormat:@"%s", optarg];
      break;
      //      case 'S':
      //        param = optarg;
      //  ssh = [NSString stringWithFormat:@"%s", optarg];
      //  break;
      case 'a':
      self.sessionParameters.predictionMode = @"always";
      break;
      case 'n':
      self.sessionParameters.predictionMode = @"never";
      break;
      case 'P':
      sshPort = [NSString stringWithFormat:@"%s", optarg];
      break;
      case 'I':
      sshIdentity = [NSString stringWithFormat:@"%s", optarg];
      break;
      default:
      return [self dieMsg:@(usage_format)];
    }
  }
  
  if (argc - optind < 1) {
    return [self dieMsg:@(usage_format)];
  }
  
  if (help) {
    return [self dieMsg:@(usage_format)];
  }
  
  NSString *userhost = [NSString stringWithFormat:@"%s", argv[optind++]];
  
  NSArray *chunks = [userhost componentsSeparatedByString:@"@"];
  BKHosts *hostCfg;
  if ([chunks count] != 2) {
    hostCfg = [BKHosts withHost:userhost];
  } else {
    hostCfg = [BKHosts withHost:chunks[1]];
  }
  
  char **remote_command = &argv[optind];
  int idx_remote_command = argc - optind;
  NSMutableArray *remoteCmdChunks = [[NSMutableArray alloc] init];
  if (idx_remote_command) {
    for (int i = 0; i < idx_remote_command; i++) {
      [remoteCmdChunks addObject:[NSString stringWithFormat:@"%s", remote_command[i]]];
    }
    self.sessionParameters.startupCmd = [remoteCmdChunks componentsJoinedByString:@" "];
  }
  
  [self processMoshSettings:hostCfg];
  
  if (self.sessionParameters.key) {
    self.sessionParameters.ip = hostCfg.hostName ?: userhost;
    if (self.sessionParameters.port == nil) {
      return [self dieMsg:@"If MOSH_KEY is set port is required. (-p)"];
    }
  } else  {
    NSString *moshServerCmd = [self getMoshServerStringCmd:self.sessionParameters.serverPath port:self.sessionParameters.port withColors:colors run:self.sessionParameters.startupCmd];
    [self debugMsg:moshServerCmd];
    
    NSError *error;
    [self setConnParamsWithSsh:ssh userHost:userhost port:sshPort identity:sshIdentity moshCommand:moshServerCmd error:&error];
    if (error) {
      return [self dieMsg:error.localizedDescription];
    }
  }
  
  // Validate prediction mode
  self.sessionParameters.predictionMode = self.sessionParameters.predictionMode ?: @"adaptive";
  if ([@[ @"always", @"adaptive", @"never" ] indexOfObject:self.sessionParameters.predictionMode] == NSNotFound) {
    return [self dieMsg:@"Unknown prediction mode. Use one of: always, adaptive, never"];
  }
  return 0;
}

- (int)main:(int)argc argv:(char **)argv
{
  if (self.sessionParameters.encodedState == nil) {
    int code = [self initParamaters:argc argv:argv];
    if ( code < 0) {
      return code;
    }
  }
  
  NSString *locales_path = [[NSBundle mainBundle] pathForResource:@"locales" ofType:@"bundle"];
  setenv("PATH_LOCALE", [locales_path cStringUsingEncoding:1], 1);
  
  [_device setRawMode:YES];
  
  mosh_main(
            _stream.in, _stream.out, &_device->win,
            &__state_callback, (__bridge void *) self,
            [self.sessionParameters.ip UTF8String],
            [self.sessionParameters.port UTF8String],
            [self.sessionParameters.key UTF8String],
            [self.sessionParameters.predictionMode UTF8String],
            self.sessionParameters.encodedState.bytes,
            self.sessionParameters.encodedState.length
            );
  
  [_device setRawMode:NO];

  fprintf(_stream.out, "\nMosh session finished!\n");
  
  return 0;
}

- (void)processMoshSettings:(BKHosts *)host
{
  NSString *server = host.moshServer.length ?
  // Escape server path
  [NSString stringWithFormat:@"\"%@\"", [host.moshServer stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]]
  : nil;
  
  self.sessionParameters.serverPath = self.sessionParameters.serverPath ?: server;
  
  self.sessionParameters.port = self.sessionParameters.port ?: [host.moshPort stringValue];
  
  NSString *startupCmd = host.moshStartup.length ? host.moshStartup : nil;
  self.sessionParameters.startupCmd = self.sessionParameters.startupCmd ?: startupCmd;
  
  NSString *predictionMode = host.prediction ? predictionModeStrings[host.prediction] : nil;
  self.sessionParameters.predictionMode = self.sessionParameters.predictionMode ?: predictionMode;
}

- (NSString *)getMoshServerStringCmd:(NSString *)server port:(NSString *)port withColors:(NSString *)colors run:(NSString *)command
{
  server = server.length ? server : @"mosh-server";
  colors = colors.length ? colors : @"256";
  
  // Prepare ssh command
  NSMutableArray *moshServerArgs = [NSMutableArray arrayWithObjects:server, @"new", @"-s", @"-c", colors, @"-l LC_ALL=en_US.UTF-8", nil];
  if (port) {
    [moshServerArgs addObject:@"-p"];
    [moshServerArgs addObject:port];
  }
  
  if (command) {
    [moshServerArgs addObject: @"--"];
    [moshServerArgs addObject:command];
  }
  
  return [NSString stringWithFormat:@"%@", [moshServerArgs componentsJoinedByString:@" "]];
}

- (void)setConnParamsWithSsh:(NSString *)ssh userHost:(NSString *)userHost port:(NSString *)port identity:(NSString *)identity moshCommand:(NSString *)command error:(NSError **)error
{
  ssh = ssh ? ssh : @"ssh";
  
  NSMutableArray*sshArgs = [@[ssh, @"-o _printaddress=yes", @"-o compression=no", @"-t", userHost, command] mutableCopy];
  if (port) {
    [sshArgs insertObject:[NSString stringWithFormat:@"-p %@", port] atIndex:1];
  }
  if (identity) {
    [sshArgs insertObject:[NSString stringWithFormat:@"-i %@", identity] atIndex:1];
  }
  if (_debug) {
    [sshArgs insertObject:@"-v" atIndex:1];
  }
  
  NSString *sshCmd = [sshArgs componentsJoinedByString:@" "];
  [self debugMsg:sshCmd];

  FILE *term_r = ios_popen(sshCmd.UTF8String, "r");
  
  // Capture ssh output and process parameters for Mosh connection
  char *buf = NULL;
  size_t buf_sz = 0;
  NSString *line;
  
  NSString *ipPattern = @"Connected to (\\S*)$";
  NSRegularExpression *ipFormat = [NSRegularExpression regularExpressionWithPattern:ipPattern options:0 error:nil];
  
  NSString *connPattern = @"MOSH CONNECT (\\d+) (\\S*)$";
  NSRegularExpression *connFormat = [NSRegularExpression regularExpressionWithPattern:connPattern options:0 error:nil];
  
  NSTextCheckingResult *match;
  
  ssize_t n = 0;
  
  while ((n = getline(&buf, &buf_sz, term_r)) >= 0) {
    line = [NSString stringWithFormat:@"%.*s", (int)n, buf];
    if ((match = [ipFormat firstMatchInString:line options:0 range:NSMakeRange(0, line.length)])) {
      NSRange matchRange = [match rangeAtIndex:1];
      self.sessionParameters.ip = [line substringWithRange:matchRange];
    } else if ((match = [connFormat firstMatchInString:line options:0 range:NSMakeRange(0, line.length)])) {
      NSRange matchRange = [match rangeAtIndex:1];
      self.sessionParameters.port = [line substringWithRange:matchRange];
      matchRange = [match rangeAtIndex:2];
      self.sessionParameters.key = [line substringWithRange:matchRange];
      break;
    } else {
      fwrite(buf, 1, n, _stream.out);
    }
  }
  
  fclose(term_r);
  
  if (!self.sessionParameters.ip) {
    *error = [NSError errorWithDomain:@"blink.mosh.ssh" code:0 userInfo:@{ NSLocalizedDescriptionKey : @"Did not find remote IP address" }];
    return;
  }
  
  if (self.sessionParameters.key == nil || self.sessionParameters.port == nil) {
    *error = [NSError errorWithDomain:@"blink.mosh.ssh" code:0 userInfo:@{ NSLocalizedDescriptionKey : @"Did not find remote IP address" }];
    return;
  }
}

- (void)debugMsg:(NSString *)msg
{
  if (_debug) {
    fprintf(_stream.out, "MoshClient:DEBUG:%s\r\n", [msg UTF8String]);
  }
}

- (int)dieMsg:(NSString *)msg
{
  fprintf(_stream.out, "%s\n", [msg UTF8String]);
  return -1;
}

- (void)sigwinch
{
  pthread_kill(_tid, SIGWINCH);
}

- (void)kill
{
  pthread_kill(_tid, SIGINT);
}

- (void)suspend
{
  _lock = [[NSLock alloc] init];
  [_lock lock];
  [_device write:@"\x1e\x1a"];
  NSTimeInterval timeout = 2;
  NSDate *d = [[NSDate date] dateByAddingTimeInterval:timeout];
  if ([_lock lockBeforeDate: d]) {
    [_lock unlock];
  }
  _lock = nil;
}

- (void)onStateEncoded: (NSData *) encodedState
{
  self.sessionParameters.encodedState = encodedState;
  [_lock unlock];
}

@end
