/* Subtract two struct timespec values.

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

/* Written by Paul Eggert.  */

/* Return the difference between two timespec values A and B.  On
   overflow, return an extremal value.  This assumes 0 <= tv_nsec <
   TIMESPEC_RESOLUTION.  */

#include <config.h>
#include "timespec.h"

#include "intprops.h"

struct timespec
timespec_sub (struct timespec a, struct timespec b)
{
  time_t rs = a.tv_sec;
  time_t bs = b.tv_sec;
  int ns = a.tv_nsec - b.tv_nsec;
  int rns = ns;
  time_t tmin = TYPE_MINIMUM (time_t);
  time_t tmax = TYPE_MAXIMUM (time_t);

  if (ns < 0)
    {
      rns = ns + TIMESPEC_RESOLUTION;
      if (bs < tmax)
        bs++;
      else if (- TYPE_SIGNED (time_t) < rs)
        rs--;
      else
        goto low_overflow;
    }

  /* INT_SUBTRACT_WRAPV is not appropriate since time_t might be unsigned.
     In theory time_t might be narrower than int, so plain
     INT_SUBTRACT_OVERFLOW does not suffice.  */
  if (! INT_SUBTRACT_OVERFLOW (rs, bs) && tmin <= rs - bs && rs - bs <= tmax)
    rs -= bs;
  else
    {
      if (rs < 0)
        {
        low_overflow:
          rs = tmin;
          rns = 0;
        }
      else
        {
          rs = tmax;
          rns = TIMESPEC_RESOLUTION - 1;
        }
    }

  return make_timespec (rs, rns);
}
