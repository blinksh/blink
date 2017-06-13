/* Convert a 'struct tm' to a time_t value.
   Copyright (C) 1993-2017 Free Software Foundation, Inc.
   This file is part of the GNU C Library.
   Contributed by Paul Eggert <eggert@twinsun.com>.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with the GNU C Library; if not, see
   <http://www.gnu.org/licenses/>.  */

/* Define this to 1 to have a standalone program to test this implementation of
   mktime.  */
#ifndef DEBUG_MKTIME
# define DEBUG_MKTIME 0
#endif

#if !defined _LIBC && !DEBUG_MKTIME
# include "config.h"
#endif

/* Assume that leap seconds are possible, unless told otherwise.
   If the host has a 'zic' command with a '-L leapsecondfilename' option,
   then it supports leap seconds; otherwise it probably doesn't.  */
#ifndef LEAP_SECONDS_POSSIBLE
# define LEAP_SECONDS_POSSIBLE 1
#endif

#include "time.h"

#include <limits.h>
#include <stdbool.h>

#include <intprops.h>
#include <verify.h>

#if DEBUG_MKTIME
# include <stdio.h>
# include <stdlib.h>
# include <string.h>
/* Make it work even if the system's libc has its own mktime routine.  */
# undef mktime
# define mktime my_mktime
#endif

/* A signed type that can represent an integer number of years
   multiplied by three times the number of seconds in a year.  It is
   needed when converting a tm_year value times the number of seconds
   in a year.  The factor of three comes because these products need
   to be subtracted from each other, and sometimes with an offset
   added to them, without worrying about overflow.

   Much of the code uses long_int to represent time_t values, to
   lessen the hassle of dealing with platforms where time_t is
   unsigned, and because long_int should suffice to represent all
   time_t values that mktime can generate even on platforms where
   time_t is excessively wide.  */

#if INT_MAX <= LONG_MAX / 3 / 366 / 24 / 60 / 60
typedef long int long_int;
#else
typedef long long int long_int;
#endif
verify (INT_MAX <= TYPE_MAXIMUM (long_int) / 3 / 366 / 24 / 60 / 60);

/* Shift A right by B bits portably, by dividing A by 2**B and
   truncating towards minus infinity.  B should be in the range 0 <= B
   <= LONG_INT_BITS - 2, where LONG_INT_BITS is the number of useful
   bits in a long_int.  LONG_INT_BITS is at least 32.

   ISO C99 says that A >> B is implementation-defined if A < 0.  Some
   implementations (e.g., UNICOS 9.0 on a Cray Y-MP EL) don't shift
   right in the usual way when A < 0, so SHR falls back on division if
   ordinary A >> B doesn't seem to be the usual signed shift.  */

static long_int
shr (long_int a, int b)
{
  long_int one = 1;
  return (-one >> 1 == -1
	  ? a >> b
	  : a / (one << b) - (a % (one << b) < 0));
}

/* Bounds for the intersection of time_t and long_int.  */

static long_int const mktime_min
  = ((TYPE_SIGNED (time_t) && TYPE_MINIMUM (time_t) < TYPE_MINIMUM (long_int))
     ? TYPE_MINIMUM (long_int) : TYPE_MINIMUM (time_t));
static long_int const mktime_max
  = (TYPE_MAXIMUM (long_int) < TYPE_MAXIMUM (time_t)
     ? TYPE_MAXIMUM (long_int) : TYPE_MAXIMUM (time_t));

verify (TYPE_IS_INTEGER (time_t));

#define EPOCH_YEAR 1970
#define TM_YEAR_BASE 1900
verify (TM_YEAR_BASE % 100 == 0);

/* Is YEAR + TM_YEAR_BASE a leap year?  */
static bool
leapyear (long_int year)
{
  /* Don't add YEAR to TM_YEAR_BASE, as that might overflow.
     Also, work even if YEAR is negative.  */
  return
    ((year & 3) == 0
     && (year % 100 != 0
	 || ((year / 100) & 3) == (- (TM_YEAR_BASE / 100) & 3)));
}

/* How many days come before each month (0-12).  */
#ifndef _LIBC
static
#endif
const unsigned short int __mon_yday[2][13] =
  {
    /* Normal years.  */
    { 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365 },
    /* Leap years.  */
    { 0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335, 366 }
  };


#ifdef _LIBC
typedef time_t mktime_offset_t;
#else
/* Portable standalone applications should supply a <time.h> that
   declares a POSIX-compliant localtime_r, for the benefit of older
   implementations that lack localtime_r or have a nonstandard one.
   See the gnulib time_r module for one way to implement this.  */
