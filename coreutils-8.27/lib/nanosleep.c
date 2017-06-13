/* Provide a replacement for the POSIX nanosleep function.

   Copyright (C) 1999-2000, 2002, 2004-2017 Free Software Foundation, Inc.

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

/* written by Jim Meyering
   and Bruno Haible for the native Windows part */

#include "config.h"

#include "time.h"

#include "intprops.h"
#include "sig-handler.h"
#include "verify.h"

#include <stdbool.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/select.h>
#include <signal.h>

#include <sys/time.h>
#include <errno.h>

#include <unistd.h>


enum { BILLION = 1000 * 1000 * 1000 };

#if HAVE_BUG_BIG_NANOSLEEP

int
nanosleep (const struct timespec *requested_delay,
           struct timespec *remaining_delay)
# undef nanosleep
{
  /* nanosleep mishandles large sleeps due to internal overflow problems.
     The worst known case of this is Linux 2.6.9 with glibc 2.3.4, which
     can't sleep more than 24.85 days (2^31 milliseconds).  Similarly,
     cygwin 1.5.x, which can't sleep more than 49.7 days (2^32 milliseconds).
     Solve this by breaking the sleep up into smaller chunks.  */

  if (requested_delay->tv_nsec < 0 || BILLION <= requested_delay->tv_nsec)
    {
      errno = EINVAL;
      return -1;
    }

  {
    /* Verify that time_t is large enough.  */
    verify (TYPE_MAXIMUM (time_t) / 24 / 24 / 60 / 60);
    const time_t limit = 24 * 24 * 60 * 60;
    time_t seconds = requested_delay->tv_sec;
    struct timespec intermediate;
    intermediate.tv_nsec = requested_delay->tv_nsec;

    while (limit < seconds)
      {
        int result;
        intermediate.tv_sec = limit;
        result = nanosleep (&intermediate, remaining_delay);
        seconds -= limit;
        if (result)
          {
            if (remaining_delay)
              remaining_delay->tv_sec += seconds;
            return result;
          }
        intermediate.tv_nsec = 0;
      }
    intermediate.tv_sec = seconds;
    return nanosleep (&intermediate, remaining_delay);
  }
}

#elif (defined _WIN32 || defined __WIN32__) && ! defined __CYGWIN__
/* Native Windows platforms.  */

# define WIN32_LEAN_AND_MEAN
# include <windows.h>

/* The Windows API function Sleep() has a resolution of about 15 ms and takes
   at least 5 ms to execute.  We use this function for longer time periods.
   Additionally, we use busy-looping over short time periods, to get a
   resolution of about 0.01 ms.  In order to measure such short timespans,
   we use the QueryPerformanceCounter() function.  */

int
nanosleep (const struct timespec *requested_delay,
           struct timespec *remaining_delay)
{
  static bool initialized;
  /* Number of performance counter increments per nanosecond,
     or zero if it could not be determined.  */
  static double ticks_per_nanosecond;

  if (requested_delay->tv_nsec < 0 || BILLION <= requested_delay->tv_nsec)
    {
      errno = EINVAL;
      return -1;
    }

