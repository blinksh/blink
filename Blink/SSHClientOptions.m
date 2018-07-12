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


#import "SSHClientOptions.h"
#import "BlinkPaths.h"
#import "BKDefaults.h"
#import "BKHosts.h"
#import "BKPubKey.h"
#include <getopt.h>

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
const NSString * SSHOptionLocalForward = @"localforward"; // -L
const NSString * SSHOptionRemoteForward = @"remoteforward"; // -R
const NSString * SSHOptionForwardAgent = @"forwardagent"; // -a -A
const NSString * SSHOptionForwardX11 = @"forwardx11"; // -x -X


// Non standart
const NSString * SSHOptionPassword = @"_password"; //
const NSString * SSHOptionPrintConfiguration = @"_printconfiguration"; // -G
const NSString * SSHOptionPrintVersion = @"_printversion"; // -V

const NSString * SSHOptionValueYES = @"yes";
const NSString * SSHOptionValueNO = @"no";
const NSString * SSHOptionValueASK = @"ask";
const NSString * SSHOptionValueAUTO = @"auto";
const NSString * SSHOptionValueANY = @"any";
const NSString * SSHOptionValueNONE = @"none";

const NSString * SSHOptionValueINFO = @"info";
const NSString * SSHOptionValueERROR = @"error";
const NSString * SSHOptionValueDEBUG = @"debug";
const NSString * SSHOptionValueDEBUG1 = @"debug1";
const NSString * SSHOptionValueDEBUG2 = @"debug2";
const NSString * SSHOptionValueDEBUG3 = @"debug3";


@implementation SSHClientOptions {
  NSMutableDictionary *_options;
  int _exitCode;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _options = [[NSMutableDictionary alloc] init];
    _exitCode = SSH_OK;
  }
  
  return self;
}

- (int)_exitWithCode:(int)code andMessage:(NSString *)message {
  _exitCode = code;
  _exitMessage = message;
  return code;
}

