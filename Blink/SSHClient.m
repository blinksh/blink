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
#import "SSHClientChannel.h"

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
  
  if (!data) {
    dispatch_async(queue, ^{
      handler(nil, 1);
    });
    return;
  }
  
  dispatch_write(fd, data, queue, handler);
}

void dispatch_write_ssh_chars(dispatch_fd_t fd,
                               char *buffer,
                               dispatch_queue_t queue) {
  if (buffer == NULL) {
    return;
  }
  dispatch_data_t data = dispatch_data_create(buffer, strlen(buffer), queue, ^{ ssh_string_free_char(buffer); });
  
  if (!data) {
    return;
  }
  
  dispatch_write(fd, data, queue, ^(dispatch_data_t _Nullable data, int error) {});
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

NSMutableArray<NSNumber *> *__ssh_userauth_list(ssh_session session) {
  NSMutableArray *result = [[NSMutableArray alloc] init];
  
  int methods = ssh_userauth_list(session, NULL);
  
  if (methods & SSH_AUTH_METHOD_PUBLICKEY) {
    [result addObject:@(SSH_AUTH_METHOD_PUBLICKEY)];
  }
  
  if (methods & SSH_AUTH_METHOD_HOSTBASED) {
    [result addObject:@(SSH_AUTH_METHOD_HOSTBASED)];
  }
  
  if (methods & SSH_AUTH_METHOD_INTERACTIVE) {
    [result addObject:@(SSH_AUTH_METHOD_INTERACTIVE)];
  }
  
  if (methods & SSH_AUTH_METHOD_PASSWORD) {
    [result addObject:@(SSH_AUTH_METHOD_PASSWORD)];
  }
  
  return result;
}

@interface SSHClient (internal) <SSHClientChannelDelegate>
- (int) _ssh_auth_fn_prompt:(const char *)prompt buf:(char *)buf len:(size_t) len echo:(int) echo verify:(int)verify;
@end


int __ssh_auth_fn(const char *prompt, char *buf, size_t len,
                    int echo, int verify, void *userdata) {
  SSHClient *client = (__bridge SSHClient *)userdata;
  return [client _ssh_auth_fn_prompt:prompt buf:buf len:len echo:echo verify:verify];
}

@implementation SSHClient {
  dispatch_queue_t _queue;
  ssh_event _event;
  ssh_session _session;
  NSMutableDictionary *_options;

  dispatch_fd_t _fdIn;
  dispatch_fd_t _fdOut;
  dispatch_fd_t _fdErr;
  
  
  
  SSHClientChannel *_mainChannel;
  
  bool _doExit;
  int _exitCode;
}

- (instancetype)initWithStdIn:(dispatch_fd_t)fdIn stdOut:(dispatch_fd_t)fdOut stdErr:(dispatch_fd_t)fdErr {
  if (self = [super init]) {
    
    _queue = dispatch_queue_create("sh.blink.sshclient", DISPATCH_QUEUE_SERIAL);
    _fdIn = fdIn;
    _fdOut = fdOut;
    _fdErr = fdErr;
    _options = [[NSMutableDictionary alloc] init];
    
    _doExit = NO;
    _exitCode = 0;
  }
  
  return self;
}

- (int)_exitWithCode:(int)code {
  _doExit = YES;
  _exitCode = code;
  return code;
}

- (int)_exitWithCode:(int)code andMessage: (NSString * __nonnull)message {
  dispatch_write_utf8string(_fdErr, [message stringByAppendingString:@"\n"], _queue, ^(dispatch_data_t  _Nullable data, int error) {
    dispatch_sync(_queue, ^{
      [self _exitWithCode:code];
    });
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

- (int) _ssh_auth_fn_prompt:(const char *)prompt buf:(char *)buf len:(size_t) len echo:(int) echo verify:(int)verify {
  return 0;
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
                         SSHOptionIdentityFile: @[identityfileType, @[@"id_rsa", /* id_dsa, id_ecdsa, id_ed25519 */]],
                         SSHOptionStrictHostKeyChecking: @[yesNoAskType, @"ask"],
                         SSHOptionCompression: @[yesNoType, @"yes"] // We mobile terminal, so we set compression to yes by default.
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

- (int)_parseArgs:(int) argc argv:(char **) argv {
  optind = 1;

  NSMutableDictionary *args = [[NSMutableDictionary alloc] init];
  [args setObject:@(SSH_LOG_NONE) forKey:SSHOptionLogLevel];
  NSMutableArray<NSString *> *options = [[NSMutableArray alloc] init];
  NSMutableArray<NSString *> *identityfiles = [[NSMutableArray alloc] init];
  
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
  dispatch_write_utf8string(_fdOut, usage, _queue, ^(dispatch_data_t  _Nullable data, int error) {
    [self _exitWithCode:code];
  });
  return code;
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
      args[SSHOptionIdentityFile] = savedHost.key;
    }
    if (savedHost.password) {
      args[SSHOptionPassword] = savedHost.password;
    }
  }
}

- (int)_applySSHOptionKey:(const NSString *)optionKey withOption:(enum ssh_options_e) option {
  id value = _options[optionKey];
  if (!value) {
    return SSH_OK;
  }
  
  if ([value isKindOfClass:[NSNumber class]]) {
    int v = [value intValue];
    return ssh_options_set(_session, option, &v);
  } else if ([value isKindOfClass:[NSString class]]) {
    const char *v = [value UTF8String];
    return ssh_options_set(_session, option, v);
  }
  
  return SSH_ERROR;
}

- (void)_ssh_createAndConfigureSession {
  _session = ssh_new();
  _event = ssh_event_new();
  
  [self _applySSHOptionKey:SSHOptionConnectTimeout withOption:SSH_OPTIONS_TIMEOUT];
  [self _applySSHOptionKey:SSHOptionCompression withOption:SSH_OPTIONS_COMPRESSION];
  [self _applySSHOptionKey:SSHOptionHostName withOption:SSH_OPTIONS_HOST];
  [self _applySSHOptionKey:SSHOptionUser withOption:SSH_OPTIONS_USER];
  [self _applySSHOptionKey:SSHOptionPort withOption:SSH_OPTIONS_PORT];
  [self _applySSHOptionKey:SSHOptionConnectTimeout withOption:SSH_OPTIONS_TIMEOUT];
  ssh_options_set(_session, SSH_OPTIONS_SSH_DIR, BlinkPaths.ssh.UTF8String);
  
  NSString *configFile = _options[SSHOptionConfigFile];
  ssh_options_parse_config(_session, configFile.UTF8String);
}

- (void)_printConfiguration {
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
  
  dispatch_write_utf8string(_fdOut, [lines componentsJoinedByString:@"\n"], _queue, ^(dispatch_data_t _Nullable data, int error) {
    [self _exitWithCode:SSH_OK];
  });
}

- (int)_do_poll {
  int rc = SSH_AGAIN;
  do {
    rc = ssh_event_dopoll(_event, -1);
  } while (rc == SSH_AGAIN);
  return rc;
}

- (int)_start_connect_flow {
  __block int rc = SSH_ERROR;
  dispatch_block_t connect_block = ^{
    rc = ssh_connect(_session);
  };
  
  dispatch_sync(_queue, ^{
    ssh_set_blocking(_session, 0);
    _event = ssh_event_new();
    connect_block();
    ssh_event_add_session(_event, _session);
    if (ssh_event_add_session(_event, _session) == SSH_ERROR) {
      rc = SSH_ERROR;
    }
  });
  
  if (rc == SSH_ERROR) {
    return rc;
  }
  
  dispatch_async(dispatch_get_global_queue(0, 0), ^{
    // connect
    for(;;) {
      switch(rc) {
        case SSH_AGAIN: {
          dispatch_sync(_queue, connect_block);
          continue;
        }
        case SSH_OK:
          [self _auth];
        case SSH_ERROR:
        default:
          return;
      }
    }
  });
  
  return rc;
}

- (void)_auth {
  __block int rc = SSH_ERROR;
  dispatch_block_t auth_block = ^{
    rc = ssh_userauth_none(_session, NULL);
  };
  
  dispatch_async(dispatch_get_global_queue(0, 0), ^{
    // 1. pre auth
    for (;;) {
      dispatch_sync(_queue, auth_block);
      switch (rc) {
        case SSH_AUTH_PARTIAL:
        case SSH_AUTH_DENIED: break;
        case SSH_AUTH_AGAIN: continue;
        default:
        case SSH_AUTH_ERROR:
          [self _exitWithCode:rc];
          return;
      }
      break;
    }
    
    // 2. print issue banner if any
    dispatch_sync(_queue, ^{
      dispatch_write_ssh_chars(_fdOut, ssh_get_issue_banner(_session), _queue);
    });
    
    // 3. get auth methods from server
    __block int methods;
    dispatch_sync(_queue, ^{
      methods = ssh_userauth_list(_session, NULL);
    });
    
    // 4. public key first
    if (methods & SSH_AUTH_METHOD_PUBLICKEY) {
      NSArray<NSString *> *identityfiles = _options[SSHOptionIdentityFile];
      for (NSString *identityfile in identityfiles) {
        __block ssh_key pkey;
        dispatch_sync(_queue, ^{
          BKPubKey *secureKey = [BKPubKey withID:identityfile];
          // we have this identity in
          if (secureKey) {
            rc = ssh_pki_import_privkey_base64(secureKey.privateKey.UTF8String,
                                               NULL, /* TODO: get stored */
                                               __ssh_auth_fn,
                                               (__bridge void *) self,
                                               &pkey);
          } else {
            rc = ssh_pki_import_privkey_file(identityfile.UTF8String,
                                             NULL,
                                             __ssh_auth_fn,
                                             (__bridge void *) self,
                                             &pkey);
          }
        });
        if (rc == SSH_ERROR) {
          continue;
        }
        NSString *user = _options[SSHOptionUser];
        dispatch_block_t auth_block = ^{
          rc = ssh_userauth_publickey(_session, user.UTF8String, pkey);
        };
        bool tryNextIdentityFile = NO;
        for (;;) {
          dispatch_sync(_queue, auth_block);
          switch (rc) {
            case SSH_AUTH_AGAIN: continue;
            case SSH_AUTH_SUCCESS:
              return;
            case SSH_AUTH_DENIED:
            case SSH_AUTH_PARTIAL:
              tryNextIdentityFile = YES;
              break;
            default:
              break;
          }
          break;
        }
        if (tryNextIdentityFile) {
          continue;
        }
        break;
      }
    }
    
  });
}


- (dispatch_block_t)_ssh_interactiveEventhandler {
  return ^{
    int rc = ssh_userauth_kbdint(_session, NULL, NULL);
    switch (rc) {
      case SSH_AUTH_AGAIN:
        return;
      case SSH_AUTH_INFO: {
        const char *nameChars = ssh_userauth_kbdint_getname(_session);
        const char *instructionChars = ssh_userauth_kbdint_getinstruction(_session);
        
        NSString *name = nameChars ? @(nameChars) : nil;
        NSString *instruction = instructionChars ? @(instructionChars) : nil;
        
        int nprompts = ssh_userauth_kbdint_getnprompts(_session);
        if (nprompts >= 0) {
          NSMutableArray *prompts = [[NSMutableArray alloc] initWithCapacity:nprompts];
          for (int i = 0; i < nprompts; i++) {
            char echo = NO;
            const char *prompt = ssh_userauth_kbdint_getprompt(_session, i, &echo);
            
            [prompts addObject:@[prompt == NULL ? @"" : @(prompt), @(echo)]];
          }
          
          NSArray * answers = [self _getAnswersWithName:name instruction:instruction andPrompts:prompts];
          
          for (int i = 0; i < answers.count; i++) {
            int rc = ssh_userauth_kbdint_setanswer(_session, i, [answers[i] UTF8String]);
            if (rc < 0) {
              break;
            }
          }
        }
        
        rc = ssh_userauth_kbdint(_session, NULL, NULL);
      }
        break;
      case SSH_AUTH_SUCCESS:
        return [self _ssh_authenticated];
      default:
        break;
    }
  };
}

- (NSArray<NSString *>*)_getAnswersWithName:(NSString *)name instruction: (NSString *)instruction andPrompts:(NSArray *)prompts {
  NSMutableArray<NSString *> *answers = [[NSMutableArray alloc] init];
  for (int i = 0; i < prompts.count; i++) {
    dispatch_write_utf8string(_fdOut, prompts[i][0], dispatch_get_global_queue(0, 0), ^(dispatch_data_t  _Nullable data, int error) {
    });
    FILE *fp = fdopen(_fdIn, "r");
    char * line = NULL;
    size_t len = 0;
    ssize_t read = getline(&line, &len, fp);
    
    if (read != -1) {
      
    } else {
      
    }
    
    if (line) {
      NSString * lineStr = [@(line) stringByReplacingOccurrencesOfString:@"\n" withString:@""];
      [answers addObject:lineStr];
      free(line);
    }
    fclose(fp);
  }
  return answers;
}

- (void)_ssh_authenticated {
  NSLog(@"Authenticated");
  
//  dispatch_source_t channel_source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, _fdSessionSock, 0, _mainQueue);
//  ssh_channel channel = ssh_channel_new(_ssh_session);
//  _mainChannel = [[SSHClientChannel alloc] initWithDispatchSource:channel_source andChannel:channel];
//  _mainChannel.delegate = self;
//  [_mainChannel open];
  
}
  

- (int)main:(int) argc argv:(char **) argv {
  __block int rc = [self _parseArgs:argc argv: argv];

  if (rc != SSH_OK) {
    return [self _exitWithCode:rc];
  }
  
  [self _ssh_createAndConfigureSession];
  
  if ([_options[SSHOptionPrintConfiguration] isEqual:SSHOptionValueYES]) {
    [self _printConfiguration];
    return [self _exitWithCode:SSH_OK];
  }
  
  if ([self _start_connect_flow] == SSH_ERROR) {
    return [self _exitWithCode:SSH_ERROR];
  }
  
  dispatch_block_t poll_block = ^{
    rc = ssh_event_dopoll(_event, 2000);
  };

  while (!_doExit) {
    dispatch_sync(_queue, poll_block);
    if (rc == SSH_ERROR) {
      break;
    }
  };
  
  return _exitCode;
}

@end
