/* Case-insensitive buffer comparator.
   Copyright (C) 1996-1997, 2000, 2003, 2006, 2009-2017 Free Software
   Foundation, Inc.

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

/* Written by Jim Meyering.  */

#include "config.h"

#include "memcasecmp.h"

#include <ctype.h>
#include <limits.h>

/* Like memcmp, but ignore differences in case.
   Convert to upper case (not lower) before comparing so that
   join -i works with sort -f.  */

int
memcasecmp (const void *vs1, const void *vs2, size_t n)
{
  size_t i;
  char const *s1 = vs1;
  char const *s2 = vs2;
  for (i = 0; i < n; i++)
    {
      unsigned char u1 = s1[i];
      unsigned char u2 = s2[i];
      int U1 = toupper (u1);
      int U2 = toupper (u2);
      int diff = (UCHAR_MAX <= INT_MAX ? U1 - U2
                  : U1 < U2 ? -1 : U2 < U1);
      if (diff)
        return diff;
    }
  return 0;
}
