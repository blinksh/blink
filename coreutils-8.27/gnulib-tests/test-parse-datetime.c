/* Test of parse_datetime() function.
   Copyright (C) 2008-2017 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, see <http://www.gnu.org/licenses/>.  */

/* Written by Simon Josefsson <simon@josefsson.org>, 2008.  */

#include <config.h>

#include "parse-datetime.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "macros.h"

#ifdef DEBUG
#define LOG(str, now, res)                                              \
  printf ("string '%s' diff %d %d\n",                                 \
          str, res.tv_sec - now.tv_sec, res.tv_nsec - now.tv_nsec);
#else
#define LOG(str, now, res) (void) 0
#endif

static const char *const day_table[] =
{
  "SUNDAY",
  "MONDAY",
  "TUESDAY",
  "WEDNESDAY",
  "THURSDAY",
  "FRIDAY",
  "SATURDAY",
  NULL
};


#if ! HAVE_TM_GMTOFF
/* Shift A right by B bits portably, by dividing A by 2**B and
   truncating towards minus infinity.  A and B should be free of side
   effects, and B should be in the range 0 <= B <= INT_BITS - 2, where
   INT_BITS is the number of useful bits in an int.  GNU code can
   assume that INT_BITS is at least 32.

   ISO C99 says that A >> B is implementation-defined if A < 0.  Some
   implementations (e.g., UNICOS 9.0 on a Cray Y-MP EL) don't shift
   right in the usual way when A < 0, so SHR falls back on division if
   ordinary A >> B doesn't seem to be the usual signed shift.  */
#define SHR(a, b)       \
  (-1 >> 1 == -1        \
   ? (a) >> (b)         \
   : (a) / (1 << (b)) - ((a) % (1 << (b)) < 0))

#define TM_YEAR_BASE 1900

/* Yield the difference between *A and *B,
   measured in seconds, ignoring leap seconds.
   The body of this function is taken directly from the GNU C Library;
   see src/strftime.c.  */
static long int
tm_diff (struct tm const *a, struct tm const *b)
{
  /* Compute intervening leap days correctly even if year is negative.
     Take care to avoid int overflow in leap day calculations.  */
  int a4 = SHR (a->tm_year, 2) + SHR (TM_YEAR_BASE, 2) - ! (a->tm_year & 3);
  int b4 = SHR (b->tm_year, 2) + SHR (TM_YEAR_BASE, 2) - ! (b->tm_year & 3);
  int a100 = a4 / 25 - (a4 % 25 < 0);
  int b100 = b4 / 25 - (b4 % 25 < 0);
  int a400 = SHR (a100, 2);
  int b400 = SHR (b100, 2);
  int intervening_leap_days = (a4 - b4) - (a100 - b100) + (a400 - b400);
  long int ayear = a->tm_year;
  long int years = ayear - b->tm_year;
  long int days = (365 * years + intervening_leap_days
                   + (a->tm_yday - b->tm_yday));
  return (60 * (60 * (24 * days + (a->tm_hour - b->tm_hour))
                + (a->tm_min - b->tm_min))
          + (a->tm_sec - b->tm_sec));
}
#endif /* ! HAVE_TM_GMTOFF */

static long
gmt_offset (time_t s)
{
  long gmtoff;

#if !HAVE_TM_GMTOFF
  struct tm tm_local = *localtime (&s);
  struct tm tm_gmt   = *gmtime (&s);

  gmtoff = tm_diff (&tm_local, &tm_gmt);
#else
  gmtoff = localtime (&s)->tm_gmtoff;
#endif

  return gmtoff;
}

