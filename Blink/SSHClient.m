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
#import "BKHosts.h"
#import "BKPubKey.h"
#import "SSHClientOptions.h"
#import "SSHClientChannel.h"

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
  
  SSHClientOptions *_options;

  ssh_event _event;
  ssh_session _session;
  ssh_channel _channel;

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
    _options = [[SSHClientOptions alloc] init];
    
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

- (int)_exitWithCode:(int)code andMessage: (NSString *)message {
  _exitCode = code;
  if (message == nil) {
    return _exitCode;
  }
  message = [message stringByAppendingString:@"\n"];
  write(_fdErr, message.UTF8String, [message lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
  return _exitCode;
}


- (int) _ssh_auth_fn_prompt:(const char *)prompt buf:(char *)buf len:(size_t) len echo:(int) echo verify:(int)verify {
  return 0;
}

- (void)_printVersion {
  ssh_session s = ssh_new();
  int v = ssh_get_openssh_version(s);
  NSArray<NSString *> *lines = @[
                                 [NSString stringWithFormat:@"%@", @(v)],
                                 @"",
                                 ];
  
  NSString *message = [lines componentsJoinedByString:@"\n"];
  [self _exitWithCode:SSH_OK andMessage:message];
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
              [self _open_channels];
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
    
    // 5. interactive
    if (methods & SSH_AUTH_METHOD_INTERACTIVE) {
      for (;;) {
        dispatch_sync(_queue, ^{
          rc = ssh_userauth_kbdint(_session, NULL, NULL);
        });
        
        switch (rc) {
          case SSH_AUTH_AGAIN: continue;
          case SSH_AUTH_INFO: {
            dispatch_sync(_queue, ^{
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
            });
          }
          break;
          case SSH_AUTH_SUCCESS:
            [self _open_channels];
          default:
            return;
        }
      }
    }
    
  });
}

- (void)_open_channels {
  dispatch_async(dispatch_get_global_queue(0, 0), ^{
    __block int rc;
    dispatch_sync(_queue, ^{
      _channel = ssh_channel_new(_session);
      ssh_channel_set_blocking(_channel, 0);
    });
    
    
    for (;;) {
      dispatch_sync(_queue, ^{
        rc = ssh_channel_open_session(_channel);
      });
      switch (rc) {
        case SSH_AGAIN: continue;
        case SSH_OK: break;
        default:
        case SSH_ERROR:
          // this is main channel. So we exit if we fail here
          [self _exitWithCode:rc];
          return;
      }
      break;
    }
    
    for (;;) {
      dispatch_sync(_queue, ^{
        rc = ssh_channel_request_pty(_channel);
      });
      switch (rc) {
        case SSH_AGAIN: continue;
        case SSH_OK: break;
        default:
        case SSH_ERROR:
          // this is main channel. So we exit if we fail here
          [self _exitWithCode:rc];
          return;
      }
      break;
    }
    
    for (;;) {
      dispatch_sync(_queue, ^{
        rc = ssh_channel_request_shell(_channel);
      });
      switch (rc) {
        case SSH_AGAIN: continue;
        case SSH_OK: break;
        default:
        case SSH_ERROR:
          // this is main channel. So we exit if we fail here
          [self _exitWithCode:rc];
          return;
      }
      break;
    }
    
    __block ssh_connector connector_in, connector_out, connector_err;
    
    dispatch_sync(_queue, ^{
      // stdin
      connector_in = ssh_connector_new(_session);
      ssh_connector_set_in_fd(connector_in, _fdIn);
      ssh_connector_set_out_channel(connector_in, _channel, SSH_CONNECTOR_STDOUT);
      ssh_event_add_connector(_event, connector_in);
      
      // stdout
      connector_out = ssh_connector_new(_session);
      ssh_connector_set_in_channel(connector_out, _channel, SSH_CONNECTOR_STDOUT);
      ssh_connector_set_out_fd(connector_out, _fdOut);
      ssh_event_add_connector(_event, connector_out);
      
      // stderr
      connector_err = ssh_connector_new(_session);
      ssh_connector_set_in_channel(connector_err, _channel, SSH_CONNECTOR_STDERR);
      ssh_connector_set_out_fd(connector_err, _fdErr);
      ssh_event_add_connector(_event, connector_err);
    });
    
//    sleep(10000);
  });
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
//    fclose(fp);
  }
  return answers;
}

- (void)_ssh_authenticated {
  NSLog(@"Authenticated");
}
  

- (int)main:(int) argc argv:(char **) argv {
  __block int rc = [_options parseArgs:argc argv: argv];

  if (rc != SSH_OK) {
    return [self _exitWithCode:rc andMessage:_options.exitMessage];
  }
  
  if ([_options[SSHOptionPrintVersion] isEqual:SSHOptionValueYES]) {
    [self _printVersion];
    return [self _exitWithCode:SSH_OK];
  }
  
  _session = ssh_new();
  _event = ssh_event_new();
  
  rc = [_options configureSSHSession:_session];
  if (rc != SSH_OK) {
    return [self _exitWithCode:rc andMessage:_options.exitMessage];
  }
  
  if ([_options[SSHOptionPrintConfiguration] isEqual:SSHOptionValueYES]) {
      dispatch_write_utf8string(_fdOut, [_options configurationAsText], _queue, ^(dispatch_data_t _Nullable data, int error) {});
    return [self _exitWithCode:SSH_OK];
  }
  
  if ([self _start_connect_flow] == SSH_ERROR) {
    return [self _exitWithCode:SSH_ERROR];
  }
  
  dispatch_block_t poll_block = ^{
    rc = ssh_event_dopoll(_event, 500);
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