# undef __localtime_r
# define __localtime_r localtime_r
# define __mktime_internal mktime_internal
# include "mktime-internal.h"
#endif

/* Do the values A and B differ according to the rules for tm_isdst?
   A and B differ if one is zero and the other positive.  */
static bool
isdst_differ (int a, int b)
{
  return (!a != !b) && (0 <= a) && (0 <= b);
}

/* Return an integer value measuring (YEAR1-YDAY1 HOUR1:MIN1:SEC1) -
   (YEAR0-YDAY0 HOUR0:MIN0:SEC0) in seconds, assuming that the clocks
   were not adjusted between the timestamps.

   The YEAR values uses the same numbering as TP->tm_year.  Values
   need not be in the usual range.  However, YEAR1 must not overflow
   when multiplied by three times the number of seconds in a year, and
   likewise for YDAY1 and three times the number of seconds in a day.  */

static long_int
ydhms_diff (long_int year1, long_int yday1, int hour1, int min1, int sec1,
	    int year0, int yday0, int hour0, int min0, int sec0)
{
  verify (-1 / 2 == 0);

  /* Compute intervening leap days correctly even if year is negative.
     Take care to avoid integer overflow here.  */
  int a4 = shr (year1, 2) + shr (TM_YEAR_BASE, 2) - ! (year1 & 3);
  int b4 = shr (year0, 2) + shr (TM_YEAR_BASE, 2) - ! (year0 & 3);
  int a100 = a4 / 25 - (a4 % 25 < 0);
  int b100 = b4 / 25 - (b4 % 25 < 0);
  int a400 = shr (a100, 2);
  int b400 = shr (b100, 2);
  int intervening_leap_days = (a4 - b4) - (a100 - b100) + (a400 - b400);

  /* Compute the desired time without overflowing.  */
  long_int years = year1 - year0;
  long_int days = 365 * years + yday1 - yday0 + intervening_leap_days;
  long_int hours = 24 * days + hour1 - hour0;
  long_int minutes = 60 * hours + min1 - min0;
  long_int seconds = 60 * minutes + sec1 - sec0;
  return seconds;
}

/* Return the average of A and B, even if A + B would overflow.
   Round toward positive infinity.  */
static long_int
long_int_avg (long_int a, long_int b)
{
  return shr (a, 1) + shr (b, 1) + ((a | b) & 1);
}

/* Return a time_t value corresponding to (YEAR-YDAY HOUR:MIN:SEC),
   assuming that T corresponds to *TP and that no clock adjustments
   occurred between *TP and the desired time.
   Although T and the returned value are of type long_int,
   they represent time_t values and must be in time_t range.
   If TP is null, return a value not equal to T; this avoids false matches.
   YEAR and YDAY must not be so large that multiplying them by three times the
   number of seconds in a year (or day, respectively) would overflow long_int.
   If the returned value would be out of range, yield the minimal or
   maximal in-range value, except do not yield a value equal to T.  */
static long_int
guess_time_tm (long_int year, long_int yday, int hour, int min, int sec,
	       long_int t, const struct tm *tp)
{
  if (tp)
    {
      long_int result;
      long_int d = ydhms_diff (year, yday, hour, min, sec,
			       tp->tm_year, tp->tm_yday,
			       tp->tm_hour, tp->tm_min, tp->tm_sec);
      if (! INT_ADD_WRAPV (t, d, &result))
	return result;
    }

  /* Overflow occurred one way or another.  Return the nearest result
     that is actually in range, except don't report a zero difference
     if the actual difference is nonzero, as that would cause a false
     match; and don't oscillate between two values, as that would
     confuse the spring-forward gap detector.  */
  return (t < long_int_avg (mktime_min, mktime_max)
	  ? (t <= mktime_min + 1 ? t + 1 : mktime_min)
	  : (mktime_max - 1 <= t ? t - 1 : mktime_max));
}

/* Use CONVERT to convert T to a struct tm value in *TM.  T must be in
   range for time_t.  Return TM if successful, NULL if T is out of
   range for CONVERT.  */
static struct tm *
convert_time (struct tm *(*convert) (const time_t *, struct tm *),
	      long_int t, struct tm *tm)
{
  time_t x = t;
  return convert (&x, tm);
}

