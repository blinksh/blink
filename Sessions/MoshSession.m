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
#include <netdb.h>
#include <pthread.h>
#include <sys/socket.h>
#include <unistd.h>

#include <mosh/moshiosbridge.h>

#import "BKHosts.h"
#import "MoshSession.h"
#import "SSHSession.h"
#import <ios_system/ios_system.h>
#import "Blink-Swift.h"


static NSDictionary *predictionModeStrings = nil;
static NSDictionary *experimentalIPStrings = nil;

static const char *usage_format =
"This is the Original mosh command. Use in case new mosh command does not work.\r\n"
"Please let us know in that case.\r\n"
"Usage: mosh1 [options] [user@]host|IP [--] [command]"
"\r\n"
"                --server=PATH          mosh server on remote machine\r\n"
"                                       (default: mosh-server)\r\n"
"                --predict=adaptive     local echo for slower links [default]\r\n"
"-a              --predict=always       use local echo even on fast links\r\n"
"-n              --predict=never        never use local echo\r\n"
"                --predict=experimental aggressively echo even when incorrect\r\n"
"\r\n"
"-o              --predict-overwrite    prediction overwrites instead of inserting\r\n"
"\r\n"
"-k              --key=<MOSH_KEY>       MOSH_KEY to connect without ssh\r\n"
"-p PORT[:PORT2] --port=PORT[:PORT2]    server-side UDP port (range)\r\n"
"-P NUM                                 ssh connection port\r\n"
"-T              --no-ssh-pty           do not allocate a pseudo tty on ssh connection\r\n"
"-2                                     use ssh2 command\r\n"
"-I id                                  ssh authentication identity name\r\n"
//  "        --ssh=COMMAND        ssh command to run when setting up session\r\n"
//  "                                (example: \"ssh -p 2222\")\r\n"
//  "                                (default: \"ssh\")\r\n"
"\r\n"
"                --verbose              verbose mode\r\n"
"                --help                 this message\r\n"
"\r\n"
"--experimental-remote-ip={default|remote|local}    method used to discover the IP address that the mosh-client connects to \r\n"
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
  NSString *_escapeKey;
  dispatch_semaphore_t _sema;
  CFTypeRef _selfRef;
}

@dynamic sessionParams;

+ (void)initialize
{
  predictionModeStrings = @{
    @(BKMoshPredictionAdaptive): @"adaptive",
    @(BKMoshPredictionAlways): @"always",
    @(BKMoshPredictionNever): @"never",
    @(BKMoshPredictionExperimental): @"experimental"
  };
  
  experimentalIPStrings = @{
    @(BKMoshExperimentalIPNone): @"default",
    @(BKMoshExperimentalIPLocal): @"local",
    @(BKMoshExperimentalIPRemote): @"remote"
  };
}

