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


#import "SSHClientChannel.h"

#import "SSHClient.h"
#include <libssh/callbacks.h>

@interface ConnectedChannel : NSObject {
  NSString *_name; //For debugging;
  ssh_event _event;
  dispatch_fd_t _sockFd;
  ssh_connector _connector_in;
  ssh_connector _connector_out;
  ssh_connector _connector_err;
  ssh_channel _channel;
  ssh_channel_callbacks _cb;
  
}

@property int exitCode;
- (void)connect:(ssh_channel)channel withFdIn:(dispatch_fd_t)fdIn fdOut:(dispatch_fd_t)fdOut fdErr:(dispatch_fd_t)fdErr;
- (void)connect:(ssh_channel)channel withSockFd:(dispatch_fd_t)sockFd;
- (void)addToEvent:(ssh_event)event;
- (void)closeAndFree;
- (void)removeFromEvent;
- (void)closeSock;
- (void)on_eof;
- (void)on_close;

@end

void __channel_eof_cb(ssh_session session, ssh_channel channel, void *userdata) {
  ConnectedChannel *connectedChannel = (__bridge ConnectedChannel *)userdata;
  NSLog(@"eof %@", connectedChannel);
  [connectedChannel on_eof];
}

void __channel_close_cb(ssh_session session, ssh_channel channel, void *userdata) {
  ConnectedChannel *connectedChannel = (__bridge ConnectedChannel *)userdata;
  NSLog(@"close %@", connectedChannel);
  [connectedChannel on_close];
}

void __channel_exit_status_cb(ssh_session session,
                              ssh_channel channel,
                              int exit_status,
                              void *userdata) {
  ConnectedChannel *connectedChannel = (__bridge ConnectedChannel *)userdata;
  NSLog(@"exit_status %@", connectedChannel);
  connectedChannel.exitCode = exit_status;
}


@implementation ConnectedChannel

- (NSString *)description {
  return [self debugDescription];
}

- (NSString *)debugDescription {
  return _name ?: @"Unknown";
}

- (void)connect:(ssh_channel)channel withFdIn:(dispatch_fd_t)fdIn fdOut:(dispatch_fd_t)fdOut fdErr:(dispatch_fd_t)fdErr {
  _name = @"stdio";
  _channel = channel;
  ssh_session session = ssh_channel_get_session(_channel);
  // stdin
  _connector_in = ssh_connector_new(session);
  ssh_connector_set_in_fd(_connector_in, dup(fdIn));
  ssh_connector_set_out_channel(_connector_in, _channel, SSH_CONNECTOR_STDOUT);
  
  // stdout
  _connector_out = ssh_connector_new(session);
  ssh_connector_set_in_channel(_connector_out, _channel, SSH_CONNECTOR_STDOUT);
  ssh_connector_set_out_fd(_connector_out,dup(fdOut));
  
  // stderr
  _connector_err = ssh_connector_new(session);
  ssh_connector_set_in_channel(_connector_err, _channel, SSH_CONNECTOR_STDERR);
  ssh_connector_set_out_fd(_connector_err, dup(fdErr));
  
  _cb = calloc(1, sizeof(struct ssh_channel_callbacks_struct));
  _cb->userdata = (__bridge void *)self;
  _cb->channel_eof_function = __channel_eof_cb;
  _cb->channel_close_function = __channel_close_cb;
  _cb->channel_exit_status_function = __channel_exit_status_cb;
  
  ssh_callbacks_init(_cb);
  ssh_add_channel_callbacks(channel, _cb);
}

- (void)connect:(ssh_channel)channel withSockFd:(dispatch_fd_t)sockFd {
  _name = @"sock";
  _sockFd = sockFd;
  _channel = channel;
  ssh_session session = ssh_channel_get_session(_channel);
  
  // stdin
  _connector_in = ssh_connector_new(session);
  
  ssh_connector_set_in_fd(_connector_in, sockFd);
  ssh_connector_set_out_channel(_connector_in, _channel, SSH_CONNECTOR_BOTH);
  
  // stdout
  _connector_out = ssh_connector_new(session);
  ssh_connector_set_in_channel(_connector_out, _channel, SSH_CONNECTOR_BOTH);
  ssh_connector_set_out_fd(_connector_out, sockFd);
  
  _cb = calloc(1, sizeof(struct ssh_channel_callbacks_struct));
  _cb->userdata = (__bridge void *)self;
  _cb->channel_eof_function = __channel_eof_cb;
  _cb->channel_close_function = __channel_close_cb;
  _cb->channel_exit_status_function = __channel_exit_status_cb;
  
  ssh_callbacks_init(_cb);
  ssh_add_channel_callbacks(channel, _cb);
}

