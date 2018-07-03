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


@implementation SSHClientChannel
- (void)openWithClient:(SSHClient *)client {
}

- (void)closeWithClient:(SSHClient *)client {
}

@end

@implementation SSHClientMainChannel {
  
  ssh_channel _channel;
  ssh_connector _connector_in;
  ssh_connector _connector_out;
  ssh_connector _connector_err;
}

- (void)openWithClient:(SSHClient *)client {
  dispatch_async(dispatch_get_global_queue(0, 0), ^{
    __block int rc;
    [client sync: ^{
      _channel = ssh_channel_new(client.session);
      ssh_channel_set_blocking(_channel, 0);
    }];


    for (;;) {
      [client sync: ^{
        rc = ssh_channel_open_session(_channel);
      }];
      switch (rc) {
        case SSH_AGAIN: continue;
        case SSH_OK: break;
        default:
        case SSH_ERROR:
          [client sync:^{
            ssh_channel_free(_channel);
            [client exitWithCode:rc];
          }];
          return;
      }
      break;
    }

    BOOL doRequestPTY = client.options[SSHOptionRequestTTY] == SSHOptionValueYES
          || (client.options[SSHOptionRequestTTY] == SSHOptionValueAUTO && client.isTTY);
    
    if (doRequestPTY) {
      for (;;) {
        [client sync: ^{
          rc = ssh_channel_request_pty(_channel);
        }];
        switch (rc) {
          case SSH_AGAIN: continue;
          case SSH_OK: break;
          default:
          case SSH_ERROR:
            [client sync:^{
              ssh_channel_close(_channel);
              ssh_channel_free(_channel);
              [client exitWithCode:rc];
            }];
            return;
        }
        break;
      }
    }

    NSString *remoteCommand = client.options[SSHOptionRemoteCommand];
    for (;;) {
      [client sync: ^{
        if (remoteCommand) {
          rc = ssh_channel_request_exec(_channel, remoteCommand.UTF8String);
        } else {
          rc = ssh_channel_request_shell(_channel);
        }
      }];
      switch (rc) {
        case SSH_AGAIN: continue;
        case SSH_OK: break;
        default:
        case SSH_ERROR:
          [client sync:^{
            ssh_channel_close(_channel);
            ssh_channel_free(_channel);
            [client exitWithCode:rc];
          }];
          return;
      }
      break;
    }

    
    
    [client sync: ^{
      // stdin
      _connector_in = ssh_connector_new(client.session);
      ssh_connector_set_in_fd(_connector_in, client.fdIn);
      ssh_connector_set_out_channel(_connector_in, _channel, SSH_CONNECTOR_STDOUT);
      ssh_event_add_connector(client.event, _connector_in);

      // stdout
      _connector_out = ssh_connector_new(client.session);
      ssh_connector_set_in_channel(_connector_out, _channel, SSH_CONNECTOR_STDOUT);
      ssh_connector_set_out_fd(_connector_out, client.fdOut);
      ssh_event_add_connector(client.event, _connector_out);

      // stderr
      _connector_err = ssh_connector_new(client.session);
      ssh_connector_set_in_channel(_connector_err, _channel, SSH_CONNECTOR_STDERR);
      ssh_connector_set_out_fd(_connector_err, client.fdErr);
      ssh_event_add_connector(client.event, _connector_err);
    }];
  });
}

@end

@implementation SSHClientDirectForwardChannel {
  ssh_channel _channel;
  
  NSString *_remotehost;
  int _remoteport;
  NSString *_sourcehost;
  int _localport;
  
  dispatch_fd_t _listenSock;
  dispatch_queue_t _listenQueue;
  
  dispatch_source_t _listenSource;
  
}

- (instancetype)initWithAddress:(NSString *)address {
  self = [super init];
  if (self) {
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
  dispatch_async(dispatch_get_global_queue(0, 0), ^{
    __block int rc;
    _listenSock = socket(AF_INET, SOCK_STREAM, 0);
    if (_listenSock < 0) {
      [client sync:^{
        ssh_channel_free(_channel);
        [client exitWithCode:rc];
      }];
      return;
    }
    
    struct sockaddr_in address;
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    
    address.sin_port=htons(_localport);
    bind(_listenSock, (struct sockaddr *)&address,sizeof(address));
    listen(_listenSock, 15);
    
    _listenSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, _listenSock, 0, _listenQueue);

    
    dispatch_source_set_event_handler(_listenSource, ^{
      dispatch_fd_t sock = accept(_listenSock, NULL, NULL);
      [client sync: ^{
        _channel = ssh_channel_new(client.session);
        ssh_channel_set_blocking(_channel, 0);
      }];
      
      for (;;) {
        [client sync: ^{
          rc = ssh_channel_open_forward(_channel, _remotehost.UTF8String, _remoteport, _sourcehost.UTF8String, _localport);
        }];
        switch (rc) {
          case SSH_AGAIN: continue;
          case SSH_OK: break;
          default:
          case SSH_ERROR:
            [client sync:^{
              ssh_channel_free(_channel);
              [client exitWithCode:rc];
            }];
            return;
        }
        break;
      }
      
      [client sync: ^{
        // stdin
        
        ssh_connector _connector_in = ssh_connector_new(client.session);
        ssh_connector_set_in_fd(_connector_in, sock);
        ssh_connector_set_out_channel(_connector_in, _channel, SSH_CONNECTOR_BOTH);
        ssh_event_add_connector(client.event, _connector_in);
        
        // stdout
        ssh_connector _connector_out = ssh_connector_new(client.session);
        ssh_connector_set_in_channel(_connector_out, _channel, SSH_CONNECTOR_BOTH);
        ssh_connector_set_out_fd(_connector_out, sock);
        ssh_event_add_connector(client.event, _connector_out);
      }];
    });
    dispatch_resume(_listenSource);
  });
}

@end
