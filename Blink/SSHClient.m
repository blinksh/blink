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
#import "SSHClientConnectedChannel.h"

#import <signal.h>
#import <pthread.h>
#import <poll.h>
#include <sys/ioctl.h>
#include <libssh/callbacks.h>

static void __on_usr1(int signum) {
//  NSLog(@"SIGUSR1");
}

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


@interface SSHClient (internal) <SSHClientConnectedChannelDelegate>
- (int) _ssh_auth_fn_prompt:(const char *)prompt buf:(char *)buf len:(size_t) len echo:(int) echo verify:(int)verify;
@end

int __ssh_auth_fn(const char *prompt, char *buf, size_t len,
                    int echo, int verify, void *userdata) {
  SSHClient *client = (__bridge SSHClient *)userdata;
  return [client _ssh_auth_fn_prompt:prompt buf:buf len:len echo:echo verify:verify];
}

@implementation SSHClient {
  SSHClientOptions *_options;
  ssh_event _event;
  ssh_session _session;
  dispatch_queue_t _queue;
  dispatch_queue_t _listenQueue;
  
  dispatch_fd_t _fdIn;
  dispatch_fd_t _fdOut;
  dispatch_fd_t _fdErr;
  
  BOOL _isTTY;
  NSMutableArray<dispatch_source_t> *_listenSources;
  SSHClientConnectedChannel *_sessionChannel;
  NSMutableArray<SSHClientConnectedChannel *> *_connectedChannels;
  
  ssh_callbacks _ssh_callbacks;
  bool _doExit;
  int _exitCode;
  pthread_t _thread;
  __weak TermDevice *_device;
}

- (instancetype)initWithStdIn:(dispatch_fd_t)fdIn stdOut:(dispatch_fd_t)fdOut stdErr:(dispatch_fd_t)fdErr device:(TermDevice *)device isTTY:(BOOL)isTTY {
  if (self = [super init]) {
    
    _device = device;
    _queue = dispatch_queue_create("sh.blink.sshclient", DISPATCH_QUEUE_SERIAL);
    _listenQueue = dispatch_queue_create("sh.blink.sshclient.listen", DISPATCH_QUEUE_SERIAL); // can be concurrent
    _fdIn = fdIn;
    _fdOut = fdOut;
    _fdErr = fdErr;
    _options = [[SSHClientOptions alloc] init];
    _listenSources = [[NSMutableArray alloc] init];
    
    _isTTY = isTTY;
    _thread = pthread_self();
    
    _doExit = NO;
    _exitCode = 0;
  }
  
  return self;
}

- (void)close {
  //  ssh_set_blocking(_session, 1);
  if (_event) {
    ssh_event_free(_event);
    _event = NULL;
  }
  if (_session) {
    ssh_free(_session);
    _session = NULL;
  }
  if (_ssh_callbacks) {
    free(_ssh_callbacks);
    _ssh_callbacks = NULL;
  }
}

- (void)dealloc {
  NSLog(@"SSHClient dealloc");
}


#pragma mark - UTILS

- (void)sigwinch {
  [self _schedule:^{
    ssh_channel channel = _sessionChannel.channel;
    ssh_channel_change_pty_size(channel, _device->win.ws_col, _device->win.ws_row);
  }];
}

- (int)exitWithCode:(int)code {
  _doExit = YES;
  _exitCode = code;
  [self close];
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

- (void)_schedule:(dispatch_block_t)block {
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
    __write(_fdOut, @"\n");
    //    fclose(fp);
  }
  
  return answers;
}

- (void)_poll {
  ssh_event_dopoll(_event, -1);
}


#pragma mark - CONNECT

- (int)_start_connect_flow {
  _event = ssh_event_new();
  ssh_set_blocking(_session, 0);
  int rc = ssh_connect(_session);
  if (rc == SSH_ERROR) {
    return rc;
  }

  if (ssh_event_add_session(_event, _session) == SSH_ERROR) {
    rc = SSH_ERROR;
    return rc;
  }
  
  // connect
  for(;;) {
    switch(rc) {
      case SSH_AGAIN:
        rc = ssh_connect(_session);
        [self _poll];
        continue;
      case SSH_OK:
        return [self _auth];
      default:
      case SSH_ERROR:
        return rc;
    }
  }
  
  return rc;
}

#pragma mark - AUTHENTICATION