- (int)initParamaters:(int)argc argv:(char **)argv
{
  
  NSString *ssh, *sshPort, *sshIdentity;
  BOOL sshTTY = YES;
  BOOL useSSH2 = NO;
  int help = 0;
  NSString *colors;
  
  struct option long_options[] =
  {
    {"server", required_argument, 0, 's'},
    {"predict", required_argument, 0, 'r'},
    {"port", required_argument, 0, 'p'},
    {"ip", optional_argument, 0, 'i'},
    {"key", optional_argument, 0, 'k'},
    {"no-ssh-pty", optional_argument, 0, 'T'},
    {"predict-overwrite", no_argument, 0, 'o'},
    //{"ssh", required_argument, 0, 'S'},
    {"verbose", no_argument, &_debug, 1},
    {"help", no_argument, &help, 1},
    {"experimental-remote-ip", required_argument, 0, 'R'},
    {0, 0, 0, 0}};
  
  optind = 0;
  if (self.sessionParams == nil) {
    self.sessionParams = [[MoshParams alloc] init];
  }
  
  while (1) {
    int option_index = 0;
    int c = getopt_long(argc, argv, "anop:I:P:k:T2", long_options, &option_index);
    if (c == -1) {
      break;
    }
    
    if (c == 0) {
      // Already parsed param
      continue;
    }
    
    switch (c) {
      case 's':
      self.sessionParams.serverPath = [NSString stringWithFormat:@"%s", optarg];
      break;
      case '2':
      useSSH2 = YES;
      break;
      case 'r':
      self.sessionParams.predictionMode = [NSString stringWithFormat:@"%s", optarg];
      break;
      case 'p':
      self.sessionParams.port = [NSString stringWithFormat:@"%s", optarg];
      break;
      case 'o':
      self.sessionParams.predictOverwrite = @"yes";
      break;
      case 'k':
      self.sessionParams.key = [NSString stringWithFormat:@"%s", optarg];
      break;
      //      case 'S':
      //        param = optarg;
      //  ssh = [NSString stringWithFormat:@"%s", optarg];
      //  break;
      case 'a':
      self.sessionParams.predictionMode = @"always";
      break;
      case 'n':
      self.sessionParams.predictionMode = @"never";
      break;
      case 'P':
      sshPort = [NSString stringWithFormat:@"%s", optarg];
      break;
      case 'I':
      sshIdentity = [NSString stringWithFormat:@"%s", optarg];
      break;
      case 'T':
        sshTTY = NO;
      break;
      case 'R':
      self.sessionParams.experimentalRemoteIp = [NSString stringWithFormat:@"%s", optarg];
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
    self.sessionParams.startupCmd = [remoteCmdChunks componentsJoinedByString:@" "];
  }
  
  [self processMoshSettings:hostCfg];
  
  if (self.sessionParams.key) {
    self.sessionParams.ip = hostCfg.hostName ?: userhost;
    if (self.sessionParams.port == nil) {
      return [self dieMsg:@"If MOSH_KEY is set port is required. (-p)"];
    }
  } else  {
    NSString *moshServerCmd = [self getMoshServerStringCmd:self.sessionParams.serverPath
                                                      port:self.sessionParams.port
                                                withColors:colors
                                                       run:self.sessionParams.startupCmd];
    [self debugMsg:moshServerCmd];
    
    NSError *error;
    if (useSSH2) {
      [self setConnParamsWithSsh2:ssh userHost:userhost port:sshPort identity:sshIdentity moshCommand:moshServerCmd error:&error];
    } else {
      [self setConnParamsWithSsh:ssh userHost:userhost port:sshPort identity:sshIdentity sshTTY:sshTTY moshCommand:moshServerCmd error:&error];
    }
    if (error) {
      return [self dieMsg:error.localizedDescription];
    }
  }
  
  // Validate prediction mode
  self.sessionParams.predictionMode = self.sessionParams.predictionMode ?: @"adaptive";
  if ([@[ @"always", @"adaptive", @"never" ] indexOfObject:self.sessionParams.predictionMode] == NSNotFound) {
    return [self dieMsg:@"Unknown prediction mode. Use one of: always, adaptive, never"];
  }
  
  self.sessionParams.experimentalRemoteIp = self.sessionParams.experimentalRemoteIp ?: @"default";
  if (![@[@"default", @"remote", @"local"] containsObject:self.sessionParams.experimentalRemoteIp]) {
    return [self dieMsg:@"Unknown experimental IP mode. Use one of: default, remote, local"];
  }
  
  return 0;
}

- (int)main:(int)argc argv:(char **)argv
{
  _escapeKey = @"\x1e";
  char *envMoshEscapeKey = getenv("MOSH_ESCAPE_KEY");
  if (envMoshEscapeKey) {
    NSString *newEscape = @(envMoshEscapeKey);
    if (newEscape.length == 1) {
      _escapeKey = newEscape;
    }
  }
  
  NSData *encodedState = self.sessionParams.encodedState;
  if (encodedState == nil) {
    int code = [self initParamaters:argc argv:argv];
    if ( code < 0) {
      return code;
    }
  }
  
  NSString *locales_path = [[NSBundle mainBundle] pathForResource:@"locales" ofType:@"bundle"];
  setenv("PATH_LOCALE", [locales_path cStringUsingEncoding:1], 1);
  
  [_device setRawMode:YES];

  [self.sessionParams cleanEncodedState];
  
  _selfRef = CFBridgingRetain(self);
  mosh_main(
            _stream.in, _stream.out, &_device->win,
            &__state_callback, (void *)_selfRef,
            [self.sessionParams.ip UTF8String],
            [self.sessionParams.port UTF8String],
            [self.sessionParams.key UTF8String],
            [self.sessionParams.predictionMode UTF8String],
            encodedState.bytes,
            encodedState.length,
            [self.sessionParams.predictOverwrite UTF8String]
            );
  
  [_device setRawMode:NO];

  fprintf(_stream.out, "\nMosh session finished!\n");
  
  return 0;
}

- (void)main_cleanup {
  if (_selfRef) {
    CFBridgingRelease(_selfRef);
    _selfRef = NULL;
  }
  [super main_cleanup];
}

- (void)processMoshSettings:(BKHosts *)host
{
  NSString *server = host.moshServer.length ?
  // Escape server path
  [NSString stringWithFormat:@"\"%@\"", [host.moshServer stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]]
  : nil;
  
  self.sessionParams.serverPath = self.sessionParams.serverPath ?: server;
  
  if (!self.sessionParams.port && host.moshPort) {
    self.sessionParams.port = [host.moshPort stringValue];
    if (host.moshPortEnd) {
      self.sessionParams.port = [NSString stringWithFormat:@"%@:%@", host.moshPort, host.moshPortEnd];
    }
  }
//  self.sessionParams.port = self.sessionParams.port ?: [host.moshPort stringValue];
  
  NSString *startupCmd = host.moshStartup.length ? host.moshStartup : nil;
  self.sessionParams.startupCmd = self.sessionParams.startupCmd ?: startupCmd;
  
  NSString *predictionMode = host.prediction ? predictionModeStrings[host.prediction] : nil;
  self.sessionParams.predictionMode = self.sessionParams.predictionMode ?: predictionMode;
  self.sessionParams.predictOverwrite = self.sessionParams.predictOverwrite ?: host.moshPredictOverwrite;

  NSString *experimentalIP = host.moshExperimentalIP ? experimentalIPStrings[host.moshExperimentalIP] : @"default";
  self.sessionParams.experimentalRemoteIp = self.sessionParams.experimentalRemoteIp ?: experimentalIP;
}

- (NSString *)getMoshServerStringCmd:(NSString *)server
                                port:(NSString *)port
                          withColors:(NSString *)colors
                                 run:(NSString *)command
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

- (void)setConnParamsWithSsh:(NSString *)ssh
                    userHost:(NSString *)userHost
                        port:(NSString *)port
                    identity:(NSString *)identity
                      sshTTY:(BOOL)sshTTY
                 moshCommand:(NSString *)command
                       error:(NSError **)error
{
  ssh = ssh ? ssh : @"ssh";
  
  NSMutableArray * sshArgs;
  
  BOOL useIPFromSSHConnectionEnv = [@"remote" isEqual:self.sessionParams.experimentalRemoteIp];
  if (useIPFromSSHConnectionEnv) {
    NSString *commandWithEcho = [NSString stringWithFormat:@"echo \"MOSH SSH_CONNECTION $SSH_CONNECTION\" && %@", command];
    sshArgs = [@[ssh, @"-o compression=no", sshTTY ? @"-t" : @"-T", userHost, @"--", commandWithEcho] mutableCopy];
  } else {
    sshArgs = [@[ssh, @"-o compression=no", sshTTY ? @"-t" : @"-T", userHost, @"--", command] mutableCopy];
  }
  
  if (port) {
    [sshArgs insertObject:[NSString stringWithFormat:@"-p %@", port] atIndex:1];
  }
  if (identity) {
    [sshArgs insertObject:[NSString stringWithFormat:@"-i %@", identity] atIndex:1];
  }
  if (_debug) {
    [sshArgs insertObject:@"-v" atIndex:1];
  }
  
  [_mcpSession setActiveSession];
  
  NSString * sshCmd = [sshArgs componentsJoinedByString:@" "];
  [self debugMsg:sshCmd];

  FILE *term_r = ios_popen(sshCmd.UTF8String, "r");
  
  if (term_r == NULL) {
    *error = [NSError errorWithDomain:@"blink.mosh.ssh" code:0 userInfo:@{ NSLocalizedDescriptionKey : @"SSH session exited with error. Try SSH to the host first." }];
    return;
  }
  
  // Capture ssh output and process parameters for Mosh connection
  char *buf = NULL;
  size_t buf_sz = 0;
  NSString * line;
  
  NSString* ipPattern;
  int ipMatchIdx = -1;
  
  NSRegularExpression *ipFormat = NULL;
  if (useIPFromSSHConnectionEnv) {
    ipPattern = @"MOSH SSH_CONNECTION (\\S*) (\\d*) (\\S*) (\\d*)$";
    ipMatchIdx = 3;
    ipFormat = [NSRegularExpression regularExpressionWithPattern:ipPattern options:0 error:nil];
  } else if ([@"default" isEqual:self.sessionParams.experimentalRemoteIp]) {
    ipPattern = @"Connected to (\\S*)$";
    ipMatchIdx = 1;
    ipFormat = [NSRegularExpression regularExpressionWithPattern:ipPattern options:0 error:nil];
  }
    
  NSString * connPattern = @"MOSH CONNECT (\\d+) (\\S*)$";
  NSRegularExpression * connFormat = [NSRegularExpression regularExpressionWithPattern:connPattern options:0 error:nil];
  NSTextCheckingResult * match;
  ssize_t n = 0;
  
  while ((n = getline(&buf, &buf_sz, term_r)) >= 0) {
    line = [NSString stringWithFormat:@"%.*s", (int)n, buf];
    NSRange lineRange = NSMakeRange(0, line.length);
    
    if (ipFormat != NULL) {
      match = [ipFormat firstMatchInString:line options:0 range:lineRange];
      if (match) {
        self.sessionParams.ip = [line substringWithRange:[match rangeAtIndex:ipMatchIdx]];
        continue;
      }
    } else {
      // No ipFormat for "local", so resolve locally.
      NSString *host;
      NSArray *userHostList = [userHost componentsSeparatedByString:@"@"];
      if ([userHostList count] > 1) {
        host = userHostList[1];
      } else {
        host = userHostList[0];
      }
      
      // TODO Or to INET6 from CLI flag
      NSString *resolvedAddress = [self resolve_addr:[host UTF8String]
                          port:22 family:AF_INET];
      if (resolvedAddress == NULL) {
        *error = [NSError errorWithDomain:@"blink.mosh.ssh" code:0 userInfo:@{ NSLocalizedDescriptionKey : @"Could not resolve address locally for host." }];
        return;
      }
      self.sessionParams.ip = resolvedAddress;
    }
    
    match = [connFormat firstMatchInString:line options:0 range:lineRange];
    if (match) {
      self.sessionParams.port = [line substringWithRange:[match rangeAtIndex:1]];
      self.sessionParams.key  = [line substringWithRange:[match rangeAtIndex:2]];
      break;
    }
    
    fwrite(buf, 1, n, _stream.out);
  }
  
  fclose(term_r);
  
  if (!match) {
    *error = [NSError errorWithDomain:@"blink.mosh.ssh" code:0 userInfo:@{ NSLocalizedDescriptionKey : @"Could not start mosh-server." }];
    return;
  }
  
  if (!self.sessionParams.ip) {
    *error = [NSError errorWithDomain:@"blink.mosh.ssh" code:0 userInfo:@{ NSLocalizedDescriptionKey : @"Incorrect mosh-server startup sequence." }];
    return;
  }
  
  if (self.sessionParams.key == nil || self.sessionParams.port == nil) {
    *error = [NSError errorWithDomain:@"blink.mosh.ssh" code:0 userInfo:@{ NSLocalizedDescriptionKey : @"Incorrect mosh-server startup sequence." }];
    return;
  }
}

- (void)setConnParamsWithSsh2:(NSString *)ssh userHost:(NSString *)userHost port:(NSString *)port identity:(NSString *)identity moshCommand:(NSString *)command error:(NSError **)error
{
  ssh = ssh ? ssh : @"ssh2";
  
  NSMutableArray*sshArgs = [NSMutableArray arrayWithObjects:ssh, @"-t", userHost, @"--", command, nil];
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
  
  SSHSession *sshSession = [[SSHSession alloc] initWithDevice:_device andParams:nil];
  
  int poutput[2];
  pipe(poutput);
  FILE *term_w = fdopen(poutput[1], "w");
  setvbuf(term_w, NULL, _IONBF, 0);
  FILE *term_r = fdopen(poutput[0], "r");
  
  fclose(sshSession.stream.out);
  sshSession.stream.out = term_w;
  
  [sshSession executeWithArgs:sshCmd];
  
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
      self.sessionParams.ip = [line substringWithRange:matchRange];
    } else if ((match = [connFormat firstMatchInString:line options:0 range:NSMakeRange(0, line.length)])) {
      NSRange matchRange = [match rangeAtIndex:1];
      self.sessionParams.port = [line substringWithRange:matchRange];
      matchRange = [match rangeAtIndex:2];
      self.sessionParams.key = [line substringWithRange:matchRange];
      break;
    } else {
      fwrite(buf, 1, n, _stream.out);
    }
  }
  
  if (!self.sessionParams.ip) {
    *error = [NSError errorWithDomain:@"blink.mosh.ssh" code:0 userInfo:@{ NSLocalizedDescriptionKey : @"Did not find remote IP address" }];
    return;
  }
  
  if (self.sessionParams.key == nil || self.sessionParams.port == nil) {
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
  // MOSH-ESC .
  [_device write:[NSString stringWithFormat:@"%@%@", _escapeKey ?: @"\x1e", @"\x2e"]];
  pthread_kill(_tid, SIGINT);
}

