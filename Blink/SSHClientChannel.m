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
#include <libssh/libssh.h>
#include <libssh/callbacks.h>


@implementation SSHClientChannel {
  ssh_channel _ssh_channel;
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


- (void)_registerCallbacks {
  
  struct ssh_channel_callbacks_struct _callbacks = {
    .userdata               = (__bridge void *)(self),
    .channel_data_function  = __channel_data_available,
    .channel_close_function = __channel_close_received,
    .channel_eof_function   = __channel_eof_received,
    .channel_exit_status_function = __channel_exit_status,
  };
  
  ssh_channel_select
  ssh_callbacks_init(&_callbacks);
  ssh_set_channel_callbacks(_ssh_channel, &_callbacks);
}

@end


