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
#import "SSHClientChannel.h"

#import <pthread.h>
#include <libssh/callbacks.h>

void __write(dispatch_fd_t fd, NSString *message) {
  if (message == nil) {
    return;
  }
  write(fd, message.UTF8String, [message lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
}

void __write_ssh_chars_and_free(dispatch_fd_t fd, char *buffer) {
  if (buffer == NULL) {
    return;
  }
  write(fd, buffer, strlen(buffer));
  ssh_string_free_char(buffer);
}


@interface SSHClient (internal)
- (int) _ssh_auth_fn_prompt:(const char *)prompt buf:(char *)buf len:(size_t) len echo:(int) echo verify:(int)verify;
@end


int __ssh_auth_fn(const char *prompt, char *buf, size_t len,
                    int echo, int verify, void *userdata) {
  SSHClient *client = (__bridge SSHClient *)userdata;
  return [client _ssh_auth_fn_prompt:prompt buf:buf len:len echo:echo verify:verify];
}

@implementation SSHClient {
  NSMutableArray<SSHClientChannel *> *_channels;
  
  bool _doExit;
  int _exitCode;
  pthread_t _thread;
}

- (instancetype)initWithStdIn:(dispatch_fd_t)fdIn stdOut:(dispatch_fd_t)fdOut stdErr:(dispatch_fd_t)fdErr isTTY:(BOOL)isTTY {
  if (self = [super init]) {
    
    _queue = dispatch_queue_create("sh.blink.sshclient", DISPATCH_QUEUE_SERIAL);
    _fdIn = fdIn;
    _fdOut = fdOut;
    _fdErr = fdErr;
    _options = [[SSHClientOptions alloc] init];
    _channels = [[NSMutableArray alloc] init];
    _isTTY = isTTY;
    _thread = pthread_self();
    
    _doExit = NO;
    _exitCode = 0;
  }
  
  return self;
}

- (int)exitWithCode:(int)code {
  _doExit = YES;
  _exitCode = code;
  return code;
}

- (int)_exitWithCode:(int)code andMessage: (NSString *)message {
  if (message == nil) {
    return [self exitWithCode:code];
  }
  message = [message stringByAppendingString:@"\n"];
  __write(_fdErr, message);
  return [self exitWithCode:code];
}

- (void)schedule:(dispatch_block_t)block {
  dispatch_async(_queue, block);
  pthread_kill(_thread, SIGUSR1);
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
  dispatch_sync(_queue, ^{
    _event = ssh_event_new();
    rc = ssh_connect(_session);
    if (rc == SSH_ERROR) {
      return;
    }
    ssh_set_blocking(_session, 0);
    ssh_event_add_session(_event, _session);
    if (ssh_event_add_session(_event, _session) == SSH_ERROR) {
      rc = SSH_ERROR;
      return;
    }
    
    // connect
    for(;;) {
      switch(rc) {
        case SSH_AGAIN:
          rc = ssh_connect(_session);
          [self poll];
          continue;
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
  
  // 1. pre auth
  for (;;) {
    rc = ssh_userauth_none(_session, NULL);
    switch (rc) {
      case SSH_AUTH_AGAIN:
        [self poll];
        continue;
      case SSH_AUTH_PARTIAL:
      case SSH_AUTH_DENIED: break;
      default:
      case SSH_AUTH_ERROR:
        [self exitWithCode:rc];
        return;
    }
    break;
  }
  
  // 2. print issue banner if any
  __write_ssh_chars_and_free(_fdOut, ssh_get_issue_banner(_session));
  
  // 3. get auth methods from server
  int methods = ssh_userauth_list(_session, NULL);
  
  // 4. public key first
  if (methods & SSH_AUTH_METHOD_PUBLICKEY) {
    rc = [self _auth_with_publickey];
    if (rc == SSH_AUTH_SUCCESS) {
      return;
    }
  }
  
  // 5. interactive
  if (methods & SSH_AUTH_METHOD_INTERACTIVE) {
    rc = [self _auth_with_interactive];
    if (rc == SSH_AUTH_SUCCESS) {
      return;
    }
  }

  [self exitWithCode:SSH_ERROR];
}

- (int)_auth_with_publickey {
  __block int rc = SSH_OK;
  NSArray<NSString *> *identityfiles = _options[SSHOptionIdentityFile];
  for (NSString *identityfile in identityfiles) {
    __block ssh_key pkey;
    
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
    if (rc == SSH_ERROR) {
      continue;
    }
    
    NSString *user = _options[SSHOptionUser];
    bool tryNextIdentityFile = NO;
    for (;;) {
      rc = ssh_userauth_publickey(_session, user.UTF8String, pkey);
      switch (rc) {
        case SSH_AUTH_AGAIN:
          [self poll];
          continue;
        case SSH_AUTH_SUCCESS:
          [self _open_channels];
          return rc;
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
  
  return rc;
}

- (int)_auth_with_interactive {
  int rc = SSH_OK;
  for (;;) {
    rc = ssh_userauth_kbdint(_session, NULL, NULL);
    
    switch (rc) {
      case SSH_AUTH_AGAIN:
        [self poll];
        continue;
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
        [self _open_channels];
      default:
        return rc;
    }
  }
}

- (void)_open_channels {
  SSHClientMainChannel *mainChannel = [[SSHClientMainChannel alloc] init];
  [_channels addObject:mainChannel];
  [mainChannel openWithClient:self];
  
  NSArray<NSString *> *addresses = _options[SSHOptionLocalForward];
  for (NSString *address in addresses) {
    SSHClientDirectForwardChannel *channel = [[SSHClientDirectForwardChannel alloc] initWithAddress:address];
    [_channels addObject:channel];
    [channel openWithClient:self];
  }
}

- (NSArray<NSString *>*)_getAnswersWithName:(NSString *)name instruction: (NSString *)instruction andPrompts:(NSArray *)prompts {
  NSMutableArray<NSString *> *answers = [[NSMutableArray alloc] init];
  for (int i = 0; i < prompts.count; i++) {
    __write(_fdOut, prompts[i][0]);
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

- (void)poll {
  ssh_event_dopoll(_event, -1); // TODO: tune timeout or event make it dynamic
}

void __on_usr1(int signum) {
  NSLog(@"asf");
}

- (int)main:(int) argc argv:(char **) argv {
  __block int rc = [_options parseArgs:argc argv: argv];

  if (rc != SSH_OK) {
    return [self _exitWithCode:rc andMessage:_options.exitMessage];
  }
  
  if ([_options[SSHOptionPrintVersion] isEqual:SSHOptionValueYES]) {
    [self _printVersion];
    return [self exitWithCode:SSH_OK];
  }
  
  _session = ssh_new();
  _event = ssh_event_new();
  sigset_t set;
  sigemptyset(&set);
  
  sigaddset(&set, SIGUSR1);
  // Block signal SIGUSR1 in this thread
  pthread_sigmask(SIG_SETMASK, &set, NULL);
  
  struct sigaction psa;
  psa.sa_handler = __on_usr1;
  sigaction(SIGUSR1, &psa, NULL);
  
//  pthread_sigmask(<#int#>, <#const sigset_t * _Nullable#>, <#sigset_t * _Nullable#>)
//  ssh_poll_init()
  rc = [_options configureSSHSession:_session];
  if (rc != SSH_OK) {
    return [self _exitWithCode:rc andMessage:_options.exitMessage];
  }
  
  if ([_options[SSHOptionPrintConfiguration] isEqual:SSHOptionValueYES]) {
    __write(_fdOut, [_options configurationAsText]);
    return [self exitWithCode:SSH_OK];
  }
  
  if ([self _start_connect_flow] == SSH_ERROR) {
    return [self exitWithCode:SSH_ERROR];
  }
  
  dispatch_block_t poll_block = ^{
    rc = ssh_event_dopoll(_event, 1000); // TODO: tune timeout or event make it dynamic
  };
  
//  POLL_IN
//  ssh_event_add_fd(<#ssh_event event#>, <#socket_t fd#>, <#short events#>, <#ssh_event_callback cb#>, <#void *userdata#>)

  while (!_doExit) {
    dispatch_sync(_queue, poll_block);
    if (rc == SSH_ERROR) {
      break;
    }
  };
  
  return _exitCode;
}

@end