- (NSMutableDictionary *)_applyOptions:(NSArray *)options toArgs:(NSDictionary *)args {
  
  NSObject *stringType = [[NSObject alloc] init];
  NSObject *yesNoType = [[NSObject alloc] init];
  NSObject *yesNoAutoType = [[NSObject alloc] init];
  NSObject *yesNoAskType = [[NSObject alloc] init];
  NSObject *portType = [[NSObject alloc] init];
  NSObject *intType = [[NSObject alloc] init];
  NSObject *intNoneType = [[NSObject alloc] init];
  NSObject *identityfileType = [[NSObject alloc] init];
  NSObject *localforwardType = [[NSObject alloc] init];
  NSObject *remoteforwardType = [[NSObject alloc] init];
  
  NSDictionary *opts = @{
                         SSHOptionUser: @[stringType],
                         SSHOptionHostName: @[stringType],
                         SSHOptionPort: @[portType, @(22)],
                         SSHOptionRequestTTY: @[yesNoAutoType, SSHOptionValueAUTO],
                         SSHOptionTCPKeepAlive: @[yesNoType, SSHOptionValueYES],
                         SSHOptionConnectionAttempts: @[intType, @(1)],
                         SSHOptionNumberOfPasswordPrompts: @[intType, @(3)],
                         SSHOptionServerLiveCountMax: @[intType, @(3)],
                         SSHOptionServerLiveInterval: @[intType, @(0)],
                         SSHOptionRemoteCommand: @[stringType],
                         SSHOptionConnectTimeout: @[intType, SSHOptionValueNONE],
                         SSHOptionIdentityFile: @[identityfileType, @[@"id_rsa", /* id_dsa, id_ecdsa, id_ed25519 */]],
                         SSHOptionLocalForward: @[localforwardType],
                         SSHOptionRemoteForward: @[remoteforwardType],
                         SSHOptionProxyCommand: @[stringType],
                         SSHOptionForwardAgent: @[yesNoType, SSHOptionValueNO],
                         SSHOptionForwardX11: @[yesNoType, SSHOptionValueNO],
                         SSHOptionStrictHostKeyChecking: @[yesNoAskType, SSHOptionValueASK],
                         SSHOptionCompression: @[yesNoType, SSHOptionValueYES] // We mobile terminal, so we set compression to yes by default.
                         };
  
  NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
  
  // Set defaults:
  for (NSString *key in opts.allKeys) {
    NSArray *vals = opts[key];
    if (vals.count >= 2) {
      result[key] = vals[1];
    }
  }
  
  NSMutableArray<NSString *> *identityfileOption = [[NSMutableArray alloc] init];
  NSMutableArray<NSString *> *localforwardOption = [[NSMutableArray alloc] init];
  NSMutableArray<NSString *> *remoteforwardOption = [[NSMutableArray alloc] init];
  
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
    } else if (type == identityfileType) {
      [identityfileOption addObject:value];
    } else if (type == localforwardType) {
      [localforwardOption addObject:value];
    } else if (type == remoteforwardType) {
      [remoteforwardOption addObject:value];
    } else if (type == yesNoType) {
      if ([@[SSHOptionValueYES, SSHOptionValueNO] indexOfObject:lv] == NSNotFound) {
        [self _exitWithCode:SSH_ERROR andMessage:[NSString stringWithFormat:@"unsupported option \"%@\".", key]];
        return result;
      }
      result[key] = lv;
    } else if (type == yesNoAutoType) {
      if ([@[SSHOptionValueYES, SSHOptionValueNO, SSHOptionValueAUTO] indexOfObject:lv] == NSNotFound) {
        [self _exitWithCode:SSH_ERROR andMessage:[NSString stringWithFormat:@"unsupported option \"%@\".", key]];
        return result;
      }
      result[key] = lv;
    } else if (type == yesNoAskType) {
      if ([@[SSHOptionValueYES, SSHOptionValueNO, SSHOptionValueASK] indexOfObject:lv] == NSNotFound) {
        [self _exitWithCode:SSH_ERROR andMessage:[NSString stringWithFormat:@"unsupported option \"%@\".", key]];
        return result;
      }
      result[key] = lv;
    } else if (type == intNoneType) {
      if ([SSHOptionValueNONE isEqualToString:lv]) {
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
  NSMutableArray *argsKeys = [args.allKeys mutableCopy];
  NSMutableArray *identityfileInArgs = args[SSHOptionIdentityFile];
  
  if (identityfileInArgs) {
    [identityfileInArgs addObjectsFromArray:identityfileOption];
  } else if (identityfileOption.count > 0) {
    identityfileInArgs = identityfileInArgs;
  }
  if (identityfileInArgs.count > 0) {
    result[SSHOptionIdentityFile] = [NSOrderedSet orderedSetWithArray:identityfileInArgs].array;
    [argsKeys removeObject:SSHOptionIdentityFile];
  }
  
  for (NSString *key in argsKeys) {
    result[key] = args[key];
  }
  
  return result;
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

- (int)parseArgs:(int) argc argv:(char **) argv {
  optind = 1;
  
  NSMutableDictionary *args = [[NSMutableDictionary alloc] init];
  [args setObject:@(SSH_LOG_NONE) forKey:SSHOptionLogLevel];
  NSMutableArray<NSString *> *options = [[NSMutableArray alloc] init];
  NSMutableArray<NSString *> *localforward = [[NSMutableArray alloc] init];
  NSMutableArray<NSString *> *remoteforward = [[NSMutableArray alloc] init];
  NSMutableArray<NSString *> *identityfiles = [[NSMutableArray alloc] init];
  BOOL quite = NO;
  
  while (1) {
    int c = getopt(argc, argv, "axR:L:Vo:CGp:i:hTtvl:F:");
    if (c == -1) {
      break;
    }
    
    switch (c) {
      case 'a':
        [args setObject:SSHOptionValueNO forKey:SSHOptionForwardAgent];
        break;
      case 'x':
        [args setObject:SSHOptionValueNO forKey:SSHOptionForwardX11];
        break;
      case 'p':
        [args setObject:[self _tryParsePort:optarg] forKey:SSHOptionPort];
        break;
      case 'C':
        [args setObject:SSHOptionValueYES forKey:SSHOptionCompression];
        break;
      case 'v':
        [args setObject:@(MIN([_options[SSHOptionLogLevel] intValue] + 1, SSH_LOG_TRACE)) forKey:SSHOptionLogLevel];
        break;
      case 'q':
        quite = YES;
        break;
      case 'i':
        [identityfiles addObject:@(optarg)];
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
      case 'L':
        [localforward addObject:@(optarg)];
        break;
      case 'R':
        [remoteforward addObject:@(optarg)];
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
      case 'V':
        [args setObject:SSHOptionValueYES forKey:SSHOptionPrintVersion];
        break;
      default:
        return [self _exitWithCode:SSH_ERROR andMessage:[self _usage]];
    }
  }
  
  if (quite) {
    [args setObject:@(SSH_LOG_NONE) forKey:SSHOptionLogLevel];
  }
  
  if (identityfiles.count > 0) {
    args[SSHOptionIdentityFile] = identityfiles;
  }
  
  if (optind < argc) {
    [self _parseUserAtHostStr:@(argv[optind++]) toArgs:args];
  }
  
  NSMutableArray *cmds = [[NSMutableArray alloc] init];
  while (optind < argc) {
    [cmds addObject:[NSString stringWithUTF8String:argv[optind++]]];
  }
  
  if (cmds.count > 0) {
    args[SSHOptionRemoteCommand] = [cmds componentsJoinedByString:@" "];
  }
  
  if (args[SSHOptionHostName] == NULL && args[SSHOptionPrintVersion] == NULL) {
    return [self _exitWithCode:SSH_ERROR andMessage:[self _usage]];;
  }
  
  if (localforward.count > 0) {
    args[SSHOptionLocalForward] = localforward;
  }
  
  if (remoteforward.count > 0) {
    args[SSHOptionRemoteForward] = remoteforward;
  }
  
  _options = [self _applyOptions:options toArgs:args];
  
  return _exitCode;
}

- (int)configureSSHSession:(ssh_session)session {
  [self _applySSH:session optionKey:SSHOptionConnectTimeout withOption:SSH_OPTIONS_TIMEOUT];
  [self _applySSH:session optionKey:SSHOptionCompression withOption:SSH_OPTIONS_COMPRESSION];
  [self _applySSH:session optionKey:SSHOptionHostName withOption:SSH_OPTIONS_HOST];
  [self _applySSH:session optionKey:SSHOptionUser withOption:SSH_OPTIONS_USER];
  [self _applySSH:session optionKey:SSHOptionPort withOption:SSH_OPTIONS_PORT];
  [self _applySSH:session optionKey:SSHOptionConnectTimeout withOption:SSH_OPTIONS_TIMEOUT];
  [self _applySSH:session optionKey:SSHOptionProxyCommand withOption:SSH_OPTIONS_PROXYCOMMAND];
  ssh_options_set(session, SSH_OPTIONS_SSH_DIR, BlinkPaths.ssh.UTF8String);
  
  NSString *configFile = _options[SSHOptionConfigFile];
  return ssh_options_parse_config(session, configFile.UTF8String);
}

- (NSString *)_usage {
  return [@[
     @"usage: ssh2 [-aCGVqTtvx]",
     @"            [-F configFile] [-i identity_file]",
     @"            [-l login_name] [-o option]",
     @"            [-p port] [-L address] [-R address]",
     @"            [user@]hostname [command]",
     @""
  ] componentsJoinedByString:@"\n"];
}

- (void)_parseUserAtHostStr:(NSString *)str toArgs:(NSMutableDictionary *)args {
  NSArray *userAtHost = [str componentsSeparatedByString:@"@"];
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
      args[SSHOptionIdentityFile] = [@[savedHost.key] mutableCopy];
    }
    if (savedHost.password) {
      args[SSHOptionPassword] = savedHost.password;
    }
  }
}