- (void)addToEvent:(ssh_event)event {
  _event = event;
  if (_connector_in) {
    ssh_event_add_connector(event, _connector_in);
  }
  
  if (_connector_out) {
    ssh_event_add_connector(event, _connector_out);
  }
  
  if (_connector_err) {
    ssh_event_add_connector(event, _connector_err);
  }
}

- (void)removeFromEvent {
//  if (!_event) {
//    return;
//  }
//  if (_connector_in) {
//    ssh_event_remove_connector(_event, _connector_in);
//  }
//  
//  if (_connector_out) {
//    ssh_event_remove_connector(_event, _connector_out);
//  }
//  
//  if (_connector_err) {
//    ssh_event_remove_connector(_event, _connector_err);
//  }
//  _event = NULL;
}

- (void)closeSock {
  if (_sockFd != SSH_INVALID_SOCKET) {
    close(_sockFd);
    _sockFd = SSH_INVALID_SOCKET;
  }
}

- (void)on_eof {
  ssh_channel_close(_channel);
}

- (void)on_close {
  [self closeAndFree];
  [self closeSock];
}

- (void)closeAndFree {
  ssh_session s = ssh_channel_get_session(_channel);
  
  if (_connector_in) {
    ssh_connector_free(_connector_in);
    _connector_in = NULL;
  }
  if (_connector_out) {
    ssh_connector_free(_connector_out);
    _connector_out = NULL;
  }
  if (_connector_err) {
    ssh_connector_free(_connector_err);
    _connector_err = NULL;
  }
  
  ssh_channel_free(_channel);
  _channel = nil;

  ssh_event_add_session(_event, s);
//  if (_channel) {
//    ssh_remove_channel_callbacks(_channel, _cb);
//    if (ssh_channel_is_open(_channel)) {
//      ssh_channel_close(_channel);
//      ssh_channel_free(_channel);
//      _channel = nil;
//    }
//  }
  
//  if (_cb) {
//    free(_cb);
//    _cb = NULL;
//  }
}

- (void)dealloc {
//  ssh_channel_free(_channel);
  _channel = NULL;
//  [self closeAndFree];
}

@end

@implementation SSHClientChannel
- (void)openWithClient:(SSHClient *)client {
}

- (void)closeWithClient:(SSHClient *)client {
}

@end

@implementation SSHClientMainChannel {
  ConnectedChannel *_connectedChannel;
}

- (void)openWithClient:(SSHClient *)client {
  __block int rc;
  ssh_channel channel = ssh_channel_new(client.session);
  ssh_channel_set_blocking(channel, 0);

  for (;;) {
    rc = ssh_channel_open_session(channel);
    switch (rc) {
      case SSH_AGAIN:
        [client poll];
        continue;
      case SSH_OK: break;
      default:
      case SSH_ERROR:
        ssh_channel_free(channel);
        [client exitWithCode:rc];
        return;
    }
    break;
  }

  BOOL doRequestPTY = client.options[SSHOptionRequestTTY] == SSHOptionValueYES
        || (client.options[SSHOptionRequestTTY] == SSHOptionValueAUTO && client.isTTY);
    
  if (doRequestPTY) {
    for (;;) {
      rc = ssh_channel_request_pty(channel);
      switch (rc) {
        case SSH_AGAIN:
          [client poll];
          continue;
        case SSH_OK: break;
        default:
        case SSH_ERROR:
          ssh_channel_close(channel);
          ssh_channel_free(channel);
          [client exitWithCode:rc];
          return;
      }
      break;
    }
  }

  NSString *remoteCommand = client.options[SSHOptionRemoteCommand];
  for (;;) {
    if (remoteCommand) {
      rc = ssh_channel_request_exec(channel, remoteCommand.UTF8String);
    } else {
      rc = ssh_channel_request_shell(channel);
    }
    switch (rc) {
      case SSH_AGAIN:
        [client poll];
        continue;
      case SSH_OK: break;
      default:
      case SSH_ERROR:
        ssh_channel_close(channel);
        ssh_channel_free(channel);
        [client exitWithCode:rc];
        return;
    }
    break;
  }

  _connectedChannel = [[ConnectedChannel alloc] init];
  [_connectedChannel connect:channel withFdIn:client.fdIn fdOut:client.fdOut fdErr:client.fdErr];
  [_connectedChannel addToEvent:client.event];
}

