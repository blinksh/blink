/* Test that posixtime works as required.
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

/* Written by Jim Meyering.  */

#include <config.h>

#include "posixtm.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <time.h>

#include "intprops.h"
#include "macros.h"

struct posixtm_test
{
  char const *in;
  unsigned int syntax_bits;
  bool valid;
  int_least64_t t_expected;
};

/* Test mainly with syntax_bits == 13
   (aka: (PDS_LEADING_YEAR | PDS_CENTURY | PDS_SECONDS))  */

static struct posixtm_test const T[] =
  {
    /* no year specified; cross-check via another posixtime call */
    { "12131415.16",     13, 1,            0}, /* ??? Dec 13 14:15:16 ???? */
    { "12131415",        13, 1,            0}, /* ??? Dec 13 14:15:00 ???? */

    /* These two tests fail on 64-bit Solaris up through at least
       Solaris 10, which is off by one day for timestamps before
       0001-01-01 00:00:00 UTC.  */
    { "000001010000.00", 13, 1,
                      - INT64_C (62167219200)},/* Sat Jan  1 00:00:00 0    */
    { "000012312359.59", 13, 1,
                      - INT64_C (62135596801)},/* Fri Dec 31 23:59:59 0    */

    { "000101010000.00", 13, 1,
                      - INT64_C (62135596800)},/* Sat Jan  1 00:00:00 1    */
    { "190112132045.51", 13, 1,
                       - INT64_C (2147483649)},/* Fri Dec 13 20:45:51 1901 */
    { "190112132045.52", 13, 1,
                       - INT64_C (2147483648)},/* Fri Dec 13 20:45:52 1901 */
    { "190112132045.53", 13, 1,  -2147483647}, /* Fri Dec 13 20:45:53 1901 */
    { "190112132046.52", 13, 1,  -2147483588}, /* Fri Dec 13 20:46:52 1901 */
    { "190112132145.52", 13, 1,  -2147480048}, /* Fri Dec 13 21:45:52 1901 */
    { "190112142045.52", 13, 1,  -2147397248}, /* Sat Dec 14 20:45:52 1901 */
    { "190201132045.52", 13, 1,  -2144805248}, /* Mon Jan 13 20:45:52 1902 */
    { "196912312359.59", 13, 1,           -1}, /* Wed Dec 31 23:59:59 1969 */
    { "197001010000.00", 13, 1,            0}, /* Thu Jan  1 00:00:00 1970 */
    { "197001010000.01", 13, 1,            1}, /* Thu Jan  1 00:00:01 1970 */
    { "197001010001.00", 13, 1,           60}, /* Thu Jan  1 00:01:00 1970 */
    { "197001010000.60", 13, 1,           60}, /* Thu Jan  1 00:01:00 1970 */
    { "197001010100.00", 13, 1,         3600}, /* Thu Jan  1 01:00:00 1970 */
    { "197001020000.00", 13, 1,        86400}, /* Fri Jan  2 00:00:00 1970 */
    { "197002010000.00", 13, 1,      2678400}, /* Sun Feb  1 00:00:00 1970 */
    { "197101010000.00", 13, 1,     31536000}, /* Fri Jan  1 00:00:00 1971 */
    { "197001000000.00", 13, 0,            0}, /* -- */
    { "197000010000.00", 13, 0,            0}, /* -- */
    { "197001010060.00", 13, 0,            0}, /* -- */
    { "197001012400.00", 13, 0,            0}, /* -- */
    { "197001320000.00", 13, 0,            0}, /* -- */
    { "197013010000.00", 13, 0,            0}, /* -- */
    { "203801190314.06", 13, 1,   2147483646}, /* Tue Jan 19 03:14:06 2038 */
    { "203801190314.07", 13, 1,   2147483647}, /* Tue Jan 19 03:14:07 2038 */
    { "203801190314.08", 13, 1,
                       INT64_C (  2147483648)},/* Tue Jan 19 03:14:08 2038 */
    { "999912312359.59", 13, 1,
                       INT64_C (253402300799)},/* Fri Dec 31 23:59:59 9999 */
    { "1112131415",      13, 1,   1323785700}, /* Tue Dec 13 14:15:00 2011 */
    { "1112131415.16",   13, 1,   1323785716}, /* Tue Dec 13 14:15:16 2011 */
    { "201112131415.16", 13, 1,   1323785716}, /* Tue Dec 13 14:15:16 2011 */
    { "191112131415.16", 13, 1,  -1831974284}, /* Wed Dec 13 14:15:16 1911 */
    { "203712131415.16", 13, 1,   2144326516}, /* Sun Dec 13 14:15:16 2037 */
    { "3712131415.16",   13, 1,   2144326516}, /* Sun Dec 13 14:15:16 2037 */
    { "6812131415.16",   13, 1,
                       INT64_C (  3122633716)},/* Thu Dec 13 14:15:16 2068 */
    { "6912131415.16",   13, 1,     -1590284}, /* Sat Dec 13 14:15:16 1969 */
    { "7012131415.16",   13, 1,     29945716}, /* Sun Dec 13 14:15:16 1970 */
    { "1213141599",       2, 1,    945094500}, /* Mon Dec 13 14:15:00 1999 */
    { "1213141500",       2, 1,    976716900}, /* Wed Dec 13 14:15:00 2000 */
    { NULL,               0, 0,            0}
  };