  /* For requested delays of one second or more, 15ms resolution is
     sufficient.  */
  if (requested_delay->tv_sec == 0)
    {
      if (!initialized)
        {
          /* Initialize ticks_per_nanosecond.  */
          LARGE_INTEGER ticks_per_second;

          if (QueryPerformanceFrequency (&ticks_per_second))
            ticks_per_nanosecond =
              (double) ticks_per_second.QuadPart / 1000000000.0;

          initialized = true;
        }
      if (ticks_per_nanosecond)
        {
          /* QueryPerformanceFrequency worked.  We can use
             QueryPerformanceCounter.  Use a combination of Sleep and
             busy-looping.  */
          /* Number of milliseconds to pass to the Sleep function.
             Since Sleep can take up to 8 ms less or 8 ms more than requested
             (or maybe more if the system is loaded), we subtract 10 ms.  */
          int sleep_millis = (int) requested_delay->tv_nsec / 1000000 - 10;
          /* Determine how many ticks to delay.  */
          LONGLONG wait_ticks = requested_delay->tv_nsec * ticks_per_nanosecond;
          /* Start.  */
          LARGE_INTEGER counter_before;
          if (QueryPerformanceCounter (&counter_before))
            {
              /* Wait until the performance counter has reached this value.
                 We don't need to worry about overflow, because the performance
                 counter is reset at reboot, and with a frequency of 3.6E6
                 ticks per second 63 bits suffice for over 80000 years.  */
              LONGLONG wait_until = counter_before.QuadPart + wait_ticks;
              /* Use Sleep for the longest part.  */
              if (sleep_millis > 0)
                Sleep (sleep_millis);
              /* Busy-loop for the rest.  */
              for (;;)
                {
                  LARGE_INTEGER counter_after;
                  if (!QueryPerformanceCounter (&counter_after))
                    /* QueryPerformanceCounter failed, but succeeded earlier.
                       Should not happen.  */
                    break;
                  if (counter_after.QuadPart >= wait_until)
                    /* The requested time has elapsed.  */
                    break;
                }
              goto done;
            }
        }
    }
  /* Implementation for long delays and as fallback.  */
  Sleep (requested_delay->tv_sec * 1000 + requested_delay->tv_nsec / 1000000);

 done:
  /* Sleep is not interruptible.  So there is no remaining delay.  */
  if (remaining_delay != NULL)
    {
      remaining_delay->tv_sec = 0;
      remaining_delay->tv_nsec = 0;
    }
  return 0;
}

#else
/* Unix platforms lacking nanosleep. */

/* Some systems (MSDOS) don't have SIGCONT.
   Using SIGTERM here turns the signal-handling code below
   into a no-op on such systems. */
# ifndef SIGCONT
#  define SIGCONT SIGTERM
# endif

static sig_atomic_t volatile suspended;

/* Handle SIGCONT. */

static void
sighandler (int sig)
{
  suspended = 1;
}

/* Suspend execution for at least *TS_DELAY seconds.  */

static int
my_usleep (const struct timespec *ts_delay)
{
  struct timeval tv_delay;
  tv_delay.tv_sec = ts_delay->tv_sec;
  tv_delay.tv_usec = (ts_delay->tv_nsec + 999) / 1000;
  if (tv_delay.tv_usec == 1000000)
    {
      if (tv_delay.tv_sec == TYPE_MAXIMUM (time_t))
        tv_delay.tv_usec = 1000000 - 1; /* close enough */
      else
        {
          tv_delay.tv_sec++;
          tv_delay.tv_usec = 0;
        }
    }
  return select (0, NULL, NULL, NULL, &tv_delay);
}

/* Suspend execution for at least *REQUESTED_DELAY seconds.  The
   *REMAINING_DELAY part isn't implemented yet.  */

int
nanosleep (const struct timespec *requested_delay,
           struct timespec *remaining_delay)
{
  static bool initialized;

  if (requested_delay->tv_nsec < 0 || BILLION <= requested_delay->tv_nsec)
    {
      errno = EINVAL;
      return -1;
    }

  /* set up sig handler */
  if (! initialized)
    {
      struct sigaction oldact;

      sigaction (SIGCONT, NULL, &oldact);
      if (get_handler (&oldact) != SIG_IGN)
        {
          struct sigaction newact;

          newact.sa_handler = sighandler;
          sigemptyset (&newact.sa_mask);
          newact.sa_flags = 0;
          sigaction (SIGCONT, &newact, NULL);
        }
      initialized = true;
    }

  suspended = 0;

  if (my_usleep (requested_delay) == -1)
    {
      if (suspended)
        {
          /* Calculate time remaining.  */
          /* FIXME: the code in sleep doesn't use this, so there's no
             rush to implement it.  */

          errno = EINTR;
        }
      return -1;
    }

  /* FIXME: Restore sig handler?  */

  return 0;
}
#endif
