//////////////////////////////////////////////////////////////////////////////////
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


#import "SSHClient.h"
#import "BlinkPaths.h"
#import "BKDefaults.h"
#import "BKHosts.h"
#import "BKPubKey.h"

#include <getopt.h>
#include <libssh/libssh.h>
#include <libssh/callbacks.h>

void dispatch_write_utf8string(dispatch_fd_t fd,
               NSString * _Nonnull string,
               dispatch_queue_t queue,
               void (^handler)(dispatch_data_t _Nullable data, int error)) {
  __block NSData *nsData = [string dataUsingEncoding:NSUTF8StringEncoding];
  
  dispatch_data_t data = dispatch_data_create(nsData.bytes, nsData.length, queue, ^{
    nsData = nil;
  });
  
  if (!data && handler) {
    dispatch_async(queue, ^{
      handler(nil, 1);
    });
    return;
  }
  
  dispatch_write(fd, data, queue, handler);
}

const NSString * SSHOptionStrictHostKeyChecking = @"stricthostkeychecking";
const NSString * SSHOptionHostName =  @"hostname";
const NSString * SSHOptionPort =  @"port"; // -p
const NSString * SSHOptionLogLevel =  @"loglevel"; // -v
const NSString * SSHOptionIdentityFile = @"identityfile"; // -i
const NSString * SSHOptionRequestTTY = @"requesttty"; // -tT
const NSString * SSHOptionUser = @"user"; // -l
const NSString * SSHOptionProxyCommand = @"proxycommand"; // ?
const NSString * SSHOptionConfigFile = @"configfile"; // -F
const NSString * SSHOptionRemoteCommand = @"remotecommand";
const NSString * SSHOptionConnectTimeout = @"connecttimeout"; // -o
const NSString * SSHOptionConnectionAttempts = @"connectionattempts"; // -o
const NSString * SSHOptionCompression = @"compression"; //-C -o
const NSString * SSHOptionTCPKeepAlive = @"tcpkeepalive";
const NSString * SSHOptionNumberOfPasswordPrompts = @"numberofpasswordprompts"; // -o
const NSString * SSHOptionServerLiveCountMax = @"serveralivecountmax"; // -o
const NSString * SSHOptionServerLiveInterval = @"serveraliveinterval"; // -o

// Non standart
const NSString * SSHOptionPassword = @"_password"; //
const NSString * SSHOptionPrintConfiguration = @"_printconfiguration"; // -G

const NSString * SSHOptionValueYES = @"yes";
const NSString * SSHOptionValueNO = @"no";
const NSString * SSHOptionValueAUTO = @"auto";
const NSString * SSHOptionValueANY = @"any";
const NSString * SSHOptionValueNONE = @"none";

const NSString * SSHOptionValueINFO = @"info";
const NSString * SSHOptionValueERROR = @"error";
const NSString * SSHOptionValueDEBUG = @"debug";
const NSString * SSHOptionValueDEBUG1 = @"debug1";
const NSString * SSHOptionValueDEBUG2 = @"debug2";
const NSString * SSHOptionValueDEBUG3 = @"debug3";

///** No logging at all */
//#define SSH_LOG_NONE 0
///** Show only warnings */
//#define SSH_LOG_WARN 1
///** Get some information what's going on */
//#define SSH_LOG_INFO 2
///** Get detailed debuging information **/
//#define SSH_LOG_DEBUG 3
///** Get trace output, packet information, ... */
//#define SSH_LOG_TRACE 4



@implementation SSHClient {
  dispatch_queue_t _mainQueue;

  dispatch_fd_t _fdIn;
  dispatch_fd_t _fdOut;
  dispatch_fd_t _fdErr;
  
  ssh_session _ssh_session;
  dispatch_semaphore_t _mainDsema;
  
  NSMutableDictionary *_options;
  
  int _exitCode;
}

- (instancetype)initWithStdIn:(dispatch_fd_t)fdIn stdOut:(dispatch_fd_t)fdOut stdErr:(dispatch_fd_t)fdErr {
  if (self = [super init]) {
    _mainQueue = dispatch_queue_create("sh.blink.sshclient", DISPATCH_QUEUE_SERIAL);
    _fdIn = fdIn;
    _fdOut = fdOut;
    _fdErr = fdErr;
    _mainDsema = dispatch_semaphore_create(0);
    _options = [[NSMutableDictionary alloc] init];
    
    _exitCode = 0;
  }
  
  return self;
}