int
main (void)
{
  unsigned int i;
  int fail = 0;
  char curr_year_str[30];
  struct tm *tm;
  time_t t_now;
  int err;
  size_t n_bytes;

  /* The above test data requires Universal Time, e.g., TZ="UTC0".  */
  err = setenv ("TZ", "UTC0", 1);
  ASSERT (err == 0);

  t_now = time (NULL);
  ASSERT (t_now != (time_t) -1);
  tm = localtime (&t_now);
  ASSERT (tm);
  n_bytes = strftime (curr_year_str, sizeof curr_year_str, "%Y", tm);
  ASSERT (0 < n_bytes);

  for (i = 0; T[i].in; i++)
    {
      time_t t_out;
      time_t t_exp;
      bool ok;

      /* Some tests assume that time_t is signed.
         If it is unsigned and the result is negative, skip the test. */
      if (T[i].t_expected < 0 && ! TYPE_SIGNED (time_t))
        {
          printf ("skipping %s: result is negative, "
                  "but your time_t is unsigned\n", T[i].in);
          continue;
        }

      if (! (TYPE_MINIMUM (time_t) <= T[i].t_expected
             && T[i].t_expected <= TYPE_MAXIMUM (time_t)))
        {
          printf ("skipping %s: result is out of range of your time_t\n",
                  T[i].in);
          continue;
        }

      t_exp = T[i].t_expected;

      /* If an input string does not specify the year number, determine
         the expected output by calling posixtime with an otherwise
         equivalent string that starts with the current year.  */
      if (8 <= strlen (T[i].in)
          && (T[i].in[8] == '.' || T[i].in[8] == '\0'))
        {
          char tmp_buf[20];
          stpcpy (stpcpy (tmp_buf, curr_year_str), T[i].in);
          ASSERT (posixtime (&t_exp, tmp_buf, T[i].syntax_bits));
        }

      ok = posixtime (&t_out, T[i].in, T[i].syntax_bits);
      if (ok != !!T[i].valid)
        {
          printf ("%s return value mismatch: got %d, expected %d\n",
                  T[i].in, !!ok, T[i].valid);
          fail = 1;
          continue;
        }

      if (!ok)
        continue;

      if (t_out != t_exp)
        {
          printf ("%s mismatch (-: actual; +:expected)\n-%12ld\n+%12ld\n",
                  T[i].in, t_out, t_exp);
          fail = 1;
        }
    }

  return fail;
}

/*
Local Variables:
indent-tabs-mode: nil
End:
*/
