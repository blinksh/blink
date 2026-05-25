////////////////////////////////////////////////////////////////////////////////
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

#include <sys/ioctl.h>

#import "TermDevice.h"

/// Splits a shell-style command line into argv, honoring single/double quotes
/// and backslash escapes. The caller owns the returned argv (free it) and must
/// keep `command` alive while the argv is used — argv entries point into it.
extern int makeargs(const char *command, char ***aa);

/// Minimal snapshot contract used by Session.
/// - hasEncodedState: quick guard
/// - takeEncodedState: returns bytes and CLEARS them (consume-on-read)
/// - putEncodedState: overwrites bytes
@protocol BKSessionParamsSnapshotting <NSObject>
- (BOOL)hasEncodedState;
- (nullable NSData *)takeEncodedState;
- (void)putEncodedState:(NSData *)data;
@end

/// Typealias for session parameter objects that can be snapshotted and securely coded
typedef id<BKSessionParamsSnapshotting, NSSecureCoding> BKSessionParams;

@protocol SessionDelegate

- (void)sessionFinished;

@end

@interface Session : NSObject {
  pthread_t _tid;
  TermStream *_stream;
  TermDevice *_device;
}

// NOTE: Now protocol-typed (no concrete base class).
@property (strong, atomic) BKSessionParams sessionParams;
@property (strong) TermStream *stream;
@property (strong) TermDevice *device;
@property (readonly) pthread_t tid;

@property (weak) id<SessionDelegate> delegate;

- (id)init NS_UNAVAILABLE;
- (id)initWithDevice:(TermDevice *)device
            andParams:(BKSessionParams)params;

- (void)executeWithArgs:(NSString *)args;
- (void)executeAttachedWithArgs:(NSString *)args;
- (int)main:(int)argc argv:(char **)argv;
- (void)main_cleanup;
- (void)sigwinch;
- (void)kill;
- (void)suspend;
- (void)handleControl:(NSString *)control;

@end
