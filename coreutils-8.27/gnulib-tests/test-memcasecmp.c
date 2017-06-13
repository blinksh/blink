/*
 * Copyright (C) 2008-2017 Free Software Foundation, Inc.
 * Written by Simon Josefsson and Bruno Haible
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

#include <config.h>

#include "memcasecmp.h"

#include <string.h>

#include "zerosize-ptr.h"
#include "macros.h"

int
main (void)
{
  /* Test equal / not equal distinction.  */
  ASSERT (memcasecmp (zerosize_ptr (), zerosize_ptr (), 0) == 0);
  ASSERT (memcasecmp ("foo", "foobar", 2) == 0);
  ASSERT (memcasecmp ("foo", "foobar", 3) == 0);
  ASSERT (memcasecmp ("foo", "foobar", 4) != 0);
  ASSERT (memcasecmp ("foo", "bar", 1) != 0);
  ASSERT (memcasecmp ("foo", "bar", 3) != 0);

  /* Test less / equal / greater distinction.  */
  ASSERT (memcasecmp ("foo", "moo", 4) < 0);
  ASSERT (memcasecmp ("moo", "foo", 4) > 0);
  ASSERT (memcasecmp ("oomph", "oops", 3) < 0);
  ASSERT (memcasecmp ("oops", "oomph", 3) > 0);
  ASSERT (memcasecmp ("foo", "foobar", 4) < 0);
  ASSERT (memcasecmp ("foobar", "foo", 4) > 0);

  /* Test embedded NULs.  */
  ASSERT (memcasecmp ("1\0", "2\0", 2) < 0);
  ASSERT (memcasecmp ("2\0", "1\0", 2) > 0);
  ASSERT (memcasecmp ("x\0""1", "x\0""2", 3) < 0);
  ASSERT (memcasecmp ("x\0""2", "x\0""1", 3) > 0);

  /* The Next x86 OpenStep bug shows up only when comparing 16 bytes
     or more and with at least one buffer not starting on a 4-byte boundary.
     William Lewis provided this test program.   */
  {
    char foo[21];
    char bar[21];
    int i;
    for (i = 0; i < 4; i++)
      {
        char *a = foo + i;
        char *b = bar + i;
        strcpy (a, "--------01111111");
        strcpy (b, "--------10000000");
        ASSERT (memcasecmp (a, b, 16) < 0);
      }
  }

  return 0;
}
