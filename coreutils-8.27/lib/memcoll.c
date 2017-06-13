/* Locale-specific memory comparison.

   Copyright (C) 1999, 2002-2004, 2006, 2009-2017 Free Software Foundation,
   Inc.

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

/* Contributed by Paul Eggert <eggert@twinsun.com>.  */

#include "config.h"

#include "memcoll.h"

#include <errno.h>
#include <stdlib.h>
#include <string.h>

/* Compare S1 (with size S1SIZE) and S2 (with length S2SIZE) according
   to the LC_COLLATE locale.  S1 and S2 are both blocks of memory with
   nonzero sizes, and the last byte in each block must be a null byte.
   Set errno to an error number if there is an error, and to zero
   otherwise.  */
static int
strcoll_loop (char const *s1, size_t s1size, char const *s2, size_t s2size)
{
  int diff;

  while (! (errno = 0, (diff = strcoll (s1, s2)) || errno))
    {
      /* strcoll found no difference, but perhaps it was fooled by NUL
         characters in the data.  Work around this problem by advancing
         past the NUL chars.  */
      size_t size1 = strlen (s1) + 1;
      size_t size2 = strlen (s2) + 1;
      s1 += size1;
      s2 += size2;
      s1size -= size1;
      s2size -= size2;

      if (s1size == 0)
        return - (s2size != 0);
      if (s2size == 0)
        return 1;
    }

  return diff;
}

/* Compare S1 (with length S1LEN) and S2 (with length S2LEN) according
   to the LC_COLLATE locale.  S1 and S2 do not overlap, and are not
   adjacent.  Perhaps temporarily modify the bytes after S1 and S2,
   but restore their original contents before returning.  Set errno to an
   error number if there is an error, and to zero otherwise.  */
int
memcoll (char *s1, size_t s1len, char *s2, size_t s2len)
{
  int diff;

  /* strcoll is slow on many platforms, so check for the common case
     where the arguments are bytewise equal.  Otherwise, walk through
     the buffers using strcoll on each substring.  */

  if (s1len == s2len && memcmp (s1, s2, s1len) == 0)
    {
      errno = 0;
      diff = 0;
    }
  else
    {
      char n1 = s1[s1len];
      char n2 = s2[s2len];

      s1[s1len] = '\0';
      s2[s2len] = '\0';

      diff = strcoll_loop (s1, s1len + 1, s2, s2len + 1);

      s1[s1len] = n1;
      s2[s2len] = n2;
    }

  return diff;
}

/* Compare S1 (a memory block of size S1SIZE, with a NUL as last byte)
   and S2 (a memory block of size S2SIZE, with a NUL as last byte)
   according to the LC_COLLATE locale.  S1SIZE and S2SIZE must be > 0.
   Set errno to an error number if there is an error, and to zero
   otherwise.  */
int
memcoll0 (char const *s1, size_t s1size, char const *s2, size_t s2size)
{
  if (s1size == s2size && memcmp (s1, s2, s1size) == 0)
    {
      errno = 0;
      return 0;
    }
  else
    return strcoll_loop (s1, s1size, s2, s2size);
}
