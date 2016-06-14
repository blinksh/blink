////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016 Blink Mobile Shell Project
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

#include <errno.h>

#import <Foundation/Foundation.h>

#import "fterm.h"


static int writefn(void *handler, const char *buf, int size);
static int closefn(void *handler);

FILE *fterm_open(TerminalView *wv, unsigned int size)
{
  FILE *desc = funopen(CFBridgingRetain(wv), NULL, writefn, NULL, closefn);
  setvbuf(desc, NULL, _IONBF, 0);
  return desc;
}

static int writefn(void *handler, const char *buf, int size)
{
  TerminalView *term = (__bridge TerminalView *)(handler);
  if (!term) {
    errno = EBADF;
    return -1;
  }
  //NSString *s = [NSString stringWithFormat:@"%.*s", size, buf];
  NSString *s = [[NSString alloc] initWithBytes:buf length:size encoding:NSUTF8StringEncoding];
  while (s == nil) {
    // Reduce size in case it failed (due to UTF8 chunks)
    s = [[NSString alloc] initWithBytes:buf length:--size encoding:NSUTF8StringEncoding];
  }

  [term write:s];
  return size;
}

static int closefn(void *handler)
{
  CFRelease(handler);
  return 0;
}

@implementation fTerm : NSObject
@end