- (int)_exitWithCode:(int)code {
  dispatch_barrier_async(_mainQueue, ^{
    _exitCode = code;
    dispatch_semaphore_signal(_mainDsema);
  });
  
  return code;
}

- (int)_exitWithCode:(int)code andMessage: (NSString * __nonnull)message {
  dispatch_write_utf8string(_fdErr, [message stringByAppendingString:@"\n"], _mainQueue, ^(dispatch_data_t  _Nullable data, int error) {
    [self _exitWithCode:code];
  });
  return _exitCode;
}

- (NSObject *)_tryParsePort:(char *)portStr {
  int port = [@(portStr) intValue];
  
  if (port <= 0 || port > 65536) {
    [self _exitWithCode:SSH_ERROR andMessage:@"Wrong port value provided."];
    return [NSNull null];
  }
  return @(port);
}

- (NSObject *)_parseValues:(char *)value withPossible:(NSArray *)possibleValues {
  NSString *val = [@(value) lowercaseString];
  if ([possibleValues indexOfObject:val] == NSNotFound) {
    [self _exitWithCode:SSH_ERROR andMessage:[NSString stringWithFormat:@"unsupported option \"%@\"", val]];
    return [NSNull null];
  }
  return val;
}

- (NSMutableDictionary *)_applyOptions:(NSArray *)options toArgs:(NSDictionary *)args {
  NSObject *stringType = [[NSObject alloc] init];
  NSObject *yesNoType = [[NSObject alloc] init];
  NSObject *yesNoAutoType = [[NSObject alloc] init];
  NSObject *yesNoAskType = [[NSObject alloc] init];
  NSObject *portType = [[NSObject alloc] init];
  NSObject *intType = [[NSObject alloc] init];
  NSObject *intNoneType = [[NSObject alloc] init];
  
  NSDictionary *opts = @{
                         SSHOptionUser: @[stringType],
                         SSHOptionHostName: @[stringType],
                         SSHOptionPort: @[portType, @(22)],
                         SSHOptionRequestTTY: @[yesNoAutoType, @"auto"],
                         SSHOptionTCPKeepAlive: @[yesNoType, @"yes"],
                         SSHOptionConnectionAttempts: @[intType, @(1)],
                         SSHOptionNumberOfPasswordPrompts: @[intType, @(3)],
                         SSHOptionServerLiveCountMax: @[intType, @(3)],
                         SSHOptionServerLiveInterval: @[intType, @(0)],
                         SSHOptionRemoteCommand: @[stringType],
                         SSHOptionConnectTimeout: @[intType, @"none"],
                         
                         SSHOptionStrictHostKeyChecking: @[yesNoAskType, @"ask"],
                         SSHOptionCompression: @[yesNoType, @"yes"]
                         };
  
  NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
  
  // Set defaults:
  for (NSString *key in opts.allKeys) {
    NSArray *vals = opts[key];
    if (vals.count >= 2) {
      result[key] = vals[1];
    }
  }
  
  // Set options:
  for (NSString *optionStr in options) {
    NSArray *parts = [optionStr componentsSeparatedByString:@"="];
    
    
    if (parts.count == 1) {
      [self _exitWithCode:SSH_ERROR andMessage:@"Missing argument."];
      return result;
    }
    
    NSString *key = [parts.firstObject lowercaseString];
    NSArray *vals = opts[key];
    if (vals == nil) {
      [self _exitWithCode:SSH_ERROR andMessage:[NSString stringWithFormat:@"Bad configuration option: %@", key]];
      return result;
    }
    
    NSObject *type = vals[0];
    NSString *value = parts[1];
    NSString *lv = [value lowercaseString];
    
    if (type == stringType) {
      result[key] = value; // TODO: strip qoutes
    } else if (type == yesNoType) {
      if ([@[@"yes", @"no"] indexOfObject:lv] == NSNotFound) {
        [self _exitWithCode:SSH_ERROR andMessage:[NSString stringWithFormat:@"unsupported option \"%@\".", key]];
        return result;
      }
      result[key] = lv;
    } else if (type == yesNoAutoType) {
      if ([@[@"yes", @"no", @"auto"] indexOfObject:lv] == NSNotFound) {
        [self _exitWithCode:SSH_ERROR andMessage:[NSString stringWithFormat:@"unsupported option \"%@\".", key]];
        return result;
      }
      result[key] = lv;
    } else if (type == yesNoAskType) {
      if ([@[@"yes", @"no", @"ask"] indexOfObject:lv] == NSNotFound) {
        [self _exitWithCode:SSH_ERROR andMessage:[NSString stringWithFormat:@"unsupported option \"%@\".", key]];
        return result;
      }
      result[key] = lv;
    } else if (type == intNoneType) {
      if ([lv isEqualToString:@"none"]) {
        result[key] = lv;
      } else {
        int v = 0;
        NSScanner *scanner = [NSScanner scannerWithString:lv];
        if ([scanner scanInt:&v] && scanner.atEnd) {
          result[key] = @(v);
        } else {
          [self _exitWithCode:SSH_ERROR andMessage:[NSString stringWithFormat:@"invalid number \"%@\".", value]];
          return result;
        }
      }
    } else if (type == portType) {
      int port = [lv intValue];
      if (port <= 0) {
        port = 22;
      }
      if (port > 65536) {
        [self _exitWithCode:SSH_ERROR andMessage:[NSString stringWithFormat:@"bad port number \"%@\".", key]];
        return result;
      }
      result[key] = @(port);
    } else if (type == intType) {
      int v = 0;
      NSScanner *scanner = [NSScanner scannerWithString:lv];
      if ([scanner scanInt:&v] && scanner.atEnd) {
        result[key] = @(v);
      } else {
        [self _exitWithCode:SSH_ERROR andMessage:[NSString stringWithFormat:@"invalid number \"%@\".", value]];
        return result;
      }
    }
  }
  
  // Apply args:
  for (NSString *key in args.allKeys) {
    result[key] = args[key];
  }
  
  return result;
}

