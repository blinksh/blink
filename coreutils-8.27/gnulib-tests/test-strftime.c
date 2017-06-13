/* Test that posixtime works as required.
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

/* Written by Jim Meyering.  */

#include <config.h>

#include "strftime.h"

#include <errno.h>
#include <stdio.h>
#include <time.h>
#include <string.h>

#include "macros.h"
#define STREQ(a, b) (strcmp (a, b) == 0)

struct posixtm_test
{
  time_t in;
  int in_ns;
  char const *fmt;
  char const *exp;
};

static struct posixtm_test const T[] =
  {
    { 1300000000, 0,            "%F", "2011-03-13" },
    { 0,          10,           "%T.%N", "00:00:00.000000010" },
    { 0,          0,            NULL, NULL }
  };

static int
posixtm_test (void)
{
  int fail = 0;
  unsigned int i;

  for (i = 0; T[i].fmt; i++)
    {
      char buf[1000];
      time_t t = T[i].in;
      struct tm *tm = gmtime (&t);
      size_t n;

      ASSERT (tm);

      n = nstrftime (buf, sizeof buf, T[i].fmt, tm, 0, T[i].in_ns);
      if (n == 0)
        {
          fail = 1;
          printf ("nstrftime failed with format %s\n", T[i].fmt);
        }

      if (! STREQ (buf, T[i].exp))
        {
          fail = 1;
          printf ("%s: result mismatch: got %s, expected %s\n",
                  T[i].fmt, buf, T[i].exp);
        }
    }

  return fail;
}

struct tzalloc_test
{
  timezone_t tz;
  char const *setting;
};

static struct tzalloc_test TZ[] =
  {
#define Pacific 0
    { 0, "PST8PDT,M3.2.0,M11.1.0"      },
#define Arizona 1
    { 0, "MST7"                        },
#define UTC 2
    { 0, 0                             },
#define CentEur 3
    { 0, "CET-1CEST,M3.5.0,M10.5.0/3"  },
#define Japan 4
    { 0, "JST-9"                       },
#define NZ 5
    { 0, "NZST-12NZDT,M9.5.0,M4.1.0/3" },
#define Unknown 6
    { 0, "<-00>0" },
    { 0 }
  };

struct localtime_rz_test
{
  /* Input parameters.  */
  struct tzalloc_test *tza;
  time_t t;

  /* Expected result.  */
  char const *exp;

  /* Determines if an incorrectly unset tm_isdst
     results in failure or just a warning.  */
  int ahistorical;
};

static struct localtime_rz_test LT[] =
  {
    { TZ+Pacific,          0, "1969-12-31 16:00:00 -0800 (PST)",  0 },
    { TZ+Arizona,          0, "1969-12-31 17:00:00 -0700 (MST)",  0 },
    { TZ+UTC    ,          0, "1970-01-01 00:00:00 +0000 (UTC)",  0 },
    { TZ+CentEur,          0, "1970-01-01 01:00:00 +0100 (CET)",  0 },
    { TZ+Japan  ,          0, "1970-01-01 09:00:00 +0900 (JST)",  0 },
    { TZ+NZ     ,          0, "1970-01-01 13:00:00 +1300 (NZDT)", 1 },
    { TZ+Unknown,          0, "1970-01-01 00:00:00 -0000 (-00)",  0 },
    { TZ+Pacific,  500000001, "1985-11-04 16:53:21 -0800 (PST)",  0 },
    { TZ+Arizona,  500000001, "1985-11-04 17:53:21 -0700 (MST)",  0 },
    { TZ+UTC    ,  500000001, "1985-11-05 00:53:21 +0000 (UTC)",  0 },
    { TZ+CentEur,  500000001, "1985-11-05 01:53:21 +0100 (CET)",  1 },
    { TZ+Japan  ,  500000001, "1985-11-05 09:53:21 +0900 (JST)",  0 },
    { TZ+NZ     ,  500000001, "1985-11-05 13:53:21 +1300 (NZDT)", 0 },
    { TZ+Unknown,  500000001, "1985-11-05 00:53:21 -0000 (-00)",  0 },
    { TZ+Pacific, 1000000002, "2001-09-08 18:46:42 -0700 (PDT)",  0 },
    { TZ+Arizona, 1000000002, "2001-09-08 18:46:42 -0700 (MST)",  0 },
    { TZ+UTC    , 1000000002, "2001-09-09 01:46:42 +0000 (UTC)",  0 },
    { TZ+CentEur, 1000000002, "2001-09-09 03:46:42 +0200 (CEST)", 0 },
    { TZ+Japan  , 1000000002, "2001-09-09 10:46:42 +0900 (JST)",  0 },
    { TZ+NZ     , 1000000002, "2001-09-09 13:46:42 +1200 (NZST)", 0 },
    { TZ+Unknown, 1000000002, "2001-09-09 01:46:42 -0000 (-00)",  0 },
    { 0 }
  };

