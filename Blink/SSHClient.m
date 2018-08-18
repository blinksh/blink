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
#import "SSHClientPortListener.h"
#import "BlinkPaths.h"

#import <signal.h>
#import <pthread.h>
#import <poll.h>
#include <sys/ioctl.h>
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


@interface SSHClient (internal) <SSHClientConnectedChannelDelegate, SSHClientPortListenerDelegate>
- (int) _ssh_auth_fn_prompt:(const char *)prompt buf:(char *)buf len:(size_t) len echo:(int) echo verify:(int)verify;
@end

int __ssh_auth_fn(const char *prompt, char *buf, size_t len,
                    int echo, int verify, void *userdata) {
  SSHClient *client = (__bridge SSHClient *)userdata;
  return [client _ssh_auth_fn_prompt:prompt buf:buf len:len echo:echo verify:verify];
}

@implementation SSHClient {
  SSHClientOptions *_options;
  ssh_session _session;
  NSTimer *_serverKeepAliveTimer;
  
  NSRunLoop *_runLoop;
  
  dispatch_fd_t _fdIn;
  dispatch_fd_t _fdOut;
  dispatch_fd_t _fdErr;
  
  BOOL _isTTY;
  
  NSMutableArray<SSHClientPortListener *> *_portListeners;
  SSHClientConnectedChannel *_sessionChannel;
  NSMutableArray<SSHClientConnectedChannel *> *_connectedChannels;
  
  NSMutableDictionary<NSNumber *, NSNumber *> *_reversePortsMap;
  
  ssh_callbacks _ssh_callbacks;
  bool _doExit;
  int _exitCode;
  pthread_t _thread;
  __weak TermDevice *_device;
}

- (instancetype)initWithStdIn:(dispatch_fd_t)fdIn stdOut:(dispatch_fd_t)fdOut stdErr:(dispatch_fd_t)fdErr device:(TermDevice *)device isTTY:(BOOL)isTTY {
  if (self = [super init]) {
    
    _portListeners = [[NSMutableArray alloc] init];
    _connectedChannels = [[NSMutableArray alloc] init];
    _device = device;
    _fdIn = fdIn;
    _fdOut = fdOut;
    _fdErr = fdErr;
    _options = [[SSHClientOptions alloc] init];
    
    _runLoop = [NSRunLoop currentRunLoop];
    
    _isTTY = isTTY;
    _thread = pthread_self();
    
    _doExit = NO;
    _exitCode = 0;
  }
  
  return self;
}

- (void)close {
  if (_serverKeepAliveTimer) {
    [_serverKeepAliveTimer invalidate];
    _serverKeepAliveTimer = nil;
  }
  for (SSHClientConnectedChannel *connectedChannel in _connectedChannels) {
    connectedChannel.delegate = nil;
    [connectedChannel close];
  }
  
  _connectedChannels = nil;
  
  for (SSHClientPortListener *listener in _portListeners) {
    listener.delegate = nil;
    [listener close];
  }
  _portListeners = nil;
  
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
  [self close];
}


#pragma mark - UTILS

- (void)sigwinch {
  [self _schedule:^{
    ssh_channel channel = _sessionChannel.channel;
    if (channel == NULL) {
      return;
    }
    ssh_channel_change_pty_size(channel, _device->win.ws_col, _device->win.ws_row);
  }];
}

- (int)_exitWithCode:(int)code {
  _doExit = YES;
  _exitCode = code;
  [self close];
  return code;
}

- (int)_exitWithCode:(int)code andMessage: (NSString *)message {
  if (message == nil) {
    return [self _exitWithCode:code];
  }
  message = [message stringByAppendingString:@"\n"];
  __write(_fdErr, message);
  return [self _exitWithCode:code];
}

- (void)_schedule:(dispatch_block_t)block {
  [_runLoop performBlock:block];
}

