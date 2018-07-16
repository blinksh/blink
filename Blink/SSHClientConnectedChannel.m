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


#import "SSHClientConnectedChannel.h"

#import "SSHClient.h"
#include <libssh/callbacks.h>

@implementation SSHClientConnectedChannel {
  NSString *_name; //For debugging;
  ssh_event _event;
  dispatch_fd_t _sockFd;
  ssh_connector _connector_in;
  ssh_connector _connector_out;
  ssh_connector _connector_err;
  ssh_channel_callbacks _cb;
}

void __channel_eof_cb(ssh_session session, ssh_channel channel, void *userdata) {
    SSHClientConnectedChannel *connectedChannel = (__bridge SSHClientConnectedChannel *)userdata;
    NSLog(@"eof %@", connectedChannel);
    [connectedChannel on_eof];
}

void __channel_close_cb(ssh_session session, ssh_channel channel, void *userdata) {
    SSHClientConnectedChannel *connectedChannel = (__bridge SSHClientConnectedChannel *)userdata;
    NSLog(@"close %@", connectedChannel);
    [connectedChannel on_close];
}

void __channel_exit_status_cb(ssh_session session,
                              ssh_channel channel,
                              int exit_status,
                              void *userdata) {
  SSHClientConnectedChannel *connectedChannel = (__bridge SSHClientConnectedChannel *)userdata;
  NSLog(@"exit_status %@", connectedChannel);
  connectedChannel.exitCode = exit_status;
}


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

  [_delegate connectedChannelDidClose:self];
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

  // We need to re add session
  ssh_event_add_session(_event, s);
  
  if (_cb) {
    free(_cb);
    _cb = NULL;
  }
}

- (void)dealloc {
//  ssh_channel_free(_channel);
  _channel = NULL;
//  [self closeAndFree];
}

@end
