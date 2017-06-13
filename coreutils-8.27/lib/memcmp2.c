/* Compare two memory areas with possibly different lengths.
   Copyright (C) 2009-2017 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published
   by the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

#include "config.h"

/* Specification.  */
#include "memcmp2.h"

#include <string.h>

int
memcmp2 (const char *s1, size_t n1, const char *s2, size_t n2)
{
  int cmp = memcmp (s1, s2, n1 <= n2 ? n1 : n2);
  if (cmp == 0)
    {
      if (n1 < n2)
        cmp = -1;
      else if (n1 > n2)
        cmp = 1;
    }
  return cmp;
}