static int
tzalloc_test (void)
{
  int fail = 0;
  int i;

  for (i = 0; LT[i].tza; i++)
    {
      struct tzalloc_test *tza = LT[i].tza;
      long lt = LT[i].t;
      timezone_t tz = tza->tz;
      char const *setting;
      static char const format[] = "%Y-%m-%d %H:%M:%S %z (%Z)";
      char buf[1000];
      struct tm tm;
      size_t n;

      if (!tz && tza->setting)
        {
          tz = tzalloc (tza->setting);
          if (!tz)
            {
              fail = 1;
              printf ("%s: tzalloc: %s\n", TZ[i].setting, strerror (errno));
              continue;
            }
          tza->tz = tz;
        }

      setting = tza->setting ? tza->setting : "UTC0";

      if (!localtime_rz (tz, &LT[i].t, &tm))
        {
          fail = 1;
          printf ("%s: %ld: localtime_rz: %s\n", setting, lt,
                  strerror (errno));
          continue;
        }

      n = nstrftime (buf, sizeof buf, format, &tm, tz, 0);
      if (n == 0)
        {
          fail = 1;
          printf ("%s: %ld: nstrftime failed\n", setting, lt);
          continue;
        }

      if (! (STREQ (buf, LT[i].exp)
             || (!tz && n == strlen (LT[i].exp)
                 && memcmp (buf, LT[i].exp, n - sizeof "(GMT)" + 1) == 0
                 && STREQ (buf + n - sizeof "(GMT)" + 1, "(GMT)"))))
        {
          /* Don't fail for unhandled dst in ahistorical entries,
             as gnulib doesn't currently fix that issue, seen on Darwin 14.  */
          if (!LT[i].ahistorical || tm.tm_isdst)
            fail = 1;
          printf ("%s: expected \"%s\", got \"%s\"\n",
                  setting, LT[i].exp, buf);
        }
    }

  return fail;
}


static int
quarter_test (void)
{
  int result = 0;
  size_t mon;

  /* Check %q.  */
  for (mon = 1; mon <= 12; mon++)
    {
      char out[2];
      char exp[2] = {0,};
      struct tm qtm = { .tm_mon = mon - 1 };
      char fmt[3] = {'%','q','\0'};

      size_t r = nstrftime (out, sizeof (out), fmt, &qtm, 0, 0);
      if (r == 0)
        {
          puts ("nstrftime(\"%q\") failed");
          result = 1;
          break;
        }

      exp[0] = mon < 4 ? '1' : mon < 7 ? '2' : mon < 10 ? '3' : '4';
      if (strcmp (out, exp) != 0)
        {
          printf ("nstrftime %%q: expected \"%s\", got \"%s\"\n", exp, out);
          result = 1;
          break;
        }
    }

  return result;
}

int
main (void)
{
  int fail = 0;
  fail |= posixtm_test ();
  fail |= tzalloc_test ();
  fail |= quarter_test ();
  return fail;
}

/*
Local Variables:
indent-tabs-mode: nil
End:
*/