- (int)_auth {
  int rc = SSH_ERROR;
  
  // 1. pre auth
  for (;;) {
    rc = ssh_userauth_none(_session, NULL);
    switch (rc) {
      case SSH_AUTH_AGAIN:
        [self _poll];
        continue;
      case SSH_AUTH_PARTIAL:
      case SSH_AUTH_DENIED:
        break;
      case SSH_AUTH_SUCCESS:
        // Who knows? see https://github.com/blinksh/blink/issues/450
        return [self _open_channels];
      default:
      case SSH_AUTH_ERROR:
        return [self exitWithCode:rc];
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
      return rc;
    }
  }

  // 5. password if we have it
  if (methods & SSH_AUTH_METHOD_PASSWORD) {
    rc = [self _auth_with_password];
    if (rc == SSH_AUTH_SUCCESS) {
      return rc;
    }
  }

  // 6. interactive
  if (methods & SSH_AUTH_METHOD_INTERACTIVE) {
    rc = [self _auth_with_interactive];
    if (rc == SSH_AUTH_SUCCESS) {
      return rc;
    }
  }

  return [self exitWithCode:SSH_ERROR];
}

- (int)_auth_with_publickey {
  int rc = SSH_OK;
  NSArray<NSString *> *identityfiles = _options[SSHOptionIdentityFile];
  for (NSString *identityfile in identityfiles) {
    ssh_key pkey;
    
    BKPubKey *secureKey = [BKPubKey withID:identityfile];
    // we have this identity in
    if (secureKey) {
//      NSString * OPENSSH_HEADER_BEGIN = @"-----BEGIN OPENSSH PRIVATE KEY-----";
//      NSString * OPENSSH_HEADER_END   = @"-----END OPENSSH PRIVATE KEY-----";
//      NSString * PRIVATE_HEADER_BEGIN = @"-----BEGIN PRIVATE KEY-----";
//      NSString * PRIVATE_HEADER_END = @"-----END PRIVATE KEY-----";
//      NSString * b64Key = [secureKey.privateKey stringByReplacingOccurrencesOfString:PRIVATE_HEADER_BEGIN withString:OPENSSH_HEADER_BEGIN];
//      b64Key = [b64Key stringByReplacingOccurrencesOfString:PRIVATE_HEADER_END withString:OPENSSH_HEADER_END];
      rc =  ssh_pki_import_privkey_base64(secureKey.privateKey.UTF8String,
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
          [self _poll];
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

- (int)_auth_with_password {
  NSString *password = _options[SSHOptionPassword];
  
  if (!password) {
    return SSH_ERROR;
  }
  
  for (;;) {
    int rc = ssh_userauth_password(_session, NULL, password.UTF8String);
    
    switch (rc) {
      case SSH_AUTH_AGAIN:
        [self _poll];
        continue;
      case SSH_AUTH_SUCCESS:
        return [self _open_channels];
      default:
        return rc;
    }
  }
  return SSH_ERROR;
}

- (int)_auth_with_interactive {
  int promptsCount = [_options[SSHOptionNumberOfPasswordPrompts] intValue];
  NSString *password = _options[SSHOptionPassword];
  for (;;) {
    int rc = ssh_userauth_kbdint(_session, NULL, NULL);
    
    switch (rc) {
      case SSH_AUTH_AGAIN:
        [self _poll];
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
            
            NSArray * answers =nil;
            
            if (password && nprompts == 1 && [@"Password:" isEqual: [[prompts firstObject] firstObject]]) {
              answers = @[password];
            } else {
              answers = [self _getAnswersWithName:name instruction:instruction andPrompts:prompts];
            }
            
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
        return [self _open_channels];
      case SSH_AUTH_DENIED: {
        if (--promptsCount > 0) {
          password = nil;
          rc = ssh_userauth_kbdint(_session, NULL, NULL);
          continue;
        }
        return rc;
      }
      default:
        return rc;
    }
  }
}

#pragma mark - CHANNELS

- (int)_open_channels {
  int rc = [self _start_session_channel];
  if (rc != SSH_OK) {
    [self exitWithCode:rc];
    return rc;
  }
  
  for (NSString *address in _options[SSHOptionLocalForward]) {
    rc = [self _start_listen_direct_forward: address];
    if (rc != SSH_OK && [SSHOptionValueYES isEqual:_options[SSHOptionExitOnForwardFailure]]) {
      [self exitWithCode:rc];
      return rc;
    }
  }
  
  for (NSString *address in _options[SSHOptionRemoteForward]) {
    [self _start_listen_reverse_forward: address];
  }
  return SSH_OK;
}

- (int)_start_session_channel {
  int rc = SSH_ERROR;
  ssh_channel channel = ssh_channel_new(_session);
  ssh_channel_set_blocking(channel, 0);
  
  for (;;) {
    rc = ssh_channel_open_session(channel);
    switch (rc) {
      case SSH_AGAIN:
        [self _poll];
        continue;
      case SSH_OK: break;
      default:
      case SSH_ERROR:
        ssh_channel_free(channel);
        return rc;
    }
    break;
  }
  
  BOOL doRequestPTY = _options[SSHOptionRequestTTY] == SSHOptionValueYES
  || (_options[SSHOptionRequestTTY] == SSHOptionValueAUTO && _isTTY);
  
  if (doRequestPTY) {
    for (;;) {
      rc = ssh_channel_request_pty_size(channel, @"xterm".UTF8String, _device->win.ws_col, _device->win.ws_row);
      switch (rc) {
        case SSH_AGAIN:
          [self _poll];
          continue;
        case SSH_OK: break;
        default:
        case SSH_ERROR:
          ssh_channel_close(channel);
          ssh_channel_free(channel);
          return rc;
      }
      break;
    }
  }
  
  [_device setRawMode:YES];
  
  NSString *remoteCommand = _options[SSHOptionRemoteCommand];
  for (;;) {
    if (remoteCommand) {
      rc = ssh_channel_request_exec(channel, remoteCommand.UTF8String);
    } else {
      rc = ssh_channel_request_shell(channel);
    }
    switch (rc) {
      case SSH_AGAIN:
        [self _poll];
        continue;
      case SSH_OK:
        break;
      default:
      case SSH_ERROR:
        ssh_channel_close(channel);
        ssh_channel_free(channel);
        return rc;
    }
    break;
  }
  
  
  _sessionChannel = [[SSHClientConnectedChannel alloc] init];
  _sessionChannel.delegate = self;
  [_sessionChannel connect:channel withFdIn:_fdIn fdOut:_fdOut fdErr:_fdErr];
  [_sessionChannel addToEvent:_event];
  return rc;
}


- (int)_start_listen_direct_forward:(NSString *)strAddress {
  __block int rc = SSH_ERROR;
  NSMutableArray<NSString *> *parts = [[strAddress componentsSeparatedByString:@":"] mutableCopy];
  int remoteport = [[parts lastObject] intValue];
  [parts removeLastObject];
  NSString *remotehost = [parts lastObject];
  [parts removeLastObject];
  int localport = [[parts lastObject] intValue];
  [parts removeLastObject];
  NSString *sourcehost = [parts lastObject] ?: @"localhost";
  
  dispatch_fd_t listenSock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (listenSock < 0) {
    return SSH_ERROR;
  }
  int value = 1;
  setsockopt(listenSock, SOL_SOCKET, SO_REUSEADDR, &value, sizeof(value));
  
  struct sockaddr_in address;
  address.sin_family = AF_INET;
  address.sin_addr.s_addr = INADDR_ANY;
  
  address.sin_port=htons(localport);
  rc = bind(listenSock, (struct sockaddr *)&address,sizeof(address));
  if (rc == -1) {
    return SSH_ERROR;
  }
  int listenBacklog = 5;
  rc = listen(listenSock, listenBacklog);
  if (rc == -1) {
    return SSH_ERROR;
  }
  
  dispatch_source_t listenSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, listenSock, 0, _listenQueue);
  
  if (listenSource == nil) {
    return SSH_ERROR;
  }
  
  dispatch_source_set_cancel_handler(listenSource, ^{
    close(listenSock);
  });
  
  dispatch_source_set_event_handler(listenSource, ^{
    dispatch_fd_t sock = accept(listenSock, NULL, NULL);
    if (sock == SSH_INVALID_SOCKET) {
      return;
    }
    
    int noSigPipe = 1;
    setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, sizeof(noSigPipe));
    
    [self _schedule:^{
      ssh_channel channel = ssh_channel_new(_session);
      ssh_channel_set_blocking(channel, 0);
      
      for (;;) {
        rc = ssh_channel_open_forward(channel, remotehost.UTF8String, remoteport, sourcehost.UTF8String, localport);
        switch (rc) {
          case SSH_AGAIN:
            [self _poll];
            continue;
          case SSH_OK: break;
          default:
          case SSH_ERROR:
            ssh_channel_free(channel);
            if (_options[SSHOptionExitOnForwardFailure] == SSHOptionValueYES) {
              [self exitWithCode:rc];
            }
            return;
        }
        break;
      }
      
      SSHClientConnectedChannel *connectedChannel = [[SSHClientConnectedChannel alloc] init];
      connectedChannel.delegate = self;
      [connectedChannel connect:channel withSockFd:sock];
      [_connectedChannels addObject:connectedChannel];
      [connectedChannel addToEvent:_event];
    }];
  });
  
  dispatch_activate(listenSource);
  [_listenSources addObject:listenSource];
  return SSH_OK;
}

- (int)_start_listen_reverse_forward:(NSString *)strAddress {
  NSString *remotehost;
  NSString *sourcehost;
  int remoteport = 0;
  int localport = 0;
  NSMutableArray<NSString *> *parts = [[strAddress componentsSeparatedByString:@":"] mutableCopy];
  
  //  -R port
  if (parts.count == 1) {
    int port = [[parts lastObject] intValue];
    remoteport = port;
    localport = port;
    remotehost = NULL;
    sourcehost = NULL;
  }
  
  remoteport = [[parts lastObject] intValue];
  [parts removeLastObject];
  remotehost = [parts lastObject];
  [parts removeLastObject];
  localport = [[parts lastObject] intValue];
  [parts removeLastObject];
  sourcehost = [parts lastObject] ?: @"localhost";
  
  for (;;) {
    int rc = ssh_channel_listen_forward(_session, remotehost.UTF8String, remoteport, &remoteport);
    switch (rc) {
      case SSH_AGAIN:
        [self _poll];
        continue;
      case SSH_OK:
        NSLog(@"Ok %@", @(remoteport));
        return rc;
      default:
      case SSH_ERROR:
        NSLog(@"Error");
        return rc;
    }
  }
  return SSH_ERROR;
}

- (int)_connect_channel:(ssh_channel)channel to_port:(int)port {
  int sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  
  if (sock == SSH_INVALID_SOCKET) {
    return SSH_ERROR;
  }
  
  struct sockaddr_in address;
  address.sin_family = AF_INET;
  address.sin_addr.s_addr = INADDR_ANY;
  
  address.sin_port=htons(port);
  
  int rc = connect(sock, (struct sockaddr *)&address, sizeof(address));
  if (rc == -1) {
    return rc;
  }
  
  SSHClientConnectedChannel *connectedChannel = [[SSHClientConnectedChannel alloc] init];
  connectedChannel.delegate = self;
  [connectedChannel connect:channel withSockFd:sock];
  [_connectedChannels addObject:connectedChannel];
  [connectedChannel addToEvent:_event];
  return SSH_OK;
}

#pragma mark - SSHClientConnectedChannelDelegate

- (void)connectedChannelDidClose:(SSHClientConnectedChannel *)connectedChannel {
  if (_sessionChannel == connectedChannel) {
    [self _schedule:^{
      [self exitWithCode:connectedChannel.exitCode];
    }];
  }
  
  [_connectedChannels removeObject:connectedChannel];
}

#pragma mark - MAIN LOOP

- (int)main:(int) argc argv:(char **) argv {
  
  struct sigaction sa = (struct sigaction) {
    .sa_handler = &__on_usr1,
    .sa_flags = 0
  };
  sigaction(SIGUSR1, &sa, NULL);

  __block int rc = [_options parseArgs:argc argv: argv];

  if (rc != SSH_OK) {
    return [self _exitWithCode:rc andMessage:_options.exitMessage];
  }
  
  if ([_options[SSHOptionPrintVersion] isEqual:SSHOptionValueYES]) {
    [self _printVersion];
    return [self exitWithCode:SSH_OK];
  }
  
  _session = ssh_new();
  _ssh_callbacks = calloc(1, sizeof(struct ssh_callbacks_struct));
  _ssh_callbacks->userdata = (__bridge void *)self;
  
  ssh_callbacks_init(_ssh_callbacks);
  ssh_set_callbacks(_session, _ssh_callbacks);
  
  _event = ssh_event_new();
  
  rc = [_options configureSSHSession:_session];
  if (rc != SSH_OK) {
    return [self _exitWithCode:rc andMessage:_options.exitMessage];
  }
  
  if ([_options[SSHOptionPrintConfiguration] isEqual:SSHOptionValueYES]) {
    __write(_fdOut, [_options configurationAsText]);
    return [self exitWithCode:SSH_OK];
  }
  
  rc = [self _start_connect_flow];
  if (rc != SSH_OK) {
    return [self exitWithCode:rc];
  }
  
  BOOL hasRemoteForwards = _options[SSHOptionRemoteForward] != nil;
  
  dispatch_block_t poll_block = ^{
    rc = ssh_event_dopoll(_event, -1);
    if (_doExit) {
      return;
    }

    if (hasRemoteForwards) {
      int port = 0;
      ssh_channel channel = ssh_channel_accept_forward(_session, 0, &port);
      if (channel) {
        [self _connect_channel:channel to_port: port];
      }
    }
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
