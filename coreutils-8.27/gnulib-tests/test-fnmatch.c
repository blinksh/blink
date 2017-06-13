/* Test of fnmatch string matching function.
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

/* Written by Simon Josefsson <simon@josefsson.org>, 2009.  */

#include <config.h>

#include <fnmatch.h>

#include "signature.h"
SIGNATURE_CHECK (fnmatch, int, (char const *, char const *, int));

#include "macros.h"

int
main ()
{
  int res;

  ASSERT (res = fnmatch ("", "", 0) == 0);

  ASSERT (res = fnmatch ("*", "", 0) == 0);
  ASSERT (res = fnmatch ("*", "foo", 0) == 0);
  ASSERT (res = fnmatch ("*", "bar", 0) == 0);
  ASSERT (res = fnmatch ("*", "*", 0) == 0);
  ASSERT (res = fnmatch ("**", "f", 0) == 0);
  ASSERT (res = fnmatch ("**", "foo.txt", 0) == 0);
  ASSERT (res = fnmatch ("*.*", "foo.txt", 0) == 0);

  ASSERT (res = fnmatch ("foo*.txt", "foobar.txt", 0) == 0);

  ASSERT (res = fnmatch ("foo.txt", "foo.txt", 0) == 0);
  ASSERT (res = fnmatch ("foo\\.txt", "foo.txt", 0) == 0);
  ASSERT (res = fnmatch ("foo\\.txt", "foo.txt", FNM_NOESCAPE) == FNM_NOMATCH);

  /* Verify that an unmatched [ is treated as a literal, as POSIX
     requires.  This test ensures that glibc Bugzilla bug #12378 stays
     fixed.
   */
  ASSERT (res = fnmatch ("[/b", "[/b", 0) == 0);

  return 0;
}