int
main (int argc _GL_UNUSED, char **argv)
{
  struct timespec result;
  struct timespec result2;
  struct timespec expected;
  struct timespec now;
  const char *p;
  int i;
  long gmtoff;
  time_t ref_time = 1304250918;

  /* Set the time zone to US Eastern time with the 2012 rules.  This
     should disable any leap second support.  Otherwise, there will be
     a problem with glibc on sites that default to leap seconds; see
     <http://bugs.gnu.org/12206>.  */
  setenv ("TZ", "EST5EDT,M3.2.0,M11.1.0", 1);

  gmtoff = gmt_offset (ref_time);


  /* ISO 8601 extended date and time of day representation,
     'T' separator, local time zone */
  p = "2011-05-01T11:55:18";
  expected.tv_sec = ref_time - gmtoff;
  expected.tv_nsec = 0;
  ASSERT (parse_datetime (&result, p, 0));
  LOG (p, expected, result);
  ASSERT (expected.tv_sec == result.tv_sec
          && expected.tv_nsec == result.tv_nsec);

  /* ISO 8601 extended date and time of day representation,
     ' ' separator, local time zone */
  p = "2011-05-01 11:55:18";
  expected.tv_sec = ref_time - gmtoff;
  expected.tv_nsec = 0;
  ASSERT (parse_datetime (&result, p, 0));
  LOG (p, expected, result);
  ASSERT (expected.tv_sec == result.tv_sec
          && expected.tv_nsec == result.tv_nsec);


  /* ISO 8601, extended date and time of day representation,
     'T' separator, UTC */
  p = "2011-05-01T11:55:18Z";
  expected.tv_sec = ref_time;
  expected.tv_nsec = 0;
  ASSERT (parse_datetime (&result, p, 0));
  LOG (p, expected, result);
  ASSERT (expected.tv_sec == result.tv_sec
          && expected.tv_nsec == result.tv_nsec);

  /* ISO 8601, extended date and time of day representation,
     ' ' separator, UTC */
  p = "2011-05-01 11:55:18Z";
  expected.tv_sec = ref_time;
  expected.tv_nsec = 0;
  ASSERT (parse_datetime (&result, p, 0));
  LOG (p, expected, result);
  ASSERT (expected.tv_sec == result.tv_sec
          && expected.tv_nsec == result.tv_nsec);


  /* ISO 8601 extended date and time of day representation,
     'T' separator, w/UTC offset */
  p = "2011-05-01T11:55:18-07:00";
  expected.tv_sec = 1304276118;
  expected.tv_nsec = 0;
  ASSERT (parse_datetime (&result, p, 0));
  LOG (p, expected, result);
  ASSERT (expected.tv_sec == result.tv_sec
          && expected.tv_nsec == result.tv_nsec);

  /* ISO 8601 extended date and time of day representation,
     ' ' separator, w/UTC offset */
  p = "2011-05-01 11:55:18-07:00";
  expected.tv_sec = 1304276118;
  expected.tv_nsec = 0;
  ASSERT (parse_datetime (&result, p, 0));
  LOG (p, expected, result);
  ASSERT (expected.tv_sec == result.tv_sec
          && expected.tv_nsec == result.tv_nsec);


  /* ISO 8601 extended date and time of day representation,
     'T' separator, w/hour only UTC offset */
  p = "2011-05-01T11:55:18-07";
  expected.tv_sec = 1304276118;
  expected.tv_nsec = 0;
  ASSERT (parse_datetime (&result, p, 0));
  LOG (p, expected, result);
  ASSERT (expected.tv_sec == result.tv_sec
          && expected.tv_nsec == result.tv_nsec);

  /* ISO 8601 extended date and time of day representation,
     ' ' separator, w/hour only UTC offset */
  p = "2011-05-01 11:55:18-07";
  expected.tv_sec = 1304276118;
  expected.tv_nsec = 0;
  ASSERT (parse_datetime (&result, p, 0));
  LOG (p, expected, result);
  ASSERT (expected.tv_sec == result.tv_sec
          && expected.tv_nsec == result.tv_nsec);


  now.tv_sec = 4711;
  now.tv_nsec = 1267;
  p = "now";
  ASSERT (parse_datetime (&result, p, &now));
  LOG (p, now, result);
  ASSERT (now.tv_sec == result.tv_sec && now.tv_nsec == result.tv_nsec);

  now.tv_sec = 4711;
  now.tv_nsec = 1267;
  p = "tomorrow";
  ASSERT (parse_datetime (&result, p, &now));
  LOG (p, now, result);
  ASSERT (now.tv_sec + 24 * 60 * 60 == result.tv_sec
          && now.tv_nsec == result.tv_nsec);

  now.tv_sec = 4711;
  now.tv_nsec = 1267;
  p = "yesterday";
  ASSERT (parse_datetime (&result, p, &now));
  LOG (p, now, result);
  ASSERT (now.tv_sec - 24 * 60 * 60 == result.tv_sec
          && now.tv_nsec == result.tv_nsec);

  now.tv_sec = 4711;
  now.tv_nsec = 1267;
  p = "4 hours";
  ASSERT (parse_datetime (&result, p, &now));
  LOG (p, now, result);
  ASSERT (now.tv_sec + 4 * 60 * 60 == result.tv_sec
          && now.tv_nsec == result.tv_nsec);

  /* test if timezone is not being ignored for day offset */
  now.tv_sec = 4711;
  now.tv_nsec = 1267;
  p = "UTC+400 +24 hours";
  ASSERT (parse_datetime (&result, p, &now));
  LOG (p, now, result);
  p = "UTC+400 +1 day";
  ASSERT (parse_datetime (&result2, p, &now));
  LOG (p, now, result2);
  ASSERT (result.tv_sec == result2.tv_sec
          && result.tv_nsec == result2.tv_nsec);

  /* test if several time zones formats are handled same way */
  now.tv_sec = 4711;
  now.tv_nsec = 1267;
  p = "UTC+14:00";
  ASSERT (parse_datetime (&result, p, &now));
  LOG (p, now, result);
  p = "UTC+14";
  ASSERT (parse_datetime (&result2, p, &now));
  LOG (p, now, result2);
  ASSERT (result.tv_sec == result2.tv_sec
          && result.tv_nsec == result2.tv_nsec);
  p = "UTC+1400";
  ASSERT (parse_datetime (&result2, p, &now));
  LOG (p, now, result2);
  ASSERT (result.tv_sec == result2.tv_sec
          && result.tv_nsec == result2.tv_nsec);

  now.tv_sec = 4711;
  now.tv_nsec = 1267;
  p = "UTC-14:00";
  ASSERT (parse_datetime (&result, p, &now));
  LOG (p, now, result);
  p = "UTC-14";
  ASSERT (parse_datetime (&result2, p, &now));
  LOG (p, now, result2);
  ASSERT (result.tv_sec == result2.tv_sec
          && result.tv_nsec == result2.tv_nsec);
  p = "UTC-1400";
  ASSERT (parse_datetime (&result2, p, &now));
  LOG (p, now, result2);
  ASSERT (result.tv_sec == result2.tv_sec
          && result.tv_nsec == result2.tv_nsec);

  now.tv_sec = 4711;
  now.tv_nsec = 1267;
  p = "UTC+0:15";
  ASSERT (parse_datetime (&result, p, &now));
  LOG (p, now, result);
  p = "UTC+0015";
  ASSERT (parse_datetime (&result2, p, &now));
  LOG (p, now, result2);
  ASSERT (result.tv_sec == result2.tv_sec
          && result.tv_nsec == result2.tv_nsec);

  now.tv_sec = 4711;
  now.tv_nsec = 1267;
  p = "UTC-1:30";
  ASSERT (parse_datetime (&result, p, &now));
  LOG (p, now, result);
  p = "UTC-130";
  ASSERT (parse_datetime (&result2, p, &now));
  LOG (p, now, result2);
  ASSERT (result.tv_sec == result2.tv_sec
          && result.tv_nsec == result2.tv_nsec);


  /* TZ out of range should cause parse_datetime failure */
  now.tv_sec = 4711;
  now.tv_nsec = 1267;
  p = "UTC+25:00";
  ASSERT (!parse_datetime (&result, p, &now));

        /* Check for several invalid countable dayshifts */
  now.tv_sec = 4711;
  now.tv_nsec = 1267;
  p = "UTC+4:00 +40 yesterday";
  ASSERT (!parse_datetime (&result, p, &now));
  p = "UTC+4:00 next yesterday";
  ASSERT (!parse_datetime (&result, p, &now));
  p = "UTC+4:00 tomorrow ago";
  ASSERT (!parse_datetime (&result, p, &now));
  p = "UTC+4:00 tomorrow hence";
  ASSERT (!parse_datetime (&result, p, &now));
  p = "UTC+4:00 40 now ago";
  ASSERT (!parse_datetime (&result, p, &now));
  p = "UTC+4:00 last tomorrow";
  ASSERT (!parse_datetime (&result, p, &now));
  p = "UTC+4:00 -4 today";
  ASSERT (!parse_datetime (&result, p, &now));

  /* And check correct usage of dayshifts */
  now.tv_sec = 4711;
  now.tv_nsec = 1267;
  p = "UTC+400 tomorrow";
  ASSERT (parse_datetime (&result, p, &now));
  LOG (p, now, result);
  p = "UTC+400 +1 day";
  ASSERT (parse_datetime (&result2, p, &now));
  LOG (p, now, result2);
  ASSERT (result.tv_sec == result2.tv_sec
          && result.tv_nsec == result2.tv_nsec);
  p = "UTC+400 1 day hence";
  ASSERT (parse_datetime (&result2, p, &now));
  LOG (p, now, result2);
  ASSERT (result.tv_sec == result2.tv_sec
          && result.tv_nsec == result2.tv_nsec);
  now.tv_sec = 4711;
  now.tv_nsec = 1267;
  p = "UTC+400 yesterday";
  ASSERT (parse_datetime (&result, p, &now));
  LOG (p, now, result);
  p = "UTC+400 1 day ago";
  ASSERT (parse_datetime (&result2, p, &now));
  LOG (p, now, result2);
  ASSERT (result.tv_sec == result2.tv_sec
          && result.tv_nsec == result2.tv_nsec);
  now.tv_sec = 4711;
  now.tv_nsec = 1267;
  p = "UTC+400 now";
  ASSERT (parse_datetime (&result, p, &now));
  LOG (p, now, result);
  p = "UTC+400 +0 minutes"; /* silly, but simple "UTC+400" is different*/
  ASSERT (parse_datetime (&result2, p, &now));
  LOG (p, now, result2);
  ASSERT (result.tv_sec == result2.tv_sec
          && result.tv_nsec == result2.tv_nsec);

  /* Check that some "next Monday", "last Wednesday", etc. are correct.  */
  setenv ("TZ", "UTC0", 1);
  for (i = 0; day_table[i]; i++)
    {
      unsigned int thur2 = 7 * 24 * 3600; /* 2nd thursday */
      char tmp[32];
      sprintf (tmp, "NEXT %s", day_table[i]);
      now.tv_sec = thur2 + 4711;
      now.tv_nsec = 1267;
      ASSERT (parse_datetime (&result, tmp, &now));
      LOG (tmp, now, result);
      ASSERT (result.tv_nsec == 0);
      ASSERT (result.tv_sec == thur2 + (i == 4 ? 7 : (i + 3) % 7) * 24 * 3600);

      sprintf (tmp, "LAST %s", day_table[i]);
      now.tv_sec = thur2 + 4711;
      now.tv_nsec = 1267;
      ASSERT (parse_datetime (&result, tmp, &now));
      LOG (tmp, now, result);
      ASSERT (result.tv_nsec == 0);
      ASSERT (result.tv_sec == thur2 + ((i + 3) % 7 - 7) * 24 * 3600);
    }

  p = "THURSDAY UTC+00";  /* The epoch was on Thursday.  */
  now.tv_sec = 0;
  now.tv_nsec = 0;
  ASSERT (parse_datetime (&result, p, &now));
  LOG (p, now, result);
  ASSERT (result.tv_sec == now.tv_sec
          && result.tv_nsec == now.tv_nsec);

  p = "FRIDAY UTC+00";
  now.tv_sec = 0;
  now.tv_nsec = 0;
  ASSERT (parse_datetime (&result, p, &now));
  LOG (p, now, result);
  ASSERT (result.tv_sec == 24 * 3600
          && result.tv_nsec == now.tv_nsec);

  /* Exercise a sign-extension bug.  Before July 2012, an input
     starting with a high-bit-set byte would be treated like "0".  */
  ASSERT ( ! parse_datetime (&result, "\xb0", &now));

  /* Exercise TZ="" parsing code.  */
  /* These two would infloop or segfault before Feb 2014.  */
  ASSERT ( ! parse_datetime (&result, "TZ=\"\"\"", &now));
  ASSERT ( ! parse_datetime (&result, "TZ=\"\" \"", &now));
  /* Exercise invalid patterns.  */
  ASSERT ( ! parse_datetime (&result, "TZ=\"", &now));
  ASSERT ( ! parse_datetime (&result, "TZ=\"\\\"", &now));
  ASSERT ( ! parse_datetime (&result, "TZ=\"\\n", &now));
  ASSERT ( ! parse_datetime (&result, "TZ=\"\\n\"", &now));
  /* Exercise valid patterns.  */
  ASSERT (   parse_datetime (&result, "TZ=\"\"", &now));
  ASSERT (   parse_datetime (&result, "TZ=\"\" ", &now));
  ASSERT (   parse_datetime (&result, " TZ=\"\"", &now));
  ASSERT (   parse_datetime (&result, "TZ=\"\\\\\"", &now));
  ASSERT (   parse_datetime (&result, "TZ=\"\\\"\"", &now));

  return 0;
}