- (int)_ssh_auth_fn_prompt:(const char *)prompt buf:(char *)buf len:(size_t) len echo:(int) echo verify:(int)verify {
  NSString *nsPrompt = @(prompt);
  if (![nsPrompt hasSuffix:@":"]) {
    nsPrompt = [nsPrompt stringByAppendingString:@":"];
  }
  NSString *answer = [[self _getAnswersWithName:nil instruction:nil andPrompts:@[@[nsPrompt, @(echo)]]] firstObject];
  if (!answer) {
    return SSH_ERROR;
  }
  
  if (![answer getCString:buf maxLength:len encoding:NSUTF8StringEncoding]) {
    return SSH_ERROR;
  }

  return SSH_OK;
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
  BOOL rawMode = _device.rawMode;
  [_device setRawMode:NO];
  
  if (instruction.length > 0) {
    __write(_fdOut, instruction);
  }
  NSMutableArray<NSString *> *answers = [[NSMutableArray alloc] init];
  
  BOOL echoMode = _device.echoMode;
  for (int i = 0; i < prompts.count; i++) {
    BOOL echo = [prompts[i][1] boolValue];
    _device.echoMode = echo;
    __write(_fdOut, prompts[i][0]);
    
    FILE *fp = fdopen(_fdIn, "r");
    char * line = NULL;
    size_t len = 0;
    ssize_t read = getline(&line, &len, fp);
//    ssize_t read = getline(&line, &len, _device.stream.in);
    
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
  [_device setEchoMode:echoMode];
  [_device setRawMode:rawMode];
  
  
  return answers;
}

- (void)_poll {
  [_runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
}


#pragma mark - CONNECT

- (int)_connect {
  int attempts = [_options[SSHOptionConnectionAttempts] intValue];
  if (attempts <= 0) {
    attempts = 1;
  }
  
  bool tcpKeepAlive = [_options[SSHOptionTCPKeepAlive] isEqual:SSHOptionValueYES];

  for(;;) {
    if (_doExit) {
      return SSH_ERROR;
    }
    
    int rc = ssh_connect(_session);
    switch(rc) {
      case SSH_AGAIN:
        [self _poll];
        continue;
      case SSH_ERROR:
        attempts--;
        if (attempts > 0) {
          continue;
        }
        return rc;
      case SSH_OK: {
        int sock = ssh_get_fd(_session);
        int flags = 0;
        socklen_t optlen = 0;
        if (getsockopt(sock, SOL_SOCKET, SO_KEEPALIVE, &flags, &optlen)) {
          return SSH_ERROR;
        }
        if (flags != tcpKeepAlive) {
          flags = tcpKeepAlive;
          [self _log_verbose:[NSString stringWithFormat:@"setting socket keepalive: %@\n", @(tcpKeepAlive)]];
          if (setsockopt(sock, SOL_SOCKET, SO_KEEPALIVE, (void *)&flags, sizeof(flags))) {
            return SSH_ERROR;
          }
        }
        
        return rc;
      }
      default:
        return rc;
    }
  }
}

#pragma mark - AUTHENTICATION

- (int)_auth {
  
  // 1. try auth none
  int rc = [self _auth_none];
  // Who knows? we can success here too. See https://github.com/blinksh/blink/issues/450
  if (rc == SSH_AUTH_SUCCESS) {
    return SSH_OK;
  }

  if (rc == SSH_AUTH_ERROR) {
    return SSH_ERROR;
  }
  
  // 2. print issue banner if any
  __write_ssh_chars_and_free(_fdOut, ssh_get_issue_banner(_session));
  
  // 3. get auth methods from server
  int methods = ssh_userauth_list(_session, NULL);
  
  NSString *password = _options[SSHOptionPassword];
  
  // 4. user entered password in settings. So try to use it first to save AuthTries
  if (password.length > 0) {
    if (methods & SSH_AUTH_METHOD_PASSWORD && [SSHOptionValueYES isEqual:_options[SSHOptionPasswordAuthentication]]) {
      rc = [self _auth_with_password: password prompts: 1];
      if (rc == SSH_AUTH_SUCCESS) {
        return SSH_OK;
      }
    } else if (methods & SSH_AUTH_METHOD_INTERACTIVE && [SSHOptionValueYES isEqual:_options[SSHOptionKbdInteractiveAuthentication]]) {
      rc = [self _auth_with_interactive_with_password:password prompts:1];
      if (rc == SSH_AUTH_SUCCESS) {
        return SSH_OK;
      }
    }
  }
  
  // 5. public keys
  if (methods & SSH_AUTH_METHOD_PUBLICKEY && [SSHOptionValueYES isEqual:_options[SSHOptionPubkeyAuthentication]]) {
    rc = [self _auth_with_publickey];
    if (rc == SSH_AUTH_SUCCESS) {
      return SSH_OK;
    }
  }
  
  int promptsCount = [_options[SSHOptionNumberOfPasswordPrompts] intValue];
  
  // 4. interactive
  if (methods & SSH_AUTH_METHOD_INTERACTIVE && [SSHOptionValueYES isEqual:_options[SSHOptionKbdInteractiveAuthentication]]) {
    rc = [self _auth_with_interactive_with_password:password prompts:promptsCount];
    if (rc == SSH_AUTH_SUCCESS) {
      return SSH_OK;
    }
  } else if (methods & SSH_AUTH_METHOD_PASSWORD && [SSHOptionValueYES isEqual:_options[SSHOptionPasswordAuthentication]]) {
    // 6. even we don't have password. Ask it
    rc = [self _auth_with_password: password prompts:promptsCount];
    if (rc == SSH_AUTH_SUCCESS) {
      return SSH_OK;
    }
  }

  return [self _exitWithCode:SSH_ERROR];
}

- (int)_auth_none {
  for (;;) {
    if (_doExit) {
      return SSH_ERROR;
    }
    
    int rc = ssh_userauth_none(_session, NULL);
    switch (rc) {
      case SSH_AUTH_AGAIN:
        [self _poll];
        continue;
      default:
        return rc;
    }
  }
}

- (int)_auth_with_publickey {
  int rc = SSH_ERROR;
  
  NSArray<NSString *> *identityfiles = _options[SSHOptionIdentityFile];
  for (NSString *identityfile in identityfiles) {
    ssh_key pkey;
    
    BKPubKey *secureKey = [BKPubKey withID:identityfile];

    // we have this identity in
    if (secureKey) {
      [self _log_verbose:[NSString stringWithFormat:@"import key %@\n", identityfile]];
      rc =  ssh_pki_import_privkey_base64(secureKey.privateKey.UTF8String,
                                         NULL, /* TODO: get stored */
                                         __ssh_auth_fn,
                                         (__bridge void *) self,
                                         &pkey);
    } else {
      NSString *identityFilePath = identityfile;
      NSFileManager *fileManager = [NSFileManager defaultManager];
      // if file doesn't exists. Fallback to ~/.ssh/<identifyfile>
      if (![fileManager fileExistsAtPath:identityFilePath]) {
        identityFilePath = [[BlinkPaths ssh] stringByAppendingPathComponent:identityFilePath];
      }
      if (![fileManager fileExistsAtPath:identityFilePath]) {
        continue;
      }
      
      [self _log_verbose:[NSString stringWithFormat:@"import key from file %@\n", identityfile]];
      rc = ssh_pki_import_privkey_file(identityFilePath.UTF8String,
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
        case SSH_AUTH_SUCCESS:
          return rc;
        case SSH_AUTH_AGAIN:
          [self _poll];
          continue;
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

- (int)_auth_with_password:(NSString *)password prompts:(int)promptsCount {
  
  for (;;) {
    if (_doExit) {
      return SSH_ERROR;
    }
    
    if (password.length == 0) {
      const int NO_ECHO = NO;
      NSArray *prompts = @[@[@"Password:", @(NO_ECHO)]];
      password = [[self _getAnswersWithName:NULL instruction:NULL andPrompts:prompts] firstObject];
    }
    
    int rc = ssh_userauth_password(_session, NULL, password.UTF8String);
    
    switch (rc) {
      case SSH_AUTH_AGAIN:
        [self _poll];
        continue;
      case SSH_AUTH_DENIED: {
        if (--promptsCount > 0) {
          [self _log_info:@"Permission denied, please try again."];
          password = nil;
          continue;
        }
        return rc;
      }
      default:
        return rc;
    }
  }
}

- (int)_auth_with_interactive_with_password:(NSString *)password prompts:(int)promptsCount {
  for (;;) {
    if (_doExit) {
      return SSH_ERROR;
    }
    
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
      case SSH_AUTH_DENIED: {
        if (--promptsCount > 0) {
          if (password == nil) {
            [self _log_info:@"Permission denied, please try again."];
          }
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

#pragma mark - HOST VERIFICATION

- (int)_verify_known_host {
  char *hexa;
  unsigned char *hash = NULL;
  size_t hlen;
  ssh_key srv_pubkey;
  int rc;
  
  
  rc = ssh_get_server_publickey(_session, &srv_pubkey);
  if (rc < 0) {
    return rc;
  }
  
  rc = ssh_get_publickey_hash(srv_pubkey,
                              SSH_PUBLICKEY_HASH_SHA1,
                              &hash,
                              &hlen);
  ssh_key_free(srv_pubkey);
  if (rc < 0) {
    return rc;
  }
  
  enum ssh_server_known_e state = ssh_is_server_known(_session);
  
  switch(state) {
    case SSH_SERVER_KNOWN_OK:
      break; /* ok */
    case SSH_SERVER_KNOWN_CHANGED:
      [self _log_info:@"Host key for server changed : server's one is now :"];
      ssh_print_hexa("Public key hash",hash, hlen);
      ssh_clean_pubkey_hash(&hash);
      [self _log_info:@"For security reason, connection will be stopped"];
      return SSH_ERROR;
    case SSH_SERVER_FOUND_OTHER:
      [self _log_info: [
        @[@"The host key for this server was not found but an other type of key exists.",
          @"An attacker might change the default server key to confuse your client",
          @"into thinking the key does not exist."]
          componentsJoinedByString:@"\n"] ];
      return SSH_ERROR;
      
    case SSH_SERVER_FILE_NOT_FOUND:
      [self _log_info: [
         @[@"Could not find known host file. If you accept the host key here,",
          @"the file will be automatically created."]
          componentsJoinedByString:@"\n"]];
      /* fallback to SSH_SERVER_NOT_KNOWN behavior */
      //      FALL_THROUGH;
    case SSH_SERVER_NOT_KNOWN: {
      hexa = ssh_get_hexa(hash, hlen);
      [self _log_info: [NSString stringWithFormat:@"Public key hash: %s", hexa]];
      ssh_string_free_char(hexa);
      
      NSNumber * doEcho = @(YES);
      NSString *answer = [[[self _getAnswersWithName:@""
                                         instruction:@"The server is unknown. Do you trust the host key?"
                                          andPrompts:@[@[@" (yes/no):", doEcho]]] firstObject] lowercaseString];
      
      if ([answer isEqual:@"yes"] || [answer isEqual:@"y"]) {
        
      } else {
        ssh_clean_pubkey_hash(&hash);
        return SSH_ERROR;
      }
      
      answer = [[[self _getAnswersWithName:@""
                               instruction:@"This new key will be written on disk for further usage. do you agree?"
                                andPrompts:@[@[@" (yes/no):", doEcho]]] firstObject] lowercaseString];
      
      if ([answer isEqual:@"yes"] || [answer isEqual:@"y"]) {
        if (ssh_write_knownhost(_session) < 0) {
          ssh_clean_pubkey_hash(&hash);
          [self _log_error];
          return SSH_ERROR;
        }
      } else {
        ssh_clean_pubkey_hash(&hash);
        return SSH_ERROR;
      }
    }
      break;
    case SSH_SERVER_ERROR:
      ssh_clean_pubkey_hash(&hash);
      [self _log_error];
      return SSH_ERROR;
  }
  ssh_clean_pubkey_hash(&hash);
      
  return SSH_OK;
}

#pragma mark - CHANNELS

- (int)_open_channels {
  [self _log_verbose:@"open channels\n"];
  int rc = [self _start_session_channel];
  if (rc != SSH_OK) {
    [self _exitWithCode:rc];
    return rc;
  }
  
  for (NSString *address in _options[SSHOptionLocalForward]) {
    rc = [self _start_listen_direct_forward: address];
    if (rc != SSH_OK && [SSHOptionValueYES isEqual:_options[SSHOptionExitOnForwardFailure]]) {
      [self _exitWithCode:rc];
      return rc;
    }
  }
  
  for (NSString *address in _options[SSHOptionRemoteForward]) {
    [self _start_listen_reverse_forward: address];
  }
  return SSH_OK;
}

- (int)_start_session_channel {
  [self _log_verbose:@"open session\n"];
  int rc = SSH_ERROR;
  ssh_channel channel = ssh_channel_new(_session);
  ssh_channel_set_blocking(channel, 0);
  
  for (;;) {
    if (_doExit) {
      ssh_channel_free(channel);
      return SSH_ERROR;
    }
    rc = ssh_channel_open_session(channel);
    switch (rc) {
      case SSH_AGAIN:
        [self _poll];
        continue;
      case SSH_OK:
        break;
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
      if (_doExit) {
        ssh_channel_close(channel);
        ssh_channel_free(channel);
        return SSH_ERROR;
      }
      
      rc = ssh_channel_request_pty_size(channel, @"xterm".UTF8String, _device->win.ws_col, _device->win.ws_row);
      switch (rc) {
        case SSH_OK:
          break;
        case SSH_AGAIN:
          [self _poll];
          continue;
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
    if (_doExit) {
      ssh_channel_close(channel);
      ssh_channel_free(channel);
      return SSH_ERROR;
    }
    if (remoteCommand) {
      rc = ssh_channel_request_exec(channel, remoteCommand.UTF8String);
    } else {
      rc = ssh_channel_request_shell(channel);
    }
    switch (rc) {
      case SSH_OK:
        break;
      case SSH_AGAIN:
        [self _poll];
        continue;
      default:
      case SSH_ERROR:
        ssh_channel_close(channel);
        ssh_channel_free(channel);
        return rc;
    }
    break;
  }
  
  
  _sessionChannel = [SSHClientConnectedChannel connect:channel withFdIn:_fdIn fdOut:_fdOut fdErr:_fdErr];
  _sessionChannel.delegate = self;
  return rc;
}

#pragma mark - SSHClientPortListenerDelegate

- (void)sshClientPortListener:(SSHClientPortListener *)listener acceptedSocket:(dispatch_fd_t)socket {
  int noSigPipe = 1;
  setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, sizeof(noSigPipe));
  
  
//  int flag = 1;
//  int result = setsockopt(socket,            /* socket affected */
//                          IPPROTO_TCP,     /* set option at TCP level */
//                          SO_SNDLOWAT,     /* name of option */
//                          (char *) &flag,  /* the cast is historical
//                                            cruft */
//                          sizeof(int));    /* length of option value */
//

  ssh_channel channel = ssh_channel_new(_session);
  
  for (;;) {
    if (_doExit) {
      ssh_channel_free(channel);
      return;
    }
    int rc = ssh_channel_open_forward(channel,
                                      listener.remotehost.UTF8String,
                                      listener.remoteport,
                                      listener.sourcehost.UTF8String,
                                      listener.localport);
    switch (rc) {
      case SSH_OK:
        break;
      case SSH_AGAIN:
        [self _poll];
        continue;
      default:
      case SSH_ERROR:
        ssh_channel_free(channel);
        if (_options[SSHOptionExitOnForwardFailure] == SSHOptionValueYES) {
          [self _exitWithCode:rc];
        }
        return;
    }
    break;
  }
  
  SSHClientConnectedChannel *connectedChannel = [SSHClientConnectedChannel connect:channel withSocket:socket];
  connectedChannel.delegate = self;
  [_connectedChannels addObject:connectedChannel];
}

- (int)_start_listen_direct_forward:(NSString *)strAddress {
  SSHClientPortListener *portListener = [[SSHClientPortListener alloc] initInitWithAddress:strAddress];
  portListener.delegate = self;
  int rc = [portListener listen];
  if (rc == SSH_OK) {
    [_portListeners addObject:portListener];
  }
  
  return rc;
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
    if (_doExit) {
      return SSH_ERROR;
    }
    
    int rc = ssh_channel_listen_forward(_session, remotehost.UTF8String, remoteport, &remoteport);
    switch (rc) {
      case SSH_OK: {
        if (_reversePortsMap == nil) {
          _reversePortsMap = [[NSMutableDictionary alloc] init];
        }
        _reversePortsMap[@(remoteport)] = @(localport);
      }
        return rc;
      case SSH_AGAIN:
        [self _poll];
        continue;
      default:
      case SSH_ERROR:
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
  
  SSHClientConnectedChannel *connectedChannel = [SSHClientConnectedChannel connect:channel withSocket:sock];
  connectedChannel.delegate = self;
  [_connectedChannels addObject:connectedChannel];
  return SSH_OK;
}

#pragma mark - SSHClientConnectedChannelDelegate

- (void)connectedChannelDidClose:(SSHClientConnectedChannel *)connectedChannel {
  if (_sessionChannel == connectedChannel) {
    [self _schedule:^{
      [self _exitWithCode:connectedChannel.exit_status];
    }];
  }
  
  [_connectedChannels removeObject:connectedChannel];
}

- (void)_log_error {
  if ([SSHOptionValueQUIET isEqual:_options[SSHOptionLogLevel]]) {
    return;
  }
  
  if (_session == NULL) {
    return;
  }
  int rc = ssh_get_error_code(_session);
  if (rc == SSH_NO_ERROR) {
    return;
  }
  
  NSString *error = [[NSString alloc] initWithUTF8String:ssh_get_error(_session)];
  if (error.length == 0) {
    return;
  }
  __write(_fdErr, @"\r\n");
  __write(_fdErr, error);
  __write(_fdErr, @"\r\n");
}

- (void)_log_info:(NSString *)message {
  if ([SSHOptionValueQUIET isEqual:_options[SSHOptionLogLevel]]) {
    return;
  }
  __write(_fdOut, message);
  __write(_fdOut, @"\r\n");
}

- (void)_log_verbose:(NSString *)message {
  if ([SSHOptionValueQUIET isEqual:_options[SSHOptionLogLevel]] ||
      [SSHOptionValueINFO isEqual:_options[SSHOptionLogLevel]]) {
    return;
  }
  __write(_fdOut, [@"blink: " stringByAppendingString: message]);
}

#pragma mark - SERVER KeepAlive timer

- (void)_start_server_keepalive_timer {
  if (_serverKeepAliveTimer) {
    [_serverKeepAliveTimer invalidate];
  }
  
  int seconds = [_options[SSHOptionServerAliveInterval] intValue];
  if (seconds <= 0) {
    return;
  }
  [self _log_verbose:[NSString stringWithFormat:@"starting server keepalive: %@s", @(seconds)]];
  _serverKeepAliveTimer = [NSTimer timerWithTimeInterval:seconds target:self selector:@selector(_on_server_keep_alive) userInfo:nil repeats:YES];
  
  [_runLoop addTimer:_serverKeepAliveTimer forMode:NSDefaultRunLoopMode];
}

- (void)_on_server_keep_alive {
  if (_doExit) {
    return;
  }
  ssh_client_send_keepalive(_session);
}

#pragma mark - MAIN LOOP

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
  ssh_set_blocking(_session, 0);
  
  _ssh_callbacks = calloc(1, sizeof(struct ssh_callbacks_struct));
  _ssh_callbacks->userdata = (__bridge void *)self;

  ssh_callbacks_init(_ssh_callbacks);
  ssh_set_callbacks(_session, _ssh_callbacks);
  
  rc = [_options configureSSHSession:_session];
  if (rc != SSH_OK) {
    return [self _exitWithCode:rc andMessage:_options.exitMessage];
  }
  
  if ([_options[SSHOptionPrintConfiguration] isEqual:SSHOptionValueYES]) {
    __write(_fdOut, [_options configurationAsText]);
    return [self _exitWithCode:SSH_OK];
  }
  
  rc = [self _connect];
  if (rc != SSH_OK) {
    [self _exitWithCode:rc];
  }

  rc = [self _verify_known_host];
  if (rc != SSH_OK) {
    [self _exitWithCode:rc];
  }
  
  rc = [self _auth];
  if (rc != SSH_OK) {
    return [self _exitWithCode:rc];
  }
  
  rc = [self _open_channels];
  if (rc != SSH_OK) {
    return [self _exitWithCode:rc];
  }
  
  [self _start_server_keepalive_timer];

  NSDate *distantFuture = [NSDate distantFuture];
  while (!_doExit && ssh_is_connected(_session)) {
    [_runLoop runMode:NSDefaultRunLoopMode beforeDate:distantFuture];
    /// TODO: move to libssh level as callback?
    if (_reversePortsMap) {
      int port = 0;
      ssh_channel channel = ssh_channel_accept_forward(_session, 0, &port);
      
      NSNumber *localPort = _reversePortsMap[@(port)];
      if (channel && localPort) {
        [self _connect_channel:channel to_port: localPort.intValue];
      }
    }
  }
  
  [self _log_error];
  
  [self close];
  
  return _exitCode;
}


@end
