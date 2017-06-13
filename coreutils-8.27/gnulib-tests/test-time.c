/* Test of <time.h> substitute.
   Copyright (C) 2007, 2009-2017 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* Written by Bruno Haible <bruno@clisp.org>, 2007.  */

#include <config.h>

#include <time.h>

#include "verify.h"

/* Check that the types are all defined.  */
struct timespec t1;
#if 0
/* POSIX:2008 does not require pid_t in <time.h> unconditionally, and indeed
   it's missing on Mac OS X 10.5, FreeBSD 6.4, OpenBSD 4.9, mingw.  */
pid_t t2;
#endif

/* Check that NULL can be passed through varargs as a pointer type,
   per POSIX 2008.  */
verify (sizeof NULL == sizeof (void *));

int
main (void)
{
  return 0;
}