/* Use CONVERT to convert *T to a broken down time in *TP.
   If *T is out of range for conversion, adjust it so that
   it is the nearest in-range value and then convert that.
   A value is in range if it fits in both time_t and long_int.  */
static struct tm *
ranged_convert (struct tm *(*convert) (const time_t *, struct tm *),
		long_int *t, struct tm *tp)
{
  struct tm *r;
  if (*t < mktime_min)
    *t = mktime_min;
  else if (mktime_max < *t)
    *t = mktime_max;
  r = convert_time (convert, *t, tp);

  if (!r && *t)
    {
      long_int bad = *t;
      long_int ok = 0;

      /* BAD is a known unconvertible value, and OK is a known good one.
	 Use binary search to narrow the range between BAD and OK until
	 they differ by 1.  */
      while (true)
	{
	  long_int mid = long_int_avg (ok, bad);
	  if (mid != ok && mid != bad)
	    break;
	  r = convert_time (convert, mid, tp);
	  if (r)
	    ok = mid;
	  else
	    bad = mid;
	}

      if (!r && ok)
	{
	  /* The last conversion attempt failed;
	     revert to the most recent successful attempt.  */
	  r = convert_time (convert, ok, tp);
	}
    }

  return r;
}

/* Convert *TP to a time_t value, inverting
   the monotonic and mostly-unit-linear conversion function CONVERT.
   Use *OFFSET to keep track of a guess at the offset of the result,
   compared to what the result would be for UTC without leap seconds.
   If *OFFSET's guess is correct, only one CONVERT call is needed.
   This function is external because it is used also by timegm.c.  */
