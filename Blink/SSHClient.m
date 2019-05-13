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
#import <sys/socket.h>
#import <sys/un.h>
#import <arpa/inet.h>


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
  
  struct ssh_callbacks_struct _ssh_callbacks;
  BOOL _doExit;
  BOOL _killed;
  int _exitCode;
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
    
    _doExit = NO;
    _killed = NO;
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
  
  if (_sessionChannel) {
    _sessionChannel.delegate = nil;
    [_sessionChannel close];
    _sessionChannel = nil;
  }
  
  if (_session) {
    ssh_free(_session);
    _session = NULL;
  }
  
  _ssh_callbacks.userdata = NULL;
  _doExit = YES;
}

- (void)dealloc {
  [self close];
}


#pragma mark - UTILS

- (void)sigwinch {
  __weak SSHClient *weakSelf = self;
  [self _schedule:^{
    SSHClient *client = weakSelf;
    if (client == nil) {
      return;
    }
    ssh_channel channel = client->_sessionChannel.channel;
    if (channel == NULL) {
      return;
    }
    ssh_channel_change_pty_size(channel, _device->win.ws_col, _device->win.ws_row);
  }];
}

- (void)kill {
  _killed = YES;
  __weak SSHClient *weakSelf = self;
  [self _schedule:^{
    [weakSelf _exitWithCode:-1];
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
  
  if (name.length > 0) {
    name = [name stringByAppendingString:@"\n"];
    fwrite(name.UTF8String, [name lengthOfBytesUsingEncoding:NSUTF8StringEncoding], 1, _device.stream.out);
  }
  
  if (instruction.length > 0) {
    instruction = [instruction stringByAppendingString:@"\n"];
    fwrite(instruction.UTF8String, [instruction lengthOfBytesUsingEncoding:NSUTF8StringEncoding], 1, _device.stream.out);
  }
  NSMutableArray<NSString *> *answers = [[NSMutableArray alloc] init];
  
  BOOL echoMode = _device.echoMode;
  for (int i = 0; i < prompts.count; i++) {
    BOOL echo = [prompts[i][1] boolValue];
    _device.echoMode = echo;
    NSString *prompt = prompts[i][0];
    // write prompt directly to device stream?...
    fwrite(prompt.UTF8String, [prompt lengthOfBytesUsingEncoding:NSUTF8StringEncoding], 1, _device.stream.out);
    
    char * line = NULL;
    size_t len = 0;
    ssize_t read = getline(&line, &len, _device.stream.in);
    
    if (read == -1) {
      [self _log_verbose:@"Can't read input"];
    }
    
    if (line) {
      NSString * lineStr = [@(line) stringByReplacingOccurrencesOfString:@"\n" withString:@""];
      [answers addObject:lineStr];
      free(line);
    }
    fwrite("\n", 1, 1, _device.stream.out);
    //    fclose(fp);
  }
  [_device setEchoMode:echoMode];
  [_device setRawMode:rawMode];
  
  
  return answers;
}

- (void)_poll {
  [_runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
}

- (BOOL)_notConnected {
  return _doExit || !ssh_is_connected(_session) || _device == nil;
}


#pragma mark - CONNECT

- (int)_connect {
  int attempts = [_options[SSHOptionConnectionAttempts] intValue];
  if (attempts <= 0) {
    attempts = 1;
  }
  
  bool tcpKeepAlive = [_options[SSHOptionTCPKeepAlive] isEqual:SSHOptionValueYES];
  
  NSNumber *connectTimeout = _options[SSHOptionConnectTimeout];
  NSDate *connectStart = [NSDate date];

  for(;;) {
    
    if (_doExit) {
      return SSH_ERROR;
    }

    if (connectTimeout.integerValue > 0 && -connectStart.timeIntervalSinceNow > connectTimeout.integerValue) {
      [self _log_info:@"Connect timeout"];
      return SSH_ERROR;
    }
    
    int rc = ssh_connect(_session);
    switch(rc) {
      case SSH_AGAIN:
        [self _poll];
        continue;
      case SSH_ERROR: {
        const char *err = ssh_get_error(_session);
        NSString *error = [NSString stringWithUTF8String:err];
        if (error) {
          // Check compression error
          NSString *noCompressionOnServer = @"no match for method compression algo client->server: server [none]";
          if ([_options[SSHOptionCompression] isEqual:SSHOptionValueYES] && [error containsString:noCompressionOnServer]) {
            ssh_free(_session);
            [self _log_verbose:@"Server doesn't support compression. Connecting without compression\n"];
            _options[[SSHOptionCompression copy]] = [SSHOptionValueNO copy];
            _session = [self _configured_session];
            continue;
          }
          [self _log_error];
        }
        attempts--;
        if (attempts > 0) {
          ssh_free(_session);
          _session = [self _configured_session];
          connectStart = [NSDate date];
          continue;
        }
      }
        return rc;
      case SSH_OK: {
        int sock = ssh_get_fd(_session);
    
        CFSocketRef sockRef = CFSocketCreateWithNative(NULL, sock, 0, NULL, NULL);
        NSData * data = (__bridge_transfer NSData *)CFSocketCopyPeerAddress(sockRef);
        CFRelease(sockRef);
        
        if (data) {
          // We got connected to socket. Lets tune it
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
          
          // Print peer host to pickup in mosh command
          char host[NI_MAXHOST];
          getnameinfo((const struct sockaddr *)[data bytes], (socklen_t)data.length, host, sizeof(host), NULL, 0, NI_NUMERICHOST);
          NSString *address = [NSString stringWithUTF8String:host];
          
          if (address && address.length && [_options[SSHOptionPrintAddress] isEqual:SSHOptionValueYES]) {
            [self _log_info:[NSString stringWithFormat:@"Connected to %@", address]];
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
  
  BOOL optionPasswordAuth = [SSHOptionValueYES isEqual:_options[SSHOptionPasswordAuthentication]];
  BOOL optionKbdInteractiveAuth = [SSHOptionValueYES isEqual:_options[SSHOptionKbdInteractiveAuthentication]];
  BOOL optionPubKeyAuth = [SSHOptionValueYES isEqual:_options[SSHOptionPubkeyAuthentication]];
  BOOL optionIdenitiesOnly = [SSHOptionValueYES isEqual:_options[SSHOptionIdentitiesOnly]];
  int  optionPasswordPromptsCount = [_options[SSHOptionNumberOfPasswordPrompts] intValue];
  
  NSString *optionPassword = _options[SSHOptionPassword];
  if (optionPassword.length == 0) {
    optionPassword = nil;
  }
  
  int maxPartialAuths = 5;
  
  for (int i = 0; i < maxPartialAuths; i++) {
    [self _log_verbose:[NSString stringWithFormat:@"using auth methods attempt: %@ of %@\n", @(i + 1), @(maxPartialAuths)]];
    
    // 3. get auth methods from server
    int methods = ssh_userauth_list(_session, NULL);
    
    // 4. user entered password in settings. So try to use it first to save AuthTries
    if (optionPassword) {
      if (methods & SSH_AUTH_METHOD_PASSWORD && optionPasswordAuth) {
        rc = [self _auth_with_password: optionPassword prompts: 1];
        if (rc == SSH_AUTH_SUCCESS) {
          return SSH_OK;
        } else if (rc == SSH_AUTH_PARTIAL) {
          continue;
        }
      } else if (methods & SSH_AUTH_METHOD_INTERACTIVE && optionKbdInteractiveAuth) {
        rc = [self _auth_with_interactive_with_password:optionPassword prompts:1];
        if (rc == SSH_AUTH_SUCCESS) {
          return SSH_OK;
        } else if (rc == SSH_AUTH_PARTIAL) {
          continue;
        }
      }
    }
  
    // 5. public keys
    
    // 5.1 Agent first if possible
    if (methods & SSH_AUTH_METHOD_PUBLICKEY && optionPubKeyAuth && !optionIdenitiesOnly) {
      rc = [self _auth_with_agent];
      if (rc == SSH_AUTH_SUCCESS) {
        return SSH_OK;
      } else if (rc == SSH_AUTH_PARTIAL) {
        continue;
      }
    }
    
    // 5.2 Identities
    if (methods & SSH_AUTH_METHOD_PUBLICKEY && optionPubKeyAuth) {
      rc = [self _auth_with_publickey];
      if (rc == SSH_AUTH_SUCCESS) {
        return SSH_OK;
      } else if (rc == SSH_AUTH_PARTIAL) {
        continue;
      }
    }
    
    // 6. interactive
    if (methods & SSH_AUTH_METHOD_INTERACTIVE && optionKbdInteractiveAuth) {
      rc = [self _auth_with_interactive_with_password:optionPassword prompts:optionPasswordPromptsCount];
      if (rc == SSH_AUTH_SUCCESS) {
        return SSH_OK;
      } else if (rc == SSH_AUTH_PARTIAL) {
        continue;
      }
    }
    
    // 7. password
    if (methods & SSH_AUTH_METHOD_PASSWORD && optionPasswordAuth) {
      // even we don't have password. Ask it
      rc = [self _auth_with_password: optionPassword prompts:optionPasswordPromptsCount];
      if (rc == SSH_AUTH_SUCCESS) {
        return SSH_OK;
      } else if (rc == SSH_AUTH_PARTIAL) {
        continue;
      }
    }
    
    break;
  }

  return [self _exitWithCode:SSH_ERROR];
}

- (int)_auth_none {
  for (;;) {
    if ([self _notConnected]) {
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

    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // we have this identity in
    if (secureKey) {
      [self _log_verbose:[NSString stringWithFormat:@"import key %@\n", identityfile]];
      rc =  ssh_pki_import_privkey_base64(secureKey.privateKey.UTF8String,
                                         NULL, /* TODO: get stored */
                                         __ssh_auth_fn,
                                         (__bridge void *) self,
                                         &pkey);
      
      NSString *identityFilePath = [[BlinkPaths ssh] stringByAppendingPathComponent:identityfile];
      if ([fileManager fileExistsAtPath:identityFilePath]) {
        [self _log_verbose:[NSString stringWithFormat:@"warning: key '%@' duplicate in SE and file system. Using key from SE   \n", identityfile]];
      }
    } else {
      NSString *identityFilePath = identityfile;
      
      // if file doesn't exists. Fallback to ~/.ssh/<identifyfile>
      if (![fileManager fileExistsAtPath:identityFilePath]) {
        identityFilePath = [[BlinkPaths ssh] stringByAppendingPathComponent:identityFilePath];
      }
      if (![fileManager fileExistsAtPath:identityFilePath]) {
        [self _log_verbose:[NSString stringWithFormat:@"warning: no key found: '%@' \n", identityfile]];
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
    
    bool tryNextIdentityFile = NO;
    
    for (;;) {
      if ([self _notConnected]) {
        ssh_key_free(pkey);
        return SSH_ERROR;
      }
      rc = ssh_userauth_try_publickey(_session, NULL, pkey);
      switch (rc) {
        case SSH_AUTH_ERROR:
          break;
        case SSH_AUTH_SUCCESS:
          break;
        case SSH_AUTH_AGAIN:
          [self _poll];
          continue;
        case SSH_AUTH_DENIED:
          tryNextIdentityFile = YES;
          break;
        case SSH_AUTH_PARTIAL: {
          int methods = ssh_userauth_list(_session, NULL);
          tryNextIdentityFile = methods & SSH_AUTH_METHOD_PUBLICKEY;
          break;
        }
        
      }
      break;
    }
    
    if (tryNextIdentityFile) {
      ssh_key_free(pkey);
      continue;
    }
    
    if (rc != SSH_AUTH_SUCCESS) {
      ssh_key_free(pkey);
      return rc;
    }
    
    tryNextIdentityFile = NO;
    
    for (;;) {
      if ([self _notConnected]) {
        ssh_key_free(pkey);
        return SSH_ERROR;
      }
      rc = ssh_userauth_publickey(_session, NULL, pkey);
      switch (rc) {
        case SSH_AUTH_SUCCESS:
          ssh_key_free(pkey);
          return rc;
        case SSH_AUTH_AGAIN:
          [self _poll];
          continue;
        case SSH_AUTH_DENIED:
          tryNextIdentityFile = YES;
          break;
        case SSH_AUTH_PARTIAL: {
            int methods = ssh_userauth_list(_session, NULL);
            tryNextIdentityFile = methods & SSH_AUTH_METHOD_PUBLICKEY;
          }
          break;
        default:
          break;
      }
      break;
    }
    
    ssh_key_free(pkey);
    
    if (tryNextIdentityFile) {
      continue;
    }
    
    break;
  }
  
  return rc;
}

- (int)_auth_with_agent {
  int rc = SSH_ERROR;
  for (;;) {
    if ([self _notConnected]) {
      return SSH_ERROR;
    }
    
    rc = ssh_userauth_agent(_session, NULL);
    switch (rc) {
      case SSH_AUTH_AGAIN:
        [self _poll];
        continue;
      default:
        return rc;
    }
  }
}

- (int)_auth_with_password:(NSString *)password prompts:(int)promptsCount {
  
  for (;;) {
    if ([self _notConnected]) {
      return SSH_ERROR;
    }
    
    if (!password) {
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
  // https://gitlab.com/libssh/libssh-mirror/blob/master/doc/authentication.dox#L124
  BOOL wasInAuthInfo = NO;
  for (;;) {
    if ([self _notConnected]) {
      return SSH_ERROR;
    }
    
    int rc = ssh_userauth_kbdint(_session, NULL, NULL);
    
    switch (rc) {
      case SSH_AUTH_AGAIN:
        [self _poll];
        continue;
      case SSH_AUTH_INFO: {
        wasInAuthInfo = YES;
        const char *nameChars = ssh_userauth_kbdint_getname(_session);
        const char *instructionChars = ssh_userauth_kbdint_getinstruction(_session);
        
        NSString *name = nameChars ? @(nameChars) : nil;
        NSString *instruction = instructionChars ? @(instructionChars) : nil;
        
        int nprompts = ssh_userauth_kbdint_getnprompts(_session);
        if (nprompts < 0) {
          return SSH_AUTH_ERROR;
        }

        NSMutableArray *prompts = [[NSMutableArray alloc] initWithCapacity:nprompts];
        for (int i = 0; i < nprompts; i++) {
          char echo = NO;
          const char *prompt = ssh_userauth_kbdint_getprompt(_session, i, &echo);
          
          [prompts addObject:@[prompt == NULL ? @"" : @(prompt), @(echo)]];
        }
        
        NSArray * answers = nil;
        
        if (password && nprompts == 1 && [@"Password:" isEqual: [[prompts firstObject] firstObject]]) {
          answers = @[password];
        } else {
          answers = [self _getAnswersWithName:name instruction:instruction andPrompts:prompts];
        }
        
        for (int i = 0; i < answers.count; i++) {
          int rc = ssh_userauth_kbdint_setanswer(_session, i, [answers[i] UTF8String]);
          if (rc < 0) {
            return SSH_AUTH_ERROR;
          }
        }
        continue;
      }
      case SSH_AUTH_DENIED: {
        if (!wasInAuthInfo) {
          return rc;
        }
        if (--promptsCount > 0) {
          if (password == nil) {
            [self _log_info:@"Permission denied, please try again."];
          }
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

#pragma mark - HOST VERIFICATION

- (const NSString *)_keyTypeNameForKey:(ssh_key) ssh_key {
  enum ssh_keytypes_e type = ssh_key_type(ssh_key);
  switch (type) {
    case SSH_KEYTYPE_DSS:
      return BK_KEYTYPE_DSA;
    case SSH_KEYTYPE_RSA:
    case SSH_KEYTYPE_RSA1:
      return BK_KEYTYPE_RSA;
    case SSH_KEYTYPE_ECDSA:
      return BK_KEYTYPE_ECDSA;
    case SSH_KEYTYPE_ED25519:
      return BK_KEYTYPE_Ed25519;
    default:
      return @(ssh_key_type_to_char(type));
  }
}

- (NSString *)_pubkeyFingerPrint:(ssh_key) ssh_key {
  unsigned char *hash = NULL;
  size_t hlen;
  int rc = ssh_get_publickey_hash(ssh_key,
                              SSH_PUBLICKEY_HASH_SHA256,
                              &hash,
                              &hlen);
  if (rc < 0) {
    return nil;
  }
  
  char *fingerprint = ssh_get_fingerprint_hash(SSH_PUBLICKEY_HASH_SHA256, hash, hlen);
  ssh_clean_pubkey_hash(&hash);
  
  if (!fingerprint) {
    return nil;
  }
  
  NSString *result = @(fingerprint);
  ssh_string_free_char(fingerprint);
  
  return result;
}

- (int)_verify_known_host {
  ssh_key srv_pubkey;
  int rc;

  rc = ssh_get_server_publickey(_session, &srv_pubkey);
  if (rc < 0) {
    return rc;
  }
  
  NSString *fingerprint = [self _pubkeyFingerPrint:srv_pubkey];
  
  NSString *fingerprintMsg = [NSString stringWithFormat:@"%@ key fingerprint is %@.",
                              [self _keyTypeNameForKey:srv_pubkey],
                              fingerprint];
  
  ssh_key_free(srv_pubkey);
  
  
  if (!fingerprint) {
    return SSH_ERROR;
  }
  
  enum ssh_known_hosts_e state = ssh_session_is_known_server(_session);
  
  if (state == SSH_KNOWN_HOSTS_OTHER) {
    [self _log_verbose:@"The host key for this server was not found but an other type of key exists.\n"];
    [self _log_verbose:@"An attacker might change the default server key to confuse your client\n"];
    [self _log_verbose:@"into thinking the key does not exist.\n"];
    state = SSH_KNOWN_HOSTS_UNKNOWN;
  }
  
  switch(state) {
    case SSH_KNOWN_HOSTS_CHANGED:
      [self _device_log_info:@"Host key for server changed."];
      [self _device_log_info:fingerprintMsg];
      [self _device_log_info:@"For security reason, connection will be stopped"];
      return SSH_ERROR;
    case SSH_KNOWN_HOSTS_OTHER:
      [self _device_log_info:@"The host key for this server was not found but an other type of key exists."];
      [self _device_log_info:@"An attacker might change the default server key to confuse your client"];
      [self _device_log_info:@"into thinking the key does not exist"];
      [self _device_log_info:@"For security reason, connection will be stopped"];
      return SSH_ERROR;
    case SSH_KNOWN_HOSTS_NOT_FOUND:
      [self _device_log_info: [
        @[@"Could not find known host file. If you accept the host key here.",
          @"the file will be automatically created."]
          componentsJoinedByString:@"\n"] ];
//      FALL_THROUGH;
    case SSH_KNOWN_HOSTS_UNKNOWN: {
      [self _device_log_info: fingerprintMsg];
      
      NSNumber * doEcho = @(YES);
      NSString *answer = [[[self _getAnswersWithName:@""
                                         instruction:@"The server is unknown."
                                          andPrompts:@[@[@"Do you trust the host key? (yes/no):", doEcho]]] firstObject] lowercaseString];
      
      if ([answer isEqual:@"yes"] || [answer isEqual:@"y"]) {
        
      } else {
        return SSH_ERROR;
      }
      
      answer = [[[self _getAnswersWithName:@""
                               instruction:@"This new key will be written on disk for further usage."
                                andPrompts:@[@[@"Do you agree? (yes/no):", doEcho]]] firstObject] lowercaseString];
      
      if ([answer isEqual:@"yes"] || [answer isEqual:@"y"]) {
        if (ssh_write_knownhost(_session) < 0) {
          [self _log_error];
          return SSH_ERROR;
        }
      }
    }
      break;
    case SSH_KNOWN_HOSTS_ERROR:
      [self _log_error];
      return SSH_ERROR;
    case SSH_KNOWN_HOSTS_OK:
      break; /* ok */
  }
      
  return SSH_OK;
}

#pragma mark - CHANNELS

- (int)_open_channels {
  [self _log_verbose:@"open channels\n"];
  int rc = SSH_ERROR;
  
  NSString * hostPort = _options[SSHOptionSTDIOForwarding];
  if (hostPort) {
    rc = [self _start_stdio_forwarding:hostPort];
  } else {
    rc = [self _start_session_channel];
  }
  
  if (rc != SSH_OK) {
    return [self _exitWithCode:rc];
  }
  
  for (NSString *address in _options[SSHOptionLocalForward]) {
    rc = [self _start_listen_direct_forward: address];
    if (rc != SSH_OK && [SSHOptionValueYES isEqual:_options[SSHOptionExitOnForwardFailure]]) {
      return [self _exitWithCode:rc];
    }
  }
  
  for (NSString *address in _options[SSHOptionRemoteForward]) {
    [self _start_listen_reverse_forward: address];
  }
  return SSH_OK;
}

- (int)_request_pty:(ssh_channel)channel {
  int rc = SSH_ERROR;
  char *default_term = "xterm-256color";
  char *term = getenv("TERM");
  if (term) {
    if (strlen(term) == 0) {
      term = default_term;
    }
  } else {
    term = default_term;
  }

  for (;;) {
    if ([self _notConnected]) {
      return SSH_ERROR;
    }
    
    rc = ssh_channel_request_pty_size(channel, term, _device->win.ws_col, _device->win.ws_row);
    switch (rc) {
      case SSH_AGAIN:
        [self _poll];
        continue;
      case SSH_OK:
        [_device setRawMode:YES];
        return rc;
      default:
        return rc;
    }
  }
}

- (int)_start_session_channel {
  [self _log_verbose:@"open session\n"];
  int rc = SSH_ERROR;
  ssh_channel channel = ssh_channel_new(_session);
  ssh_channel_set_blocking(channel, 0);
  
  for (;;) {
    if ([self _notConnected]) {
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
        [self _log_error];
        ssh_channel_free(channel);
        return rc;
    }
    break;
  }
  
  if ([SSHOptionValueYES isEqual:_options[SSHOptionForwardAgent]]) {
    rc = ssh_channel_request_auth_agent(channel);
  }
  
  BOOL doRequestPTY = [_options[SSHOptionRequestTTY] isEqual:SSHOptionValueYES]
                  || ([_options[SSHOptionRequestTTY] isEqual:SSHOptionValueAUTO] && _isTTY);
  
  if (doRequestPTY) {
    rc = [self _request_pty: channel];
    if (rc != SSH_OK) {
      ssh_channel_close(channel);
      ssh_channel_free(channel);
      return rc;
    }
  }
  
  [self _ssh_send_env: channel];

  NSString *remoteCommand = _options[SSHOptionRemoteCommand];
  for (;;) {
    if ([self _notConnected]) {
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

- (void)_ssh_send_env:(ssh_channel) channel {
  NSArray *vars = _options[SSHOptionSendEnv];
  if (!vars.count) {
    return;
  }
  
  for (NSString *varName in vars) {
    [self _log_verbose:[NSString stringWithFormat:@"Sending env '%@'", varName]];
    
    char *varValue = getenv(varName.UTF8String);
    if (!varValue) {
      continue;
    }
    
    for(;;) {
      if ([self _notConnected]) {
        return;
      }
      int rc = ssh_channel_request_env(channel, varName.UTF8String, varValue);
      switch (rc) {
        case SSH_AGAIN:
          [self _poll];
          continue;
        case SSH_OK:
        default:
          break;
      }
      break;
    }
  }
}

- (int)_start_stdio_forwarding:(NSString *)hostPort {
  NSArray *hostAndPort = [hostPort componentsSeparatedByString:@":"];
  if (hostAndPort.count != 2) {
    NSString *errorMessage = [NSString stringWithFormat:@"Bad stdio forwarding specification: %@", hostAndPort];
    return [self _exitWithCode:SSH_ERROR andMessage:errorMessage];
  }
  
  NSString *host = [hostAndPort firstObject];
  int port = [[hostAndPort lastObject] intValue];
  
  ssh_channel channel = ssh_channel_new(_session);
  
  for (;;) {
    if ([self _notConnected]) {
      ssh_channel_free(channel);
      return SSH_ERROR;
    }
    int rc = ssh_channel_open_forward(channel,
                                      host.UTF8String,
                                      port,
                                      "stdio",
                                      port);
    switch (rc) {
      case SSH_OK:
        break;
      case SSH_AGAIN:
        [self _poll];
        continue;
      default:
      case SSH_ERROR: {
        [self _log_error];
        ssh_channel_free(channel);
        return rc;
      }
    }
    break;
  }
  
  _sessionChannel = [SSHClientConnectedChannel connect:channel withFdIn:_fdIn fdOut:_fdOut fdErr:_fdErr];
  _sessionChannel.delegate = self;
  return SSH_OK;
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
    if ([self _notConnected]) {
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
    if ([self _notConnected]) {
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
  
  address.sin_port = htons(port);
  
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
  if (_killed) {
    return;
  }
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
  if (_killed) {
    return;
  }
  if ([SSHOptionValueQUIET isEqual:_options[SSHOptionLogLevel]]) {
    return;
  }
  __write(_fdOut, message);
  __write(_fdOut, @"\r\n");
}

- (void)_device_log_info:(NSString *)message {
  if (_killed) {
    return;
  }
  [_device writeOutLn:message];
}

- (void)_log_verbose:(NSString *)message {
  if (_killed) {
    return;
  }
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
  if ([self _notConnected]) {
    return;
  }
  ssh_client_send_keepalive(_session);
}

ssh_channel __ssh_channel_open_request_auth_agent_callback(ssh_session session,
                                                           void *userdata) {
  SSHClient *client = (__bridge SSHClient *)userdata;
  return [client _authChannel];
}

- (ssh_channel)_authChannel {
  
  struct sockaddr_un sunaddr;
  int saved_errno, sock;
  
  memset(&sunaddr, 0, sizeof(sunaddr));
  sunaddr.sun_family = AF_UNIX;
  char *path = getenv("SSH_AUTH_SOCK");
  if (!path) {
    return nil;
  }
  if (strlcpy(sunaddr.sun_path, path,
              sizeof(sunaddr.sun_path)) >= sizeof(sunaddr.sun_path)) {
//    NSLog(@"max size %@", @(sizeof(sunaddr.sun_path)));
//    error("%s: path \"%s\" too long for Unix domain socket",
//          __func__, path);
//    errno = ENAMETOOLONG;
    return nil;
  }
  
  sock = socket(PF_UNIX, SOCK_STREAM, 0);
  
  if (sock == SSH_INVALID_SOCKET) {
    return nil;
  }
  
  int rc = connect(sock, (struct sockaddr *)&sunaddr, sizeof(sunaddr));
  if (rc == -1) {
    return nil;
  }
  
  ssh_channel channel = ssh_channel_new(_session);
  
  SSHClientConnectedChannel *connectedChannel = [SSHClientConnectedChannel connect:channel withSocket:sock];
  connectedChannel.delegate = self;
  [_connectedChannels addObject:connectedChannel];
  return channel;
}

- (ssh_session)_configured_session {
  ssh_session session = ssh_new();
  ssh_set_blocking(session, 0);
  
  _ssh_callbacks.userdata = (__bridge void *)self;
  _ssh_callbacks.channel_open_request_auth_agent_function = __ssh_channel_open_request_auth_agent_callback;
  
  ssh_callbacks_init(&_ssh_callbacks);
  ssh_set_callbacks(session, &_ssh_callbacks);
  
  if ([_options configureSSHSession:session] == SSH_OK) {
    return session;
  }
  
  _ssh_callbacks.userdata = NULL;
  ssh_free(session);
  return NULL;
}

#pragma mark - MAIN LOOP

- (int)main:(int) argc argv:(char **) argv {

  if (_device == nil) {
    return SSH_ERROR;
  }
  
  __block int rc = [_options parseArgs:argc argv: argv];

  if (rc != SSH_OK) {
    return [self _exitWithCode:rc andMessage:_options.exitMessage];
  }
  
  if ([_options[SSHOptionPrintVersion] isEqual:SSHOptionValueYES]) {
    [self _printVersion];
    return [self _exitWithCode:SSH_OK];
  }
  
  _session = [self _configured_session];
  if (!_session) {
    return [self _exitWithCode:SSH_ERROR andMessage:_options.exitMessage];
  }
  
  if ([_options[SSHOptionPrintConfiguration] isEqual:SSHOptionValueYES]) {
    __write(_fdOut, [_options configurationAsText]);
    return [self _exitWithCode:SSH_OK];
  }
  
  rc = [self _connect];
  if (rc != SSH_OK) {
    return [self _exitWithCode:rc];
  }

  rc = [self _verify_known_host];
  if (rc != SSH_OK) {
    return [self _exitWithCode:rc];
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
    if (_doExit) {
      break;
    }
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
  
  ssh_disconnect(_session);
  [self _log_error];
  
  [self close];
  
  return _exitCode;
}


@end
