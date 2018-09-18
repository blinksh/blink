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


#ifndef blink_compat_h
#define blink_compat_h
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>
#include <limits.h>
#include "ios_error.h"

#define fatal printf
#define verbose printf
#define error printf
#define debug printf
#define debug2 printf
#define debug3 printf

#define explicit_bzero(data, len) memset_s(data, len, 0x0, len)

#define xstrdup strdup

#define SSH_LISTEN_BACKLOG    128
#define SSH_AUTHSOCKET_ENV_NAME "SSH_AUTH_SOCK"
#define SSH_AGENTPID_ENV_NAME  "SSH_AGENT_PID"

#define SECONDS    1
#define MINUTES    (SECONDS * 60)
#define HOURS    (MINUTES * 60)
#define DAYS    (HOURS * 24)
#define WEEKS    (DAYS * 7)


/* readpass.c */

#define RP_ECHO      0x0001
#define RP_ALLOW_STDIN    0x0002
#define RP_ALLOW_EOF    0x0004
#define RP_USE_ASKPASS    0x0008

char  *read_passphrase(const char *, int);
int   ask_permission(const char *, ...) __attribute__((format(printf, 1, 2)));

#define MINIMUM(a, b)  (((a) < (b)) ? (a) : (b))
#define MAXIMUM(a, b)  (((a) > (b)) ? (a) : (b))
#define ROUNDUP(x, y)   ((((x)+((y)-1))/(y))*(y))

long convtime(const char *s);
void freezero(void *ptr, size_t sz);
void lowercase(char *s);

#endif /* blink_compat_h */