time_t
__mktime_internal (struct tm *tp,
		   struct tm *(*convert) (const time_t *, struct tm *),
		   mktime_offset_t *offset)
{
  long_int t, gt, t0, t1, t2, dt;
  struct tm tm;

  /* The maximum number of probes (calls to CONVERT) should be enough
     to handle any combinations of time zone rule changes, solar time,
     leap seconds, and oscillations around a spring-forward gap.
     POSIX.1 prohibits leap seconds, but some hosts have them anyway.  */
  int remaining_probes = 6;

  /* Time requested.  Copy it in case CONVERT modifies *TP; this can
     occur if TP is localtime's returned value and CONVERT is localtime.  */
  int sec = tp->tm_sec;
  int min = tp->tm_min;
  int hour = tp->tm_hour;
  int mday = tp->tm_mday;
  int mon = tp->tm_mon;
  int year_requested = tp->tm_year;
  int isdst = tp->tm_isdst;

  /* 1 if the previous probe was DST.  */
  int dst2;

  /* Ensure that mon is in range, and set year accordingly.  */
  int mon_remainder = mon % 12;
  int negative_mon_remainder = mon_remainder < 0;
  int mon_years = mon / 12 - negative_mon_remainder;
  long_int lyear_requested = year_requested;
  long_int year = lyear_requested + mon_years;

  /* The other values need not be in range:
     the remaining code handles overflows correctly.  */

  /* Calculate day of year from year, month, and day of month.
     The result need not be in range.  */
  int mon_yday = ((__mon_yday[leapyear (year)]
		   [mon_remainder + 12 * negative_mon_remainder])
		  - 1);
  long_int lmday = mday;
  long_int yday = mon_yday + lmday;

  int negative_offset_guess;

  int sec_requested = sec;

  if (LEAP_SECONDS_POSSIBLE)
    {
      /* Handle out-of-range seconds specially,
	 since ydhms_tm_diff assumes every minute has 60 seconds.  */
      if (sec < 0)
	sec = 0;
      if (59 < sec)
	sec = 59;
    }

  /* Invert CONVERT by probing.  First assume the same offset as last
     time.  */

  INT_SUBTRACT_WRAPV (0, *offset, &negative_offset_guess);
  t0 = ydhms_diff (year, yday, hour, min, sec,
		   EPOCH_YEAR - TM_YEAR_BASE, 0, 0, 0, negative_offset_guess);

  /* Repeatedly use the error to improve the guess.  */

  for (t = t1 = t2 = t0, dst2 = 0;
       (gt = guess_time_tm (year, yday, hour, min, sec, t,
			    ranged_convert (convert, &t, &tm)),
	t != gt);
       t1 = t2, t2 = t, t = gt, dst2 = tm.tm_isdst != 0)
    if (t == t1 && t != t2
	&& (tm.tm_isdst < 0
	    || (isdst < 0
		? dst2 <= (tm.tm_isdst != 0)
		: (isdst != 0) != (tm.tm_isdst != 0))))
      /* We can't possibly find a match, as we are oscillating
	 between two values.  The requested time probably falls
	 within a spring-forward gap of size GT - T.  Follow the common
	 practice in this case, which is to return a time that is GT - T
	 away from the requested time, preferring a time whose
	 tm_isdst differs from the requested value.  (If no tm_isdst
	 was requested and only one of the two values has a nonzero
	 tm_isdst, prefer that value.)  In practice, this is more
	 useful than returning -1.  */
      goto offset_found;
    else if (--remaining_probes == 0)
      return -1;

  /* We have a match.  Check whether tm.tm_isdst has the requested
     value, if any.  */
  if (isdst_differ (isdst, tm.tm_isdst))
    {
      /* tm.tm_isdst has the wrong value.  Look for a neighboring
	 time with the right value, and use its UTC offset.

	 Heuristic: probe the adjacent timestamps in both directions,
	 looking for the desired isdst.  This should work for all real
	 time zone histories in the tz database.  */

      /* Distance between probes when looking for a DST boundary.  In
	 tzdata2003a, the shortest period of DST is 601200 seconds
	 (e.g., America/Recife starting 2000-10-08 01:00), and the
	 shortest period of non-DST surrounded by DST is 694800
	 seconds (Africa/Tunis starting 1943-04-17 01:00).  Use the
	 minimum of these two values, so we don't miss these short
	 periods when probing.  */
      int stride = 601200;

      /* The longest period of DST in tzdata2003a is 536454000 seconds
	 (e.g., America/Jujuy starting 1946-10-01 01:00).  The longest
	 period of non-DST is much longer, but it makes no real sense
	 to search for more than a year of non-DST, so use the DST
	 max.  */
      int duration_max = 536454000;

      /* Search in both directions, so the maximum distance is half
	 the duration; add the stride to avoid off-by-1 problems.  */
      int delta_bound = duration_max / 2 + stride;

      int delta, direction;

      for (delta = stride; delta < delta_bound; delta += stride)
	for (direction = -1; direction <= 1; direction += 2)
	  {
	    long_int ot;
	    if (! INT_ADD_WRAPV (t, delta * direction, &ot))
	      {
		struct tm otm;
		ranged_convert (convert, &ot, &otm);
		if (! isdst_differ (isdst, otm.tm_isdst))
		  {
		    /* We found the desired tm_isdst.
		       Extrapolate back to the desired time.  */
		    t = guess_time_tm (year, yday, hour, min, sec, ot, &otm);
		    ranged_convert (convert, &t, &tm);
		    goto offset_found;
		  }
	      }
	  }
    }

 offset_found:
  /* Set *OFFSET to the low-order bits of T - T0 - NEGATIVE_OFFSET_GUESS.
     This is just a heuristic to speed up the next mktime call, and
     correctness is unaffected if integer overflow occurs here.  */
  INT_SUBTRACT_WRAPV (t, t0, &dt);
  INT_SUBTRACT_WRAPV (dt, negative_offset_guess, offset);

  if (LEAP_SECONDS_POSSIBLE && sec_requested != tm.tm_sec)
    {
      /* Adjust time to reflect the tm_sec requested, not the normalized value.
	 Also, repair any damage from a false match due to a leap second.  */
      long_int sec_adjustment = sec == 0 && tm.tm_sec == 60;
      sec_adjustment -= sec;
      sec_adjustment += sec_requested;
      if (INT_ADD_WRAPV (t, sec_adjustment, &t)
	  || ! (mktime_min <= t && t <= mktime_max)
	  || ! convert_time (convert, t, &tm))
	return -1;
    }

  *tp = tm;
  return t;
}


static mktime_offset_t localtime_offset;

/* Convert *TP to a time_t value.  */
time_t
mktime (struct tm *tp)
{
#ifdef _LIBC
  /* POSIX.1 8.1.1 requires that whenever mktime() is called, the
     time zone names contained in the external variable 'tzname' shall
     be set as if the tzset() function had been called.  */
  __tzset ();
#elif HAVE_TZSET
  tzset ();
#endif

  return __mktime_internal (tp, __localtime_r, &localtime_offset);
}

#ifdef weak_alias
weak_alias (mktime, timelocal)
#endif

#ifdef _LIBC
libc_hidden_def (mktime)
libc_hidden_weak (timelocal)
#endif

#if DEBUG_MKTIME

