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

@class SessionParams;

typedef struct SessionArgs {
  CFTypeRef session;
  const char *args;
  bool attached;
} SessionArgs;


@protocol SessionDelegate

- (void)sessionFinished;
- (void)indexCommand:(NSString *)cmdLine;

@end

@interface Session : NSObject {
  pthread_t _tid;
  TermStream *_stream;
  TermDevice *_device;
}

@property (strong, atomic) SessionParams *sessionParams;
@property (strong) TermStream *stream;
@property (strong) TermDevice *device;

@property (weak) NSObject<SessionDelegate>* delegate;

- (id)init __unavailable;
- (id)initWithDevice:(TermDevice *)device andParams:(SessionParams *)params;
- (void)executeWithArgs:(NSString *)args;
- (void)executeAttachedWithArgs:(NSString *)args;
- (int)main:(int)argc argv:(char **)argv;
- (void)sigwinch;
- (void)kill;
- (void)suspend;
- (BOOL)handleControl:(NSString *)control;
- (void)setActiveSession;

@end
