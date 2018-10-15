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

void __write_data(NSMutableData *data, NSOutputStream *output) {
  if (data.length == 0) {
    [output removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    return;
  }
  __block NSInteger written = 0;
  [data enumerateByteRangesUsingBlock:^(const void * _Nonnull bytes, NSRange byteRange, BOOL * _Nonnull stop) {
    NSInteger res = [output write:bytes maxLength:byteRange.length];
    if (res <= 0) {
      *stop = YES;
      return;
    }
    written += res;
    if (res != byteRange.length) {
      *stop = YES;
    }
  }];
  
  
  [data replaceBytesInRange:NSMakeRange(0, written) withBytes:NULL length:0];
  if (data.length == 0) {
    [output removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
  }
}


NSInteger __write_buffer(const uint8_t *buffer, NSUInteger len, NSMutableData *data, NSOutputStream *output) {
  if (data.length == 0) {
    if (len == 0) {
      return len;
    }
    [output scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
  }
  if (len > 0) {
    [data appendBytes:buffer length:len];
  }
  if (output.hasSpaceAvailable) {
    __write_data(data, output);
  }
  return len;
}

void __write_channel(ssh_channel channel, NSMutableData *data, enum ssh_connector_flags_e channel_flags) {
  __block NSInteger written = 0;
  [data enumerateByteRangesUsingBlock:^(const void * _Nonnull bytes, NSRange byteRange, BOOL * _Nonnull stop) {
    int window = ssh_channel_window_size(channel);
    if (window <= 0) {
      *stop = YES;
      return;
    }
    NSUInteger size = byteRange.length;
    int effectiveSize = (int)MIN(window, size);
    // We can't write to channel after eof
    if (effectiveSize == 0 || ssh_channel_is_eof(channel)) {
      *stop = YES;
      return;
    }
    int wrote = 0;
    
    if (channel_flags & SSH_CONNECTOR_STDOUT) {
      wrote = ssh_channel_write(channel, bytes, effectiveSize);
    } else {
      wrote = ssh_channel_write_stderr(channel, bytes, effectiveSize);
    }
    
    if (wrote == SSH_ERROR) {
      *stop = YES;
      return;
    }
    
    written += wrote;
    
    if (wrote < effectiveSize || effectiveSize < size) {
      *stop = YES;
      return;
    }
  }];
  
  [data replaceBytesInRange:NSMakeRange(0, written) withBytes:NULL length:0];
}

const int BUFFER_SIZE = 4096;
void __readin(NSInputStream *inputStream, NSMutableData *data) {
  uint8_t buffer[BUFFER_SIZE] = {0};
  
  for (;;) {
    NSInteger len = [inputStream read:buffer maxLength:BUFFER_SIZE];
    if (len <= 0) {
      // TODO: handle -1?
      break;
    }
    
    [data appendBytes:buffer length:len];
    
    if (len < BUFFER_SIZE) {
      break;
    }
  }
  
  if (data.length == 0) {
    return;
  }
}

@interface StreamConnector : SSHClientConnectedChannel <NSStreamDelegate>

- (int)pairChannel:(ssh_channel)channel withSocket:(dispatch_fd_t)socket;

@end

@interface SockConnector : SSHClientConnectedChannel

- (int)pairChannel:(ssh_channel)channel withFdIn:(dispatch_fd_t)fdIn fdOut:(dispatch_fd_t)fdOut fdErr:(dispatch_fd_t)fdErr;

@end



@implementation SSHClientConnectedChannel {
@protected
  int _exit_status;
  ssh_channel _channel;
}

- (void)close {
  [_delegate connectedChannelDidClose:self];
}

+ (instancetype)connect:(ssh_channel)channel withSocket:(dispatch_fd_t)sockFd {
  StreamConnector *connector = [[StreamConnector alloc] init];
  int rc = [connector pairChannel:channel withSocket:sockFd];
  if (rc == SSH_OK) {
    return connector;
  }
  return NULL;
}

+ (instancetype)connect:(ssh_channel)channel withFdIn:(dispatch_fd_t)fdIn fdOut:(dispatch_fd_t)fdOut fdErr:(dispatch_fd_t)fdErr {
  SockConnector *connector = [[SockConnector alloc] init];
  int rc = [connector pairChannel:channel withFdIn:fdIn fdOut:fdOut fdErr:fdErr];
  if (rc == SSH_OK) {
    return connector;
  }
  return NULL;
}

@end



@implementation StreamConnector {
  NSInputStream *_inputStream;
  NSOutputStream *_outputStream;
  
  NSMutableData *_inputData;
  NSMutableData *_outputData;
  
  struct ssh_channel_callbacks_struct _channel_cb;
  enum ssh_connector_flags_e _channel_flags;

  dispatch_fd_t _socket;
}

static int __stream_connector_channel_data_cb(ssh_session session,
                                              ssh_channel channel,
                                              void *data,
                                              uint32_t len,
                                              int is_stderr,
                                              StreamConnector* connector) {
  if (connector->_channel_flags == SSH_CONNECTOR_BOTH) {
    return (int)__write_buffer(data, len, connector->_outputData, connector->_outputStream);
  }
  return 0;
}

void __stream_connector_channel_eof_cb(ssh_session session, ssh_channel channel, StreamConnector* connector) {
  ssh_channel_close(channel);
}

void __stream_connector_channel_close_cb(ssh_session session, ssh_channel channel, StreamConnector* connector) {
  [connector close];
}

void __stream_connector_channel_exit_status_cb(ssh_session session,
                              ssh_channel channel,
                              int exit_status,
                              StreamConnector* connector) {
  connector->_exit_status = exit_status;
}

- (instancetype)init {
  if (self = [super init]) {
    _socket = SSH_INVALID_SOCKET;
  }
  
  return self;
}

- (void)dealloc {
  [self close];
}

- (void)close {
  [_inputStream close];
  [_outputStream close];
  
  [_inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
  [_outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

  _inputStream = nil;
  _outputStream = nil;
  
  _inputData = nil;
  _outputData = nil;
  
  if (_socket != SSH_INVALID_SOCKET) {
    close(_socket);
    _socket = SSH_INVALID_SOCKET;
  }
  
  _channel_cb.userdata = NULL;
  [super close];
}

- (int)pairChannel:(ssh_channel)channel withSocket:(dispatch_fd_t)socket {
  _channel = channel;
  _socket = socket;
  
  CFReadStreamRef readStream = NULL;
  CFWriteStreamRef writeStream = NULL;
  CFStreamCreatePairWithSocket(NULL, socket, &readStream, &writeStream);
  
  if (readStream == nil || writeStream == nil) {
    return SSH_ERROR;
  }
  
  _inputStream = (__bridge_transfer NSInputStream *)readStream;
  _outputStream = (__bridge_transfer NSOutputStream *)writeStream;
  
  _channel_flags = SSH_CONNECTOR_BOTH;
  
  _channel_cb.userdata = (__bridge void *)self;
  _channel_cb.channel_data_function = __stream_connector_channel_data_cb;
  _channel_cb.channel_eof_function = __stream_connector_channel_eof_cb;
  _channel_cb.channel_close_function = __stream_connector_channel_close_cb;
  _channel_cb.channel_exit_status_function = __stream_connector_channel_exit_status_cb;
  
  ssh_callbacks_init(&_channel_cb);
  int rc = ssh_add_channel_callbacks(_channel, &_channel_cb);
  if (rc != SSH_OK) {
    _inputStream = nil;
    _outputStream = nil;
    return rc;
  }
  
  _outputData = [[NSMutableData alloc] init];
  _inputData = [[NSMutableData alloc] init];
  
  _inputStream.delegate = self;
  _outputStream.delegate = self;
  
  [_inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
  [_outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
  
  if (_inputStream.streamStatus == NSStreamStatusNotOpen) {
    [_inputStream open];
  }
  if (_outputStream.streamStatus == NSStreamStatusNotOpen) {
    [_outputStream open];
  }
  return SSH_OK;
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode {
  int remote_eof = 0;
  if (_inputStream == stream) {
    switch (eventCode) {
      case NSStreamEventHasBytesAvailable:
        __readin(_inputStream, _inputData);
        __write_channel(_channel, _inputData, _channel_flags);
        return;
      case NSStreamEventEndEncountered:
        __readin(_inputStream, _inputData);
        __write_channel(_channel, _inputData, _channel_flags);
        [_inputStream close];
        [_inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        _inputStream = nil;
        remote_eof = ssh_channel_is_eof(_channel);
        if (!remote_eof) {
          ssh_channel_send_eof(_channel);
        }
        return;
      case NSStreamEventOpenCompleted:
        return;
      case NSStreamEventErrorOccurred:
        NSLog(@"Error: %@", _inputStream.streamError);
        [_inputStream close];
        [_inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        _inputStream = nil;
        remote_eof = ssh_channel_is_eof(_channel);
        if (!remote_eof) {
          ssh_channel_send_eof(_channel);
        }
        return;
      default:
        NSLog(@"input: event %@", @(eventCode));
        break;
    }
    return;
  }
  
  
  switch (eventCode) {
    case NSStreamEventHasSpaceAvailable:
      __write_data(_outputData, _outputStream);
      return;
    case NSStreamEventOpenCompleted:
      return;
    case NSStreamEventEndEncountered:
      [_outputStream close];
      [_outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
      _outputStream = nil;
      return;
    case NSStreamEventErrorOccurred:
      NSLog(@"Error: %@", stream.streamError);
      [_outputStream close];
      [_outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
      _outputStream = nil;
      return;
    default:
      NSLog(@"output: event %@", @(eventCode));
      return;
  }
}

@end

@implementation SockConnector {
  CFSocketRef _socketRef;
  CFRunLoopSourceRef _sourceRef;
  
  dispatch_fd_t _outFd;
  dispatch_fd_t _errFd;
  
  NSMutableData *_inputData;
  
  struct ssh_channel_callbacks_struct _channel_cb;
  enum ssh_connector_flags_e _channel_flags;
}

static int __sock_connector_channel_data_cb(ssh_session session,
                                            ssh_channel channel,
                                            void *data,
                                            uint32_t len,
                                            int is_stderr,
                                            SockConnector* connector) {
  ssize_t written = 0;
  if (is_stderr && connector->_errFd != SSH_INVALID_SOCKET) {
    written = write(connector->_errFd, data, len);
  } else {
    written = write(connector->_outFd, data, len);
  }
  if (written < 0) {
    return SSH_ERROR;
  }
  return (int)written;
}

void __sock_connector_channel_eof_cb(ssh_session session, ssh_channel channel, SockConnector* connector) {
  ssh_channel_close(channel);
}

void __sock_connector_channel_close_cb(ssh_session session, ssh_channel channel, SockConnector* connector) {
  [connector close];
}

void __sock_connector_channel_exit_status_cb(ssh_session session,
                                             ssh_channel channel,
                                             int exit_status,
                                             SockConnector* connector) {
  connector->_exit_status = exit_status;
}

void __sock_callback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
  SockConnector *connector = (__bridge SockConnector*)info;
  switch (type) {
    case kCFSocketReadCallBack: {
      const int BUFFER_SIZE = 4096;
      uint8_t buffer[4096] = {0};
      
      for (;;) {
        ssize_t len = read(CFSocketGetNative(s), buffer, BUFFER_SIZE);
        if (len == 0) { // EOF
          if (connector->_inputData.length > 0) {
            __write_channel(connector->_channel, connector->_inputData, SSH_CONNECTOR_STDOUT);
          }
          ssh_channel_send_eof(connector->_channel);
//          CFRunLoopRemoveSource(CFRunLoopGetCurrent(), connector->_sourceRef, kCFRunLoopDefaultMode);
          return;
        } else if (len < 0) {
          // try again
          break;
        }
        
        [connector->_inputData appendBytes:buffer length:len];
        
        if (len < BUFFER_SIZE) {
          break;
        }
      }

      __write_channel(connector->_channel, connector->_inputData, SSH_CONNECTOR_STDOUT);
    }
      break;
      
    default:
      break;
  }
}

- (int)pairChannel:(ssh_channel)channel withFdIn:(dispatch_fd_t)fdIn fdOut:(dispatch_fd_t)fdOut fdErr:(dispatch_fd_t)fdErr {
  _channel = channel;
  _inputData = [[NSMutableData alloc] init];
  
  CFSocketContext ctx = {.info = (__bridge void*)self};
  _socketRef = CFSocketCreateWithNative(NULL, fdIn, kCFSocketReadCallBack, __sock_callback, &ctx);
  
  CFOptionFlags flags = CFSocketGetSocketFlags(_socketRef);
  flags =~ kCFSocketCloseOnInvalidate;
  CFSocketSetSocketFlags(_socketRef, flags);
  _sourceRef = CFSocketCreateRunLoopSource(NULL, _socketRef, 0);
  
  _outFd = fdOut;
  _errFd = fdErr;
  
  _channel_flags = SSH_CONNECTOR_BOTH;
  
  _channel_cb.userdata = (__bridge void *)self;
  _channel_cb.channel_data_function = __sock_connector_channel_data_cb;
  _channel_cb.channel_eof_function = __sock_connector_channel_eof_cb;
  _channel_cb.channel_close_function = __sock_connector_channel_close_cb;
  _channel_cb.channel_exit_status_function = __sock_connector_channel_exit_status_cb;
  
  ssh_callbacks_init(&_channel_cb);
  int rc = ssh_add_channel_callbacks(_channel, &_channel_cb);
  if (rc != SSH_OK) {
    CFRelease(_sourceRef);
    _sourceRef = nil;
    CFSocketInvalidate(_socketRef);
    CFRelease(_socketRef);
    _socketRef = nil;
    return rc;
  }
  
  CFRunLoopAddSource(CFRunLoopGetCurrent(), _sourceRef, kCFRunLoopDefaultMode);
  
  
  return SSH_OK;
}

- (void)close {
  if (_sourceRef) {
    CFRunLoopSourceInvalidate(_sourceRef);
    CFRelease(_sourceRef);
    _sourceRef = NULL;
  }
  if (_socketRef) {
    CFSocketInvalidate(_socketRef);
    CFRelease(_socketRef);
    _socketRef = NULL;
  }
  
  _channel_cb.userdata = NULL;
  [super close];
}

- (void)dealloc {
  [self close];
}

@end

