/* xnanosleep.c -- a more convenient interface to nanosleep

   Copyright (C) 2002-2007, 2009-2017 Free Software Foundation, Inc.

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

/* Mostly written (for sleep.c) by Paul Eggert.
   Factored out (creating this file) by Jim Meyering.  */

#include "config.h"

#include "xnanosleep.h"

#include <timespec.h>

#include <errno.h>
#include "time.h"

/* Sleep until the time (call it WAKE_UP_TIME) specified as
   SECONDS seconds after the time this function is called.
   SECONDS must be non-negative.  If SECONDS is so large that
   it is not representable as a 'struct timespec', then use
   the maximum value for that interval.  Return -1 on failure
   (setting errno), 0 on success.  */

int
xnanosleep (double seconds)
{
  struct timespec ts_sleep = dtotimespec (seconds);

  for (;;)
    {
      /* Linux-2.6.8.1's nanosleep returns -1, but doesn't set errno
         when resumed after being suspended.  Earlier versions would
         set errno to EINTR.  nanosleep from linux-2.6.10, as well as
         implementations by (all?) other vendors, doesn't return -1
         in that case;  either it continues sleeping (if time remains)
         or it returns zero (if the wake-up time has passed).  */
      errno = 0;
      if (nanosleep (&ts_sleep, NULL) == 0)
        break;
      if (errno != EINTR && errno != 0)
        return -1;
    }

  return 0;
}