- (int)_parseArgs:(int) argc argv:(char **) argv {
  optind = 1;

  NSMutableDictionary *args = [[NSMutableDictionary alloc] init];
  [args setObject:@(SSH_LOG_NONE) forKey:SSHOptionLogLevel];
  NSMutableArray<NSString *> *options = [[NSMutableArray alloc] init];
  
  while (1) {
    int c = getopt(argc, argv, "o:CGp:i:hTtvl:F:");
    if (c == -1) {
      break;
    }

    switch (c) {
      case 'p':
        [args setObject:[self _tryParsePort:optarg] forKey:SSHOptionPort];
        break;
      case 'C':
        [args setObject:SSHOptionValueYES forKey:SSHOptionCompression];
        break;
      case 'v':
        [args setObject:@(MIN([_options[SSHOptionLogLevel] intValue] + 1, SSH_LOG_TRACE)) forKey:SSHOptionLogLevel];
        break;
      case 'i':
        [args setObject:@(optarg) forKey:SSHOptionIdentityFile];
        break;
      case 't':
        [args setObject:SSHOptionValueYES forKey:SSHOptionRequestTTY];
        break;
      case 'T':
        [args setObject:SSHOptionValueNO forKey:SSHOptionRequestTTY];
        break;
      case 'l':
        [args setObject:@(optarg) forKey:SSHOptionUser];
        break;
      case 'F':
        [args setObject:@(optarg) forKey:SSHOptionConfigFile];
        break;
      case 'o':
        // Will apply later
        [options addObject:@(optarg)];
        break;
      case 'G':
        [args setObject:SSHOptionValueYES forKey:SSHOptionPrintConfiguration];
        break;
      default:
        return [self _printUsageWithCode:SSH_ERROR];
    }
  }
  
  if (optind < argc) {
    NSArray *userAtHost = [@(argv[optind++]) componentsSeparatedByString:@"@"];
    
    if ([userAtHost count] < 2) {
      [args setObject:userAtHost[0] forKey:SSHOptionHostName];
    } else {
      [args setObject:userAtHost[0] forKey:SSHOptionUser];
      [args setObject:userAtHost[1] forKey:SSHOptionHostName];
    }

    BKHosts *savedHost = [BKHosts withHost:args[SSHOptionHostName]];
    if (savedHost) {
      if (savedHost.hostName) {
        args[SSHOptionHostName] = savedHost.hostName;
      }
      if (!args[SSHOptionPort] && savedHost.port) {
        args[SSHOptionPort] = savedHost.port;
      }
      if (!args[SSHOptionUser] && savedHost.user) {
        args[SSHOptionUser] = savedHost.user;
      }
      if (!args[SSHOptionIdentityFile] && savedHost.key) {
        args[SSHOptionIdentityFile] = savedHost.key;
      }
      if (savedHost.password) {
        args[SSHOptionPassword] = savedHost.password;
      }
    }
  }
  
  NSMutableArray *cmds = [[NSMutableArray alloc] init];
  while (optind < argc) {
    [cmds addObject:[NSString stringWithUTF8String:argv[optind++]]];
  }
  
  if (cmds.count > 0) {
    args[SSHOptionRemoteCommand] = [cmds componentsJoinedByString:@" "];
  }
  
  if (args[SSHOptionHostName] == NULL) {
    return [self _printUsageWithCode:SSH_ERROR];
  }
  _options = [self _applyOptions:options toArgs:args];
  
  return SSH_OK;
}

