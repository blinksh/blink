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

@interface FUTF8Term ()

@property (readonly) TerminalView *wv;

- (id)initOnTermView:(TerminalView *)term;
- (void)write:(const char *)buf length:(int)len;

@end


FILE *fterm_open(TerminalView *wv, unsigned int size)
{
  FUTF8Term *fTerm = [[FUTF8Term alloc] initOnTermView:wv];
  FILE *desc = funopen(CFBridgingRetain(fTerm), NULL, writefn, NULL, closefn);
  setvbuf(desc, NULL, _IONBF, 0);
  return desc;
}

static int writefn(void *handler, const char *buf, int size)
{
  FUTF8Term *fTerm = (__bridge FUTF8Term *)(handler);
  if (!fTerm) {
    errno = EBADF;
    return -1;
  }

  [fTerm write:buf length:size];
  return size;
}

static int closefn(void *handler)
{
  CFRelease(handler);
  return 0;
}


// UTF8 friendly stream
@implementation FUTF8Term {
  NSData *_splitChar;
}

- (id)initOnTermView:(TerminalView *)term
{
  self = [super init];

  if (self) {
    _wv = term;
  }

  return self;
}

- (void)write:(const char *)buf length:(int)len
{
  // Prepend characters to buf
  NSMutableData *data = [[NSMutableData alloc] init];
  if (_splitChar) {
    [data appendData:_splitChar];
    _splitChar = nil;
  }

  [data appendBytes:buf length:len];
  len = (unsigned int)[data length];

  // Find the first UTF mark and compare with the iterator.
  int i = 1;
  for (; i <= ((len >= 3) ? 3 : len); i++) {
    unsigned char c = ((const char *)[data bytes])[len - i];

    if (i == 1 && (c & 0x80) == 0) {
      // Single simple character, all good
      break;
    }

    // 10XXX XXXX
    if (c >> 6 == 0x02) {
      // Save character
      //split_char[i] = c;
      continue;
    }

    // Check if the character corresponds to the sequence by ORing with it
    if ((i == 2 && ((c | 0xDF) == 0xDF)) || // 110X XXXX 1 1101 1111
	(i == 3 && ((c | 0xEF) == 0xEF)) || // 1110 XXXX 2 1110 1111
	(i == 4 && ((c | 0xF7) == 0xF7))) { // 1111 0XXX 3 1111 0111
      // Complete sequence
      break;
    } else {
      // Save splitted sequences
      _splitChar = [data subdataWithRange:NSMakeRange(len - i, i)];
      break;
    }
  }

  NSString *output;
  if (_splitChar) {
    output = [[NSString alloc] initWithBytes:[data bytes] length:(len - [_splitChar length]) encoding:NSUTF8StringEncoding];
    if (!output) {
      output = [[NSString alloc] initWithBytes:[data bytes] length:(len - [_splitChar length]) encoding:NSASCIIStringEncoding];
    }
  } else {
    output = [[NSString alloc] initWithBytes:[data bytes] length:(len) encoding:NSUTF8StringEncoding];
    if (!output) {
      output = [[NSString alloc] initWithBytes:[data bytes] length:(len) encoding:NSASCIIStringEncoding];
    }
  }

  [_wv write:output];
}
@end
