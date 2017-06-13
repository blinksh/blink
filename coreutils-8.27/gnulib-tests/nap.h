/* Assist in file system timestamp tests.
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

/* Written by Eric Blake <ebb9@byu.net>, 2009.  */

#ifndef GLTEST_NAP_H
# define GLTEST_NAP_H

# include <limits.h>
# include <stdbool.h>

/* File descriptor used for the witness file.  */
static int nap_fd = -1;

/* Return A - B, in ns.
   Return 0 if the true result would be negative.
   Return INT_MAX if the true result would be greater than INT_MAX.  */
static int
diff_timespec (struct timespec a, struct timespec b)
{
  time_t as = a.tv_sec;
  time_t bs = b.tv_sec;
  int ans = a.tv_nsec;
  int bns = b.tv_nsec;

  if (! (bs < as || (bs == as && bns < ans)))
    return 0;
  if (as - bs <= INT_MAX / 1000000000)
    {
      int sdiff = (as - bs) * 1000000000;
      int usdiff = ans - bns;
      if (usdiff < INT_MAX - sdiff)
        return sdiff + usdiff;
    }
  return INT_MAX;
}

static void
get_stat (int fd, struct stat *st, int do_write)
{
  if (do_write)
    ASSERT (write (fd, "\n", 1) == 1);
  ASSERT (fstat (fd, st) == 0);
}

/* Given a file whose descriptor is FD, see whether delaying by DELAY
   nanoseconds causes a change in a file's ctime and mtime.
   OLD_ST is the file's status, recently gotten.  */
static bool
nap_works (int fd, int delay, struct stat old_st)
{
  struct stat st;
  struct timespec delay_spec;
  delay_spec.tv_sec = delay / 1000000000;
  delay_spec.tv_nsec = delay % 1000000000;
  ASSERT (nanosleep (&delay_spec, 0) == 0);
  get_stat (fd, &st, 1);

  if (   diff_timespec (get_stat_ctime (&st), get_stat_ctime (&old_st))
      && diff_timespec (get_stat_mtime (&st), get_stat_mtime (&old_st)))
    return true;

  return false;
}

#define TEMPFILE BASE "nap.tmp"

static void
clear_temp_file (void)
{
  if (0 <= nap_fd)
    {
      ASSERT (close (nap_fd) != -1);
      ASSERT (unlink (TEMPFILE) != -1);
    }
}

/* Sleep long enough to notice a timestamp difference on the file
   system in the current directory.  Use an adaptive approach, trying
   to find the smallest delay which works on the current file system
   to make the timestamp difference appear.  Assert a maximum delay of
   ~2 seconds, more precisely sum(2^n) from 0 to 30 = 2^31 - 1 = 2.1s.
   Assumes that BASE is defined, and requires that the test module
   depends on nanosleep.  */
static void
nap (void)
{
  struct stat old_st;
  static int delay = 1;

  if (-1 == nap_fd)
    {
      atexit (clear_temp_file);
      ASSERT ((nap_fd = creat (TEMPFILE, 0600)) != -1);
      get_stat (nap_fd, &old_st, 0);
    }
  else
    {
      ASSERT (0 <= nap_fd);
      get_stat (nap_fd, &old_st, 1);
    }

  if (1 < delay)
    delay = delay / 2;  /* Try half of the previous delay.  */
  ASSERT (0 < delay);

  for ( ; delay <= 2147483647; delay = delay * 2)
    if (nap_works (nap_fd, delay, old_st))
      return;

  /* Bummer: even the highest nap delay didn't work. */
  ASSERT (0);
}

#endif /* GLTEST_NAP_H */
