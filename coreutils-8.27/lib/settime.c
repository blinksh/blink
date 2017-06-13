/* settime -- set the system clock

   Copyright (C) 2002, 2004-2007, 2009-2017 Free Software Foundation, Inc.

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

#include "config.h"

#include "timespec.h"

#include <sys/time.h>
#include <unistd.h>

#include <errno.h>

/* Set the system time.  */

int
settime (struct timespec const *ts)
{
#if defined CLOCK_REALTIME && HAVE_CLOCK_SETTIME
  {
      // Not available on iOS:
      // int r = clock_settime (CLOCK_REALTIME, ts);
      int r = 0;
      if (r == 0 || errno == EPERM)
      return r;
  }
#endif

#if HAVE_SETTIMEOFDAY
  {
    struct timeval tv;

    tv.tv_sec = ts->tv_sec;
    tv.tv_usec = ts->tv_nsec / 1000;
    return settimeofday (&tv, 0);
  }
#elif HAVE_STIME
  /* This fails to compile on OSF1 V5.1, due to stime requiring
     a 'long int*' and tv_sec is 'int'.  But that system does provide
     settimeofday.  */
  return stime (&ts->tv_sec);
#else
  errno = ENOSYS;
  return -1;
#endif
}