static int
not_equal_tm (const struct tm *a, const struct tm *b)
{
  return ((a->tm_sec ^ b->tm_sec)
	  | (a->tm_min ^ b->tm_min)
	  | (a->tm_hour ^ b->tm_hour)
	  | (a->tm_mday ^ b->tm_mday)
	  | (a->tm_mon ^ b->tm_mon)
	  | (a->tm_year ^ b->tm_year)
	  | (a->tm_yday ^ b->tm_yday)
	  | isdst_differ (a->tm_isdst, b->tm_isdst));
}

static void
print_tm (const struct tm *tp)
{
  if (tp)
    printf ("%04d-%02d-%02d %02d:%02d:%02d yday %03d wday %d isdst %d",
	    tp->tm_year + TM_YEAR_BASE, tp->tm_mon + 1, tp->tm_mday,
	    tp->tm_hour, tp->tm_min, tp->tm_sec,
	    tp->tm_yday, tp->tm_wday, tp->tm_isdst);
  else
    printf ("0");
}

static int
check_result (time_t tk, struct tm tmk, time_t tl, const struct tm *lt)
{
  if (tk != tl || !lt || not_equal_tm (&tmk, lt))
    {
      printf ("mktime (");
      print_tm (lt);
      printf (")\nyields (");
      print_tm (&tmk);
      printf (") == %ld, should be %ld\n", (long int) tk, (long int) tl);
      return 1;
    }

  return 0;
}

int
main (int argc, char **argv)
{
  int status = 0;
  struct tm tm, tmk, tml;
  struct tm *lt;
  time_t tk, tl, tl1;
  char trailer;

  /* Sanity check, plus call tzset.  */
  tl = 0;
  if (! localtime (&tl))
    {
      printf ("localtime (0) fails\n");
      status = 1;
    }

  if ((argc == 3 || argc == 4)
      && (sscanf (argv[1], "%d-%d-%d%c",
		  &tm.tm_year, &tm.tm_mon, &tm.tm_mday, &trailer)
	  == 3)
      && (sscanf (argv[2], "%d:%d:%d%c",
		  &tm.tm_hour, &tm.tm_min, &tm.tm_sec, &trailer)
	  == 3))
    {
      tm.tm_year -= TM_YEAR_BASE;
      tm.tm_mon--;
      tm.tm_isdst = argc == 3 ? -1 : atoi (argv[3]);
      tmk = tm;
      tl = mktime (&tmk);
      lt = localtime_r (&tl, &tml);
      printf ("mktime returns %ld == ", (long int) tl);
      print_tm (&tmk);
      printf ("\n");
      status = check_result (tl, tmk, tl, lt);
    }
  else if (argc == 4 || (argc == 5 && strcmp (argv[4], "-") == 0))
    {
      time_t from = atol (argv[1]);
      time_t by = atol (argv[2]);
      time_t to = atol (argv[3]);

      if (argc == 4)
	for (tl = from; by < 0 ? to <= tl : tl <= to; tl = tl1)
	  {
	    lt = localtime_r (&tl, &tml);
	    if (lt)
	      {
		tmk = tml;
		tk = mktime (&tmk);
		status |= check_result (tk, tmk, tl, &tml);
	      }
	    else
	      {
		printf ("localtime_r (%ld) yields 0\n", (long int) tl);
		status = 1;
	      }
	    tl1 = tl + by;
	    if ((tl1 < tl) != (by < 0))
	      break;
	  }
      else
	for (tl = from; by < 0 ? to <= tl : tl <= to; tl = tl1)
	  {
	    /* Null benchmark.  */
	    lt = localtime_r (&tl, &tml);
	    if (lt)
	      {
		tmk = tml;
		tk = tl;
		status |= check_result (tk, tmk, tl, &tml);
	      }
	    else
	      {
		printf ("localtime_r (%ld) yields 0\n", (long int) tl);
		status = 1;
	      }
	    tl1 = tl + by;
	    if ((tl1 < tl) != (by < 0))
	      break;
	  }
    }
  else
    printf ("Usage:\
\t%s YYYY-MM-DD HH:MM:SS [ISDST] # Test given time.\n\
\t%s FROM BY TO # Test values FROM, FROM+BY, ..., TO.\n\
\t%s FROM BY TO - # Do not test those values (for benchmark).\n",
	    argv[0], argv[0], argv[0]);

  return status;
}

#endif /* DEBUG_MKTIME */

/*
Local Variables:
compile-command: "gcc -DDEBUG_MKTIME -I. -Wall -W -O2 -g mktime.c -o mktime"
End:
*/
