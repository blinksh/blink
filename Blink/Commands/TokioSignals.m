//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2019 Blink Mobile Shell Project
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


#import "TokioSignals.h"



extern void signal_release(void * signals);
extern void signal_send(void * signals, int signal);

extern char * build_get_build_id(void);

extern void build_call_service(
                               const char * url,
                               const char * method,
                               const char * body,
                               const char * content_type,
                               BOOL auth, void * ctx,
                               build_service_callback callback,
                               void ** signals);

@implementation TokioSignals {
}

+ (instancetype) callServiceURL:
  (NSString *) url
  method: (NSString *) method
  body: (NSString *) body
  contentType: (NSString *) contentType
  auth: (BOOL) auth
  ctx: (void *)ctx
  callback: (build_service_callback) callback
{
  TokioSignals *signals = [TokioSignals new];
  
  build_call_service(
                     url.UTF8String,
                     method.UTF8String,
                     body.UTF8String,
                     contentType.UTF8String,
                     auth,
                     ctx, callback, &signals->_signals);
  
  return signals;
}

+ (nullable NSString *)getBuildId {
  char *ptr = build_get_build_id();
  if (ptr) {
    return [[NSString alloc] initWithBytesNoCopy:ptr
                                          length:strlen(ptr)
                                        encoding:NSUTF8StringEncoding
                                    freeWhenDone:YES];
  } else {
    return nil;
  }
}


- (void) signalCtrlC {
  if (_signals) {
    signal_send(_signals, 0);
  }
}

- (void)dealloc {
  if (_signals) {
    signal_release(_signals);
    _signals = NULL;
  }
}

@end