- (int)_applySSH:(ssh_session)session optionKey:(const NSString *)optionKey withOption:(enum ssh_options_e) option {
  id value = _options[optionKey];
  if (!value) {
    return SSH_OK;
  }
  
  if ([value isKindOfClass:[NSNumber class]]) {
    int v = [value intValue];
    return ssh_options_set(session, option, &v);
  } else if ([value isKindOfClass:[NSString class]]) {
    const char *v = [value UTF8String];
    return ssh_options_set(session, option, v);
  }
  
  return SSH_ERROR;
}

- (NSString *)configurationAsText {
  NSMutableArray<NSString *> *lines = [[NSMutableArray alloc] initWithCapacity:_options.count];
  
  NSArray<NSString *> *sortedKeys = [_options.allKeys sortedArrayUsingSelector:@selector(compare:)];
  for (NSString *key in sortedKeys) {
    id val = _options[key];
    if ([val isKindOfClass:[NSArray class]]) {
      NSArray *valArry = (NSArray *)val;
      for (NSObject * v in valArry) {
        [lines addObject:[NSString stringWithFormat:@"%@ %@", key, v]];
      }
    } else {
      [lines addObject:[NSString stringWithFormat:@"%@ %@", key, val]];
    }
  }
  [lines addObject:@""];
  
  return [lines componentsJoinedByString:@"\n"];  
}

- (id)objectForKeyedSubscript:(const NSString *)key {
  return _options[key];
}

@end