@end

@implementation SSHClientDirectForwardChannel {
  NSString *_remotehost;
  int _remoteport;
  NSString *_sourcehost;
  int _localport;
  
  dispatch_fd_t _listenSock;
  dispatch_queue_t _listenQueue;
  
  dispatch_source_t _listenSource;
  
  NSMutableArray<ConnectedChannel *> *_connectedChannels;
}

- (instancetype)initWithAddress:(NSString *)address {
  self = [super init];
  if (self) {
    _connectedChannels = [[NSMutableArray alloc] init];
    
    _listenQueue = dispatch_queue_create("sh.blink.sshclient.listen", DISPATCH_QUEUE_SERIAL);
    
    NSMutableArray<NSString *> *parts = [[address componentsSeparatedByString:@":"] mutableCopy];
    _remoteport = [[parts lastObject] intValue];
    [parts removeLastObject];
    _remotehost = [parts lastObject];
    [parts removeLastObject];
    _localport = [[parts lastObject] intValue];
    [parts removeLastObject];
    _sourcehost = [parts lastObject] ?: @"localhost";
  }
  return self;
}



- (void)openWithClient:(SSHClient *)client {
    __block int rc;
    _listenSock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (_listenSock < 0) {
//      [client sync:^{
//        [client exitWithCode:rc];
//      }];
      return;
    }
    int value = 1;
    setsockopt(_listenSock, SOL_SOCKET, SO_REUSEADDR, &value, sizeof(value));
    
    struct sockaddr_in address;
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    
    address.sin_port=htons(_localport);
    bind(_listenSock, (struct sockaddr *)&address,sizeof(address));
    int queueSize = 3;
    listen(_listenSock, queueSize);
    
    _listenSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, _listenSock, 0, _listenQueue);
    
    dispatch_source_set_cancel_handler(_listenSource, ^{
      close(_listenSock);
    });

    dispatch_source_set_event_handler(_listenSource, ^{
      __block ssh_channel channel;
      NSLog(@"Creating channel 1");
      dispatch_fd_t sock = accept(_listenSock, NULL, NULL);
      if (sock == SSH_INVALID_SOCKET) {
        return;
      }
      
      int noSigPipe = 1;
      setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, sizeof(noSigPipe));
      
      [client schedule:^{
        NSLog(@"Creating channel 2");
        channel = ssh_channel_new(client.session);
        ssh_channel_set_blocking(channel, 0);
      
      
        for (;;) {
          rc = ssh_channel_open_forward(channel, _remotehost.UTF8String, _remoteport, _sourcehost.UTF8String, _localport);
          switch (rc) {
            case SSH_AGAIN:
              [client poll];
              continue;
            case SSH_OK: break;
            default:
            case SSH_ERROR:
              ssh_channel_free(channel);
              [client exitWithCode:rc];
              return;
          }
          break;
        }
      
      
        ConnectedChannel *connectedChannel = [[ConnectedChannel alloc] init];
        [connectedChannel connect:channel withSockFd:sock];
        [_connectedChannels addObject:connectedChannel];
        [connectedChannel addToEvent:client.event];
      }];
    });
    dispatch_activate(_listenSource);
}

- (void)dealloc {
  if (_listenSource) {
    dispatch_cancel(_listenSource);
  }
}

@end
