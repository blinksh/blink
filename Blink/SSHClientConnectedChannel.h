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


#import <Foundation/Foundation.h>
#include <libssh/libssh.h>
#include <libssh/callbacks.h>

NS_ASSUME_NONNULL_BEGIN

@class SSHClientConnectedChannel;

@protocol SSHClientConnectedChannelDelegate <NSObject>

- (void)connectedChannelDidClose:(SSHClientConnectedChannel *) connectedChannel;

@end

@interface SSHClientConnectedChannel : NSObject

@property (weak) id<SSHClientConnectedChannelDelegate> delegate;
@property (readonly) int exit_status;
@property (readonly)ssh_channel channel;

- (void)close;

+ (instancetype)connect:(ssh_channel)channel withFdIn:(dispatch_fd_t)fdIn fdOut:(dispatch_fd_t)fdOut fdErr:(dispatch_fd_t)fdErr;
+ (instancetype)connect:(ssh_channel)channel withSocket:(dispatch_fd_t)sockFd;

@end


NS_ASSUME_NONNULL_END
