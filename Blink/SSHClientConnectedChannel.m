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

@interface StreamConnector : NSObject <NSStreamDelegate>

- (int)pairChannel:(ssh_channel)channel withSocket:(dispatch_fd_t)socket;

@end

@implementation StreamConnector {
  NSOutputStream *_outputStream;
  NSInputStream *_inputStream;
  
  NSMutableData *_outputData;
  NSMutableData *_inputData;
  
  ssh_session _session;
  ssh_channel _channel;
  int _exit_status;
  
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
  if (is_stderr) {
    if (!(connector->_channel_flags & SSH_CONNECTOR_STDERR)) {
      // ignore stderr
      return 0;
    }
  } else if (!(connector->_channel_flags & SSH_CONNECTOR_STDOUT)) {
    // ignore stdout
    return 0;
  }
  return (int)[connector write:data maxLength:len];
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
    _outputData = [[NSMutableData alloc] init];
    _inputData = [[NSMutableData alloc] init];
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
  _outputData = nil;
  
  if (_socket != SSH_INVALID_SOCKET) {
    close(_socket);
    _socket = SSH_INVALID_SOCKET;
  }
}

- (int)pairChannel:(ssh_channel)channel withSocket:(dispatch_fd_t)socket {
  _channel = channel;
  _socket = socket;
  
  CFReadStreamRef readStream = NULL;
  CFWriteStreamRef writeStream = NULL;
  CFStreamCreatePairWithSocket(NULL, socket, &readStream, &writeStream);
  _inputStream = (__bridge_transfer NSInputStream *)readStream;
  _outputStream = (__bridge_transfer NSOutputStream *)writeStream;
  
  if (_inputStream == nil) {
    return SSH_ERROR;
  }
  
  if (_outputStream == nil) {
    return SSH_ERROR;
  }
  
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

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
  
  if (_inputStream == aStream) {
    switch (eventCode) {
      case NSStreamEventHasBytesAvailable:
        [self _readin];
        return;
      case NSStreamEventEndEncountered:
        [self _readin];
        [_inputStream close];
        [_inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        ssh_channel_send_eof(_channel);
        return;
      case NSStreamEventErrorOccurred:
        NSLog(@"Error: %@", _inputStream.streamError);
        return;
      default:
        NSLog(@"input: event %@", @(eventCode));
        break;
    }
    return;
  }
  
  if (_outputStream == aStream) {
    switch (eventCode) {
      case NSStreamEventHasSpaceAvailable:
        [self _writeout];
        return;
      case NSStreamEventOpenCompleted:
        return;
      case NSStreamEventEndEncountered:
        [_outputStream close];
        [_outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        _outputStream = nil;
        return;
      case NSStreamEventErrorOccurred:
        NSLog(@"Error: %@", _outputStream.streamError);
        return;
      default:
        NSLog(@"output: event %@", @(eventCode));
        return;
    }
  }
  
  NSLog(@"Error: no handlers");
}

const int BUFFER_SIZE = 4096;

- (void)_readin {
  uint8_t buffer[BUFFER_SIZE] = {0};
  
  for (;;) {
    NSInteger len = [_inputStream read:buffer maxLength:BUFFER_SIZE];
    if (len <= 0) {
      // TODO: handle -1?
      break;
    }
    
    [_inputData appendBytes:buffer length:len];
    
    if (len < BUFFER_SIZE) {
      break;
    }
  }
  
  if (_inputData.length == 0) {
    return;
  }
  
  [self _processInputData];
}

- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len {
  if (_outputData.length == 0) {
    if (len == 0) {
      return len;
    }
    [_outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
  }
  if (len > 0) {
    [_outputData appendBytes:buffer length:len];
  }
  if (_outputStream.hasSpaceAvailable) {
    [self _writeout];
  }
  return len;
}

- (void)_writeout {
  if (_outputData.length == 0) {
    [_outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    return;
  }
  __block NSInteger written = 0;
  [_outputData enumerateByteRangesUsingBlock:^(const void * _Nonnull bytes, NSRange byteRange, BOOL * _Nonnull stop) {
    NSInteger res = [_outputStream write:bytes maxLength:byteRange.length];
    if (res <= 0) {
      *stop = YES;
      return;
    }
    written += res;
    if (res != byteRange.length) {
      *stop = YES;
    }
  }];
  

  [_outputData replaceBytesInRange:NSMakeRange(0, written) withBytes:NULL length:0];
  if (_outputData.length == 0) {
    [_outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
  }
}



- (void)_processInputData {
  __block NSInteger written = 0;
  [_inputData enumerateByteRangesUsingBlock:^(const void * _Nonnull bytes, NSRange byteRange, BOOL * _Nonnull stop) {
    int window = ssh_channel_window_size(_channel);
    if (window <= 0) {
      *stop = YES;
      return;
    }
    NSUInteger size = byteRange.length;
    int effectiveSize = (int)MIN(window, size);
    int wrote = 0;
    
    if (_channel_flags & SSH_CONNECTOR_STDOUT) {
      wrote = ssh_channel_write(_channel, bytes, effectiveSize);
    } else {
      wrote = ssh_channel_write_stderr(_channel, bytes, effectiveSize);
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
  
  [_inputData replaceBytesInRange:NSMakeRange(0, written) withBytes:NULL length:0];
}

@end

@interface DispatchConnector: NSObject {
  dispatch_io_t _out_io;
  dispatch_fd_t _out_fd;
  FILE * _out;
}

- (void) flushDataToChannel;

@end

@implementation DispatchConnector {
  ssh_session _session;
  ssh_channel _in_channel;
  ssh_channel _out_channel;
  
  dispatch_io_t _in_io;
  
  
  dispatch_queue_t _queue;
  struct ssh_channel_callbacks_struct _in_channel_cb;
  struct ssh_channel_callbacks_struct _out_channel_cb;
  
  enum ssh_connector_flags_e _in_flags;
  enum ssh_connector_flags_e _out_flags;
  
  dispatch_data_t _data;
}

static int dispatch_connector_channel_data_cb(ssh_session session,
                                              ssh_channel channel,
                                              void *data,
                                              uint32_t len,
                                              int is_stderr,
                                              DispatchConnector* connector) {
  if (is_stderr && !(connector->_in_flags & SSH_CONNECTOR_STDERR)) {
    // ignore stderr
    return 0;
  } else if (!is_stderr && !(connector->_in_flags & SSH_CONNECTOR_STDOUT)) {
    // ignore stdout
    return 0;
  }
  

  if (connector->_out_fd) {
    write(connector->_out_fd, data, len);
    return len;
  }
  
  dispatch_data_t chunk = dispatch_data_create(data, len, NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
  
  [connector writeData:chunk];
  
  return len;
}

static int dispatch_connector_channel_write_wontblock_cb(ssh_session session,
                                                         ssh_channel channel,
                                                         size_t bytes,
                                                         void *userdata) {
  DispatchConnector *connector = (__bridge DispatchConnector *)userdata;
  
  [connector flushDataToChannel];
  
  return 0;
}

- (instancetype)initWithSession:(ssh_session) session {
  if (self = [super init]) {
    _out_fd = SSH_INVALID_SOCKET;
    _session = session;
    //_queue = ssh_session_get_queue(session); //dispatch_queue_create("queue", DISPATCH_QUEUE_SERIAL);
    _queue = dispatch_queue_create("queue", DISPATCH_QUEUE_SERIAL);
    ssh_callbacks_init(&_in_channel_cb);
    ssh_callbacks_init(&_out_channel_cb);
    
    _in_channel_cb.userdata = (__bridge void *)self;
    _out_channel_cb.userdata = (__bridge void *)self;
    
    _in_channel_cb.channel_data_function = dispatch_connector_channel_data_cb;
  }
  return self;
}

- (void)dealloc {
//  if (_in_channel) {
//    ssh_remove_channel_callbacks(_in_channel, &_in_channel_cb);
//  }
//  if (_out_channel) {
//    ssh_remove_channel_callbacks(_out_channel, &_out_channel_cb);
//  }
}

- (int)setInChannel:(ssh_channel) channel flags:(enum ssh_connector_flags_e)flags {
  _in_channel = channel;
  _in_io = nil;
  _in_flags = flags;
  
  /* Fallback to default value for invalid flags */
  if (!(flags & SSH_CONNECTOR_STDOUT) && !(flags & SSH_CONNECTOR_STDERR)) {
    _in_flags = SSH_CONNECTOR_STDOUT;
  }
  
  return ssh_set_channel_callbacks(channel, &_in_channel_cb);
}

- (int)setOutChannel:(ssh_channel) channel flags:(enum ssh_connector_flags_e)flags {
  _out_channel = channel;
  _out_io = nil;
  _out_flags = flags;
  
  /* Fallback to default value for invalid flags */
  if (!(flags & SSH_CONNECTOR_STDOUT) && !(flags & SSH_CONNECTOR_STDERR)) {
    _in_flags = SSH_CONNECTOR_STDOUT;
  }
  
  return ssh_set_channel_callbacks(channel, &_out_channel_cb);
}

- (void)setInFd:(dispatch_fd_t)fd {
  _in_channel = NULL;
  _in_io = dispatch_io_create(DISPATCH_IO_STREAM, fd, _queue, ^(int error) {
    if (error) {
      NSLog(@"Error");
      return;
    }
    close(fd);
  });
  
  dispatch_io_set_low_water(_in_io, 1);
  dispatch_io_read(_in_io, 0, SIZE_MAX, _queue,
                   ^(bool done, dispatch_data_t data, int error) {

                     if (error) {
                       NSLog(@"Error");
                       return;
                     }
                     /*
                      * An invocation of the I/O handler with the done flag set, an error code of
                      * zero and an empty data object indicates that EOF was reached.
                      */
                     if (done && error == 0 && data == dispatch_data_empty) {
//                        TODO: ssh_channel_send_eof(channel)
                       NSLog(@"EOF");
                     }
                     [self writeData:data];
                   });
  
}

- (void)setOutFd:(dispatch_fd_t)fd {
  _out_channel = NULL;
  _out_fd = fd;
//  _out = fdopen(fd, "wb");
//  _out_io = dispatch_io_create(DISPATCH_IO_STREAM, fd, _queue, ^(int error) {
//    if (error) {
//      NSLog(@"Error");
//      return;
//    }
//    close(fd);
//  });
//
//  dispatch_io_set_low_water(_out_io, 1);
}

- (void)exceptFd:(dispatch_fd_t)fd {
  // TODO:
}

- (void)exceptChannel:(ssh_channel)channel {
  // TODO:
}

- (void)flushDataToChannel {
  if (!_data) {
    return;
  }
  
  if (ssh_channel_window_size(_out_channel) <=0 ) {
    return;
  }
  __block int total = 0;
  
  BOOL complete = dispatch_data_apply(_data, ^bool(dispatch_data_t  _Nonnull region, size_t offset, const void * _Nonnull buffer, size_t size) {
    int window = ssh_channel_window_size(_out_channel);
    if (window <= 0) {
      return NO;
    }
    
    
    int effectiveSize = (int)MIN(window, size);
    int wrote = 0;
    
    if (_out_flags & SSH_CONNECTOR_STDOUT) {
      wrote = ssh_channel_write(_out_channel, buffer, effectiveSize);
    } else {
      wrote = ssh_channel_write_stderr(_out_channel, buffer, effectiveSize);
    }
    
    if (wrote == SSH_ERROR) {
      return NO;
    }
    
    total += wrote;
    
    if (wrote < effectiveSize || effectiveSize < size) {
      return NO;
    }
    
    return YES;
  });
  if (complete) {
    _data = nil;
  } else {
    _data = dispatch_data_create_subrange(_data, total, dispatch_data_get_size(_data) - total);
  }
}

- (void)writeData:(dispatch_data_t) chunk {
  if (_data) {
    chunk = dispatch_data_create_concat(_data, chunk);
    _data = nil;
  }
  
  if (_out_channel) {
    _data = chunk;
    [self flushDataToChannel];
    return;
  }
  
  NSLog(@"Error!");
}

@end

@implementation SSHClientConnectedChannel {
  NSString *_name; //For debugging;
  dispatch_fd_t _sockFd;
  StreamConnector *_streamConnector;
  DispatchConnector * _connector_in;
  DispatchConnector * _connector_out;
  DispatchConnector * _connector_err;
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
  _connector_in = [[DispatchConnector alloc] initWithSession:session];
//  [_connector_in setInFd:dup(fdIn)];
  [_connector_in setInFd:fdIn];
  [_connector_in setOutChannel:_channel flags:SSH_CONNECTOR_STDOUT];

  
  // stdout
  _connector_out = [[DispatchConnector alloc] initWithSession:session];
  [_connector_out setInChannel:_channel flags:SSH_CONNECTOR_STDOUT];
//  [_connector_out setOutFd:dup(fdOut)];
  [_connector_out setOutFd:fdOut];
  
  // stderr
  _connector_err = [[DispatchConnector alloc] initWithSession:session];
  [_connector_err setInChannel:_channel flags:SSH_CONNECTOR_STDERR];
//  [_connector_err setOutFd:dup(fdErr)];
  [_connector_err setOutFd:fdErr];
 
  _cb = calloc(1, sizeof(struct ssh_channel_callbacks_struct));
  _cb->userdata = (__bridge void *)self;
  _cb->channel_eof_function = __channel_eof_cb;
  _cb->channel_close_function = __channel_close_cb;
  _cb->channel_exit_status_function = __channel_exit_status_cb;
  
  ssh_callbacks_init(_cb);
  ssh_add_channel_callbacks(channel, _cb);
}

- (void)connect:(ssh_channel)channel withSockcket:(dispatch_fd_t)sockFd {
  _name = @"stream sock";
  _streamConnector = [[StreamConnector alloc] init];
  [_streamConnector pairChannel:channel withSocket:sockFd];
}

- (void)connect:(ssh_channel)channel withSockFd:(dispatch_fd_t)sockFd {
  _name = @"sock";
  _sockFd = sockFd;
  _channel = channel;
  ssh_session session = ssh_channel_get_session(_channel);
  
  // stdin
  _connector_in = [[DispatchConnector alloc] initWithSession:session];
  [_connector_in setInFd:sockFd];
  [_connector_in setOutChannel:_channel flags:SSH_CONNECTOR_BOTH];
  
  // stdout
  _connector_out = [[DispatchConnector alloc] initWithSession:session];
  [_connector_out setInChannel:_channel flags:SSH_CONNECTOR_BOTH];
  [_connector_out setOutFd:sockFd];
  
  _cb = calloc(1, sizeof(struct ssh_channel_callbacks_struct));
  _cb->userdata = (__bridge void *)self;
  _cb->channel_eof_function = __channel_eof_cb;
  _cb->channel_close_function = __channel_close_cb;
  _cb->channel_exit_status_function = __channel_exit_status_cb;
  
  ssh_callbacks_init(_cb);
  ssh_add_channel_callbacks(channel, _cb);
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
  
  ssh_channel_free(_channel);
  _channel = nil;

  // We need to re add session
//  ssh_event_add_session(_event, s);
  
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

