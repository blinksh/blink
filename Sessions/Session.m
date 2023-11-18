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

#include <pthread.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <libgen.h> // for basename()

#import "Session.h"

static void* nextUnescapedCharacter(const char* str, const char c) {
  char* nextOccurence = strchr(str, c);
  while (nextOccurence != NULL) {
    if ((nextOccurence > str + 1) && (*(nextOccurence - 1) == '\\')) {
      // There is a backlash before the character.
      int numBackslash = 0;
      char* countBack = nextOccurence - 1;
      while ((countBack > str) && (*countBack == '\\')) { numBackslash++; countBack--; }
      if (numBackslash % 2 == 0) return nextOccurence; // even number of backslash
    } else return nextOccurence;
    nextOccurence = strchr(nextOccurence + 1, c);
  }
  return nextOccurence;
}

static char* getLastCharacterOfArgument(const char* argument) {
  if (strlen(argument) == 0) return NULL; // be safe
  if (argument[0] == '"') {
    char* endquote = nextUnescapedCharacter(argument + 1, '"');
    if (endquote != NULL) return endquote + 1;
    else return NULL;
  } else if (argument[0] == '\'') {
    char* endquote = nextUnescapedCharacter(argument + 1, '\'');
    if (endquote != NULL) return endquote + 1;
    else return NULL;
  }
  else return nextUnescapedCharacter(argument + 1, ' ');
}

static char* unquoteArgument(char* argument) {
  if (argument[0] == '"') {
    if (argument[strlen(argument) - 1] == '"') {
      argument[strlen(argument) - 1] = 0x0;
      return argument + 1;
    }
  }
  if (argument[0] == '\'') {
    if (argument[strlen(argument) - 1] == '\'') {
      argument[strlen(argument) - 1] = 0x0;
      return argument + 1;
    }
  }
  // no quotes at the beginning: replace all escaped characters:
  // '\x' -> x
  char* nextOccurence = strchr(argument, '\\');
  while ((nextOccurence != NULL) && (strlen(nextOccurence) > 0)) {
    memmove(nextOccurence, nextOccurence + 1, strlen(nextOccurence + 1) + 1);
    // strcpy(nextOccurence, nextOccurence + 1);
    nextOccurence = strchr(nextOccurence + 1, '\\');
  }
  return argument;
}

int makeargs(const char *command, char ***aa)
{
  int argc = 0;
  size_t numSpaces = 0;
  // the number of arguments is *at most* the number of spaces plus one
  const char* str = command;
  while(*str) if (*str++ == ' ') ++numSpaces;
  char** argv = (char **)malloc(sizeof(char*) * (numSpaces + 2));
  bool* dontExpand = malloc(sizeof(bool) * (numSpaces + 2));
  // n spaces = n+1 arguments, plus null at the end
  str = command;
  while (*str) {
    argv[argc] = str;
    dontExpand[argc] = false;
    argc += 1;
    char* end = getLastCharacterOfArgument(str);
    bool mustBreak = (end == NULL) || (strlen(end) == 0);
    if (!mustBreak) end[0] = 0x0;
    if ((str[0] == '\'') || (str[0] == '"')) {
      dontExpand[argc-1] = true; // don't expand arguments in quotes
    }
    argv[argc-1] = unquoteArgument(argv[argc-1]);
    if (mustBreak) break;
    str = end + 1;
    if ((argc == 1) && (argv[0][0] == '/') && (access(argv[0], R_OK) == -1)) {
      // argv[0] is a file that doesn't exist. Probably one of our commands.
      // Replace with its name:
      char* newName = basename(argv[0]);
      argv[0] = realloc(argv[0], strlen(newName));
      strcpy(argv[0], newName);
    }
    assert(argc < numSpaces + 2);
    while (str && (str[0] == ' ')) str++; // skip multiple spaces
  }
  argv[argc] = NULL;
  *aa = argv;
  free(dontExpand);

  return argc;
}

@interface Session ()

- (void)_run;

@end

void run_cleanup(void *sessionData) {
  Session *session = CFBridgingRelease(sessionData);
  [session main_cleanup];
}

void *run_session(void *sessionData)
{
  pthread_cleanup_push(run_cleanup, sessionData);
  Session *session = (__bridge Session *)sessionData;
  [session _run];
  pthread_cleanup_pop(true);
  return NULL;
}

@implementation Session {
  pthread_attr_t _attr;
  bool _attached;
  NSString *_args;
  char **_argv;
}

- (void)_run {
  assert(_args.UTF8String != NULL);
  int argc = makeargs(_args.UTF8String, &_argv);
  [self main:argc argv:_argv];
}

- (void)main_cleanup {
  [_stream close];
  dispatch_sync(dispatch_get_main_queue(), ^{
    [_delegate sessionFinished];
  });
  _stream = nil;
  _device = nil;
  _delegate = nil;
  free(_argv);
  _argv = NULL;
}

- (id)initWithDevice:(TermDevice *)device andParams:(SessionParams *)params
{
  self = [super init];

  if (self) {
    _device = device;
    _stream = [_device.stream duplicate];
    _sessionParams = params;
  }

  return self;
}

- (void)executeWithArgs:(NSString *)argstr
{
  _attached = NO;
  _args = argstr;

  CFTypeRef selfRef = CFBridgingRetain(self);
  pthread_attr_init(&_attr);
  pthread_attr_setdetachstate(&_attr, PTHREAD_CREATE_DETACHED);
  pthread_create(&_tid, &_attr, run_session, (void *)selfRef);
  pthread_attr_destroy(&_attr);
}

- (void)executeAttachedWithArgs:(NSString *)argstr
{
  _attached = YES;
  _args = argstr;

  CFTypeRef selfRef = CFBridgingRetain(self);
  pthread_attr_setdetachstate(&_attr, PTHREAD_CREATE_JOINABLE);
  pthread_create(&_tid, NULL, run_session, (void *)selfRef);
  pthread_join(_tid, NULL);
  pthread_attr_destroy(&_attr);
}

- (int)main:(int)argc argv:(char **)argv {
  return 0;
}

- (void)sigwinch {
}

- (void)kill {
}

- (void)suspend
{
}

- (BOOL)handleControl:(NSString *)control
{
  return NO;
}

- (void)setActiveSession {
}

- (void)dealloc {
  _device = nil;
  _stream = nil;
}

@end
