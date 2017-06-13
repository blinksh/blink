/* buffer-lcm.c - compute a good buffer size for dealing with two files

   Copyright (C) 2002-2017 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* Written by Paul Eggert.  */

#include "config.h"
#include "buffer-lcm.h"

/* Return a buffer size suitable for doing I/O with files whose block
   sizes are A and B.  However, never return a value greater than
   LCM_MAX.  */

size_t
buffer_lcm (size_t a, size_t b, size_t lcm_max)
{
  size_t size;

  /* Use reasonable values if buffer sizes are zero.  */
  if (!a)
    size = b ? b : 8 * 1024;
  else
    {
      if (b)
        {
          /* Return lcm (A, B) if it is in range; otherwise, fall back
             on A.  */

          size_t lcm, m, n, q, r;

          /* N = gcd (A, B).  */
          for (m = a, n = b;  (r = m % n) != 0;  m = n, n = r)
            continue;

          /* LCM = lcm (A, B), if in range.  */
          q = a / n;
          lcm = q * b;
          if (lcm <= lcm_max && lcm / b == q)
            return lcm;
        }

      size = a;
    }

  return size <= lcm_max ? size : lcm_max;
}