- (void)suspend
{
  _sema = dispatch_semaphore_create(0);
  // MOSH-ESC C-z
  [_device write:[NSString stringWithFormat:@"%@%@", _escapeKey ?: @"\x1e", @"\x1a"]];
  dispatch_semaphore_wait(_sema, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC));
}

- (void)onStateEncoded: (NSData *) encodedState
{
  self.sessionParams.encodedState = encodedState;
  if (_sema) {
    dispatch_semaphore_signal(_sema);
  }
}

- (void)dealloc
{
  NSLog(@"deallocating mosh");
}

// Hosts and no hosts tested
- (NSString*)resolve_addr:(const char *)name port:(int)port family:(int)family
{
  char strport[NI_MAXSERV];
  struct addrinfo hints, *info;
  int err;
  
  if (port <= 0) {
    port = 22;
  }
  
  snprintf(strport, sizeof strport, "%d", port);
  memset(&hints, 0, sizeof(hints));
  // IPv4 / IPv6
  hints.ai_family = family == -1 ? AF_UNSPEC : family;
  hints.ai_socktype = SOCK_STREAM;
  
  if ((err = getaddrinfo(name, strport, &hints, &info)) != 0) {
    [self debugMsg: [NSString stringWithFormat: @"getaddrinfo failed with code: %d", err]];
    return NULL;
  }
  
  struct addrinfo *ai;
  char ntop[NI_MAXHOST];

  for (ai = info; ai; ai = ai->ai_next) {
    if (ai->ai_family != AF_INET && ai->ai_family != AF_INET6) {
      continue;
    }
    
    if (getnameinfo(ai->ai_addr, ai->ai_addrlen,
                    ntop, sizeof(ntop), strport,
                    sizeof(strport), NI_NUMERICHOST | NI_NUMERICSERV) != 0) {
      [self debugMsg:@"Could not resolve address: getnameinfo failed"];
      continue;
    }

    return [NSString stringWithUTF8String:ntop];
  }

  return NULL;
}
@end
