/* Test of system information.
   Copyright (C) 2009-2017 Free Software Foundation, Inc.

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

/* Written by Bruno Haible <bruno@clisp.org>, 2009.  */

#include <config.h>

#include <sys/utsname.h>

#include "signature.h"
SIGNATURE_CHECK (uname, int, (struct utsname *));

#include <stdio.h>
#include <string.h>

#include "macros.h"


/* This program can be called with no arguments, then it performs a unit
   test.  Or it can be called with 1 argument, then it prints the uname
   contents to standard output.  */

int
main (int argc, char *argv[])
{
  struct utsname buf;

  memset (&buf, '?', sizeof (buf));

  ASSERT (uname (&buf) >= 0);

  /* Verify that every field's value is NUL terminated.  */
  ASSERT (strlen (buf.sysname) < sizeof (buf.sysname));
  ASSERT (strlen (buf.nodename) < sizeof (buf.nodename));
  ASSERT (strlen (buf.release) < sizeof (buf.release));
  ASSERT (strlen (buf.version) < sizeof (buf.version));
  ASSERT (strlen (buf.machine) < sizeof (buf.machine));

  if (argc > 1)
    {
      /* Show the result.  */

      printf ("uname -n = nodename       = %s\n", buf.nodename);
      printf ("uname -s = sysname        = %s\n", buf.sysname);
      printf ("uname -r = release        = %s\n", buf.release);
      printf ("uname -v = version        = %s\n", buf.version);
      printf ("uname -m = machine or cpu = %s\n", buf.machine);
    }

  return 0;
}
