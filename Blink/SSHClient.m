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
#import "BKDefaults.h"
#import "BKHosts.h"
#import "BKPubKey.h"

#include <getopt.h>
#include <libssh/libssh.h>
#include <libssh/callbacks.h>

void dispatch_write_string(dispatch_fd_t fd,
               NSString * _Nonnull string,
               dispatch_queue_t queue,
               void (^handler)(dispatch_data_t _Nullable data, int error))
{
  dispatch_data_t data = (dispatch_data_t)[string dataUsingEncoding:NSUTF8StringEncoding];
  if (!data) {
    dispatch_async(queue, ^{
      handler(nil, 1);
    });
    return;
  }
  dispatch_write(fd, data, queue, handler);
}


const NSString * SSHOptionStrictHostKeyChecking = @"stricthostheychecking";
const NSString * SSHOptionHostName =  @"hostname";
const NSString * SSHOptionPort =  @"port"; // -p
const NSString * SSHOptionLogLevel =  @"loglevel"; // -v
const NSString * SSHOptionIdentityFile = @"identityfile"; // -i
const NSString * SSHOptionRequestTTY = @"requesttty"; // -tT
const NSString * SSHOptionUser = @"user"; // -l
const NSString * SSHOptionProxyCommand = @"proxycommand"; // ?
const NSString * SSHOptionConfigFile = @"configfile"; // -F

const NSString * SSHOptionValueYES = @"yes";
const NSString * SSHOptionValueNO = @"no";
const NSString * SSHOptionValueAUTO = @"auto";
const NSString * SSHOptionValueANY = @"any";

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

- (void)_initSSH {
  _ssh_session = ssh_new();
}

- (int)_exitWithCode:(int)code {
  _exitCode = code;
  dispatch_semaphore_signal(_mainDsema);
  return _exitCode;
}

- (int)_exitWithCode:(int)code andMessage: (NSString * __nonnull)message {
  dispatch_write_string(_fdErr, message, _mainQueue, ^(dispatch_data_t  _Nullable data, int error) {
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

- (int)_parseArgs:(int) argc argv:(char **) argv {
  int rc = SSH_ERROR;
  
  // Options
  // port -p
  // verbose --verbose
  // command (Obtain data at the end)
  // tty -t
  // key -i identity file
  // forced password
  optind = 1;
  int port = 0;
  
  // Defaults
//  [_options setObject:@(YES) forKey:SSHOptionStrictHostKeyChecking];
//  [_options setObject:@(SSH_LOG_NONE) forKey:SSHOptionLogLevel];
//  NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
  NSMutableDictionary *args = [[NSMutableDictionary alloc] init];
  [args setObject:@(SSH_LOG_NONE) forKey:SSHOptionLogLevel];
  NSMutableArray<NSString *> *options = [[NSMutableArray alloc] init];
  
  while (1) {
    int c = getopt(argc, argv, "p:i:hTtvl:F:");
    if (c == -1) {
      break;
    }

    switch (c) {
      case 'p':
        [args setObject:[self _tryParsePort:optarg] forKey:SSHOptionPort];
        break;
//      case 'h':
//        [_options setObject:@(NO) forKey:SSHOptionStrictHostKeyChecking];
//        break;
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
        [_options setObject:@(optarg) forKey:SSHOptionProxyCommand];
        break;
      default:
        return __usage();
    }
  }
  
  if (optind < argc) {
    BKHosts *savedHost;
    NSArray *userAtHost = [[NSString stringWithFormat:@"%s", argv[optind++]]
                           componentsSeparatedByString:@"@"];
    
    if ([userAtHost count] < 2) {
      [args setObject:userAtHost[0] forKey:SSHOptionHostName];
    } else {
      [args setObject:userAtHost[0] forKey:SSHOptionUser];
      [args setObject:userAtHost[1] forKey:SSHOptionHostName];
    }
    
    if ((savedHost = [BKHosts withHost:[NSString stringWithFormat:@"%s", options->hostname]])) {
      options->hostname = savedHost.hostName ? [savedHost.hostName UTF8String] : options->hostname;
      options->port = options->port ? options->port : [savedHost.port intValue];
      if (!options->user && [savedHost.user length]) {
        options->user = [savedHost.user UTF8String];
      }
      options->identity_file = options->identity_file ? options->identity_file : [savedHost.key UTF8String];
      options->password = savedHost.password ? [savedHost.password UTF8String] : NULL;
    }
  }
  
  NSMutableArray *cmds = [[NSMutableArray alloc] init];
  while (optind < argc) {
    [cmds addObject:[NSString stringWithUTF8String:argv[optind++]]];
  }
  
  if (cmds.count > 0) {
    options->command = [cmds componentsJoinedByString:@" "].UTF8String;
  } else {
    options->request_tty = ios_isatty(fileno(thread_stdout));
  }
  
  if (options->hostname == NULL) {
    return __usage();
  }
  
  return 0;
  
  rc = SSH_OK;
  return rc;
}


- (int)main:(int) argc argv:(char **) argv {
  int rc = [self _parseArgs:argc, argv: argv];
  if (rc != SSH_OK) {
    return [self _exitWithCode:rc];
  }
  
  dispatch_async(_mainQueue, ^{
    [self _initSSH];
  });
  
  dispatch_semaphore_wait(_mainDsema, 0);
  return _exitCode;
}

@end
