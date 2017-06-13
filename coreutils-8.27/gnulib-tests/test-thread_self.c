/* Test of gl_thread_self () macro.
   Copyright (C) 2011-2017 Free Software Foundation, Inc.

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

/* Written by Bruno Haible <bruno@clisp.org>, 2011.  */

#include <config.h>

#include "glthread/thread.h"

gl_thread_t main_thread;

int
main ()
{
  /* Check that gl_thread_self () can be used with just $(LIBTHREAD), not
     $(LIBMULTITHREAD), i.e. in libraries that are multithread-safe but don't
     create threads themselves.  */
  main_thread = gl_thread_self ();

  return 0;
}
