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


#import "SSHClientPortListener.h"
#include <libssh/libssh.h>
#include <netinet/in.h>
#include <netinet/tcp.h>


@interface SSHClientPortListener () <NSStreamDelegate>
@end

@implementation SSHClientPortListener {
  CFSocketRef _socketRef;
  CFRunLoopSourceRef _sourceRef;
}

- (instancetype)initInitWithAddress:(NSString *)strAddress {
  if (self = [super init]) {
    _listenSock = SSH_INVALID_SOCKET;
    NSMutableArray<NSString *> *parts = [[strAddress componentsSeparatedByString:@":"] mutableCopy];
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

void _socketCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
  CFSocketNativeHandle *socket = (CFSocketNativeHandle *)data;
  SSHClientPortListener *client = (__bridge SSHClientPortListener *)info;
  
  int val = 1;
  setsockopt(*socket, IPPROTO_TCP, TCP_NODELAY, &val, sizeof(val));
  NSLog(@"Blink: TCP_NODELAY=1");
  
  fcntl(*socket, F_SETFL, O_NONBLOCK);

  
  [client.delegate sshClientPortListener:client acceptedSocket:*socket];
}

- (int)listen {

  CFSocketContext ctx = {
    .info =  (__bridge void *)self
  };

  struct sockaddr_in address = {
    .sin_family = AF_INET,
    .sin_addr.s_addr = INADDR_ANY,
    .sin_port = htons(_localport)
  };
  
  CFSocketSignature signature = {
    .protocolFamily = AF_INET,
    .socketType = SOCK_STREAM,
    .protocol = IPPROTO_TCP,
    .address = CFDataCreate(NULL, (UInt8 *)&address, sizeof(struct sockaddr_in))
  };
  
  _socketRef = CFSocketCreateWithSocketSignature(NULL, &signature, kCFSocketAcceptCallBack, _socketCallback, &ctx);
  fcntl(CFSocketGetNative(_socketRef), F_SETFL, O_NONBLOCK);
  
  if (_socketRef == nil) {
    return SSH_ERROR;
  }
  
  int yes = 1;
  setsockopt(CFSocketGetNative(_socketRef), SOL_SOCKET, SO_REUSEADDR, (void*)&yes, sizeof(yes));
  
  _sourceRef = CFSocketCreateRunLoopSource(NULL, _socketRef, 0);
  
  if (_socketRef == nil) {
    return SSH_ERROR;
  }

  CFRunLoopAddSource(CFRunLoopGetCurrent(), _sourceRef, kCFRunLoopCommonModes);
  
  return SSH_OK;
}

- (void)close {
  if (_sourceRef) {
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), _sourceRef, kCFRunLoopCommonModes);
    CFRelease(_sourceRef);
    _sourceRef = NULL;
  }
  
  if (_socketRef) {
    CFSocketInvalidate(_socketRef);
    CFRelease(_socketRef);
    _socketRef = NULL;
  }
  
}

- (void)dealloc {
  [self close];
}

@end