- (int)_printUsageWithCode:(int) code {
  NSString *usage = [@[
                       @"usage: ssh2 [-CGTtv]",
                       @"            [-F configFile] [-i identity_file]",
                       @"            [-l login_name] [-o option]",
                       @"            [-p port] [-L address] [-R address]",
                       @"            [user@]hostname [command]",
                       @""
                      ] componentsJoinedByString:@"\n"];
  dispatch_write_utf8string(_fdOut, usage, _mainQueue, ^(dispatch_data_t  _Nullable data, int error) {
    [self _exitWithCode:code];
  });
  return code;
}

- (int)_applySSHOptionKey:(const NSString *)optionKey withOption:(enum ssh_options_e) option {
  id value = _options[optionKey];
  if (!value) {
    return SSH_OK;
  }
  
  if ([value isKindOfClass:[NSNumber class]]) {
    int v = [value intValue];
    return ssh_options_set(_ssh_session, option, &v);
  } else if ([value isKindOfClass:[NSString class]]) {
    const char *v = [value UTF8String];
    return ssh_options_set(_ssh_session, option, v);
  }
  
  return SSH_ERROR;
}

- (void)_ssh_createAndConfigureSession {
  _ssh_session = ssh_new();
  
//  ssh_set_blocking(_ssh_session, 0);
  [self _applySSHOptionKey:SSHOptionConnectTimeout withOption:SSH_OPTIONS_TIMEOUT];
  [self _applySSHOptionKey:SSHOptionCompression withOption:SSH_OPTIONS_COMPRESSION];
  [self _applySSHOptionKey:SSHOptionHostName withOption:SSH_OPTIONS_HOST];
  [self _applySSHOptionKey:SSHOptionUser withOption:SSH_OPTIONS_USER];
  [self _applySSHOptionKey:SSHOptionPort withOption:SSH_OPTIONS_PORT];
  [self _applySSHOptionKey:SSHOptionConnectTimeout withOption:SSH_OPTIONS_TIMEOUT];
  ssh_options_set(_ssh_session, SSH_OPTIONS_SSH_DIR, BlinkPaths.ssh.UTF8String);
  
  NSString *configFile = _options[SSHOptionConfigFile];
  ssh_options_parse_config(_ssh_session, configFile.UTF8String);
}

- (void)_printConfiguration {
  NSMutableArray<NSString *> *lines = [[NSMutableArray alloc] initWithCapacity:_options.count];
  
  NSArray<NSString *> *sortedKeys = [_options.allKeys sortedArrayUsingSelector:@selector(compare:)];
  for (NSString *key in sortedKeys) {
    [lines addObject:[NSString stringWithFormat:@"%@ %@", key, _options[key]]];
  }
  [lines addObject:@""];
  
  dispatch_write_utf8string(_fdOut, [lines componentsJoinedByString:@"\n"], _mainQueue, ^(dispatch_data_t _Nullable data, int error) {
    [self _exitWithCode:SSH_OK];
  });
}

- (void)_ssh_connect {
  int rc = ssh_connect(_ssh_session);
  dispatch_fd_t socketFd = ssh_get_fd(_ssh_session);
  dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, socketFd, 0, _mainQueue);
  dispatch_source_set_event_handler(source, ^{
    NSLog(@"here");
  });
  dispatch_resume(source);
}

- (int)main:(int) argc argv:(char **) argv {
  
  int rc = [self _parseArgs:argc argv: argv];
  if (rc != SSH_OK) {
    return [self _exitWithCode:rc];
  }
  
  dispatch_async(_mainQueue, ^{
    [self _ssh_createAndConfigureSession];
    
    if ([_options[SSHOptionPrintConfiguration] isEqual:SSHOptionValueYES]) {
      [self _printConfiguration];
      return;
    }
    
    [self _ssh_connect];
  });
  
  dispatch_semaphore_wait(_mainDsema, DISPATCH_TIME_FOREVER);
  return _exitCode;
}

@end
