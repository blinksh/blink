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

#include <libssh/callbacks.h>


@implementation SSHClientChannel {
  ssh_channel _ssh_channel;
  dispatch_source_t _channel_source;
  struct ssh_channel_callbacks_struct _callbacks;
  NSData *_pendingWriteData;
}

static int __channel_data_available(ssh_session session,
                                    ssh_channel channel,
                                    void *data,
                                    uint32_t len,
                                    int is_stderr,
                                    void *userdata) {
  SSHClientChannel *clientChannel = (__bridge SSHClientChannel *)userdata;
  NSData *readData = [NSData dataWithBytes:data length:len];
  
  //  return [clientChannel _didReceiveData:readData isSTDError:is_stderr];
  return 0;
}

static void __channel_close_received(ssh_session session,
                                     ssh_channel channel,
                                     void *userdata) {
  SSHClientChannel *clientChannel = (__bridge SSHClientChannel *)userdata;
  //  [clientChannel doCloseWithError:nil];
}

static void __channel_eof_received(ssh_session session,
                                 ssh_channel channel,
                                 void *userdata) {
  // SSHKitChannel *selfChannel = (__bridge SSHKitChannel *)userdata;
  // TODO: call a new delegate here? i.e. channelDidReceiveEOF
}

static void __channel_exit_status(ssh_session session,
                                ssh_channel channel,
                                int exit_status,
                                void *userdata) {
//  SSHKitChannel *selfChannel = (__bridge SSHKitChannel *)userdata;
//  selfChannel->_exitStatus = exit_status;

}

- (instancetype)initWithDispatchSource:(dispatch_source_t) channel_source andChannel:(ssh_channel) ssh_channel {
  if (self = [super init]) {
    _channel_source = channel_source;
    _ssh_channel = ssh_channel;
//    [self _registerCallbacks];
  }
  
  return self;
}

- (void)open {
  dispatch_block_t openHandler = [self _channel_openHandler];
  dispatch_source_set_event_handler(_channel_source, openHandler);
  dispatch_resume(_channel_source);
  openHandler();
}

- (dispatch_block_t)_channel_openHandler {
  return ^{
    int rc = ssh_channel_open_session(_ssh_channel);
    switch (rc) {
      case SSH_OK: {
        dispatch_block_t ptyHandler = [self _channel_request_ptyHandler];
        dispatch_source_set_event_handler(_channel_source, ptyHandler);
        ptyHandler();
      }
        break;
      case SSH_ERROR:
        break;
      case SSH_AGAIN:
        break;
      default:
        break;
    }
  };
}

- (dispatch_block_t)_channel_request_ptyHandler {
  return ^{
    int rc = ssh_channel_request_pty(_ssh_channel);
    switch (rc) {
      case SSH_OK: {
        dispatch_block_t shellHandler = [self _channel_request_shellHandler];
        dispatch_source_set_event_handler(_channel_source, shellHandler);
        shellHandler();
      }
        break;
      case SSH_ERROR:
        break;
      case SSH_AGAIN:
        break;
      default:
        break;
    }
  };
}

- (dispatch_block_t)_channel_request_shellHandler {
  return ^{
    int rc = ssh_channel_request_shell(_ssh_channel);
    switch (rc) {
      case SSH_OK: {
        [self _registerCallbacks];
        dispatch_source_set_event_handler(_channel_source, ^{});
        dispatch_suspend(_channel_source);
      }
        break;
      case SSH_ERROR:
        break;
      case SSH_AGAIN:
        break;
      default:
        break;
    }
  };
}


- (void)_registerCallbacks {
  
  struct ssh_channel_callbacks_struct _callbacks = {
    .userdata               = (__bridge void *)(self),
    .channel_data_function  = __channel_data_available,
    .channel_close_function = __channel_close_received,
    .channel_eof_function   = __channel_eof_received,
    .channel_exit_status_function = __channel_exit_status,
  };
  
  ssh_callbacks_init(&_callbacks);
  ssh_set_channel_callbacks(_ssh_channel, &_callbacks);
}

@end


