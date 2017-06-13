/* Parse dates for touch and date.

   Copyright (C) 1989-1991, 1998, 2000-2017 Free Software Foundation, Inc.

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

/* Yacc-based version written by Jim Kingdon and David MacKenzie.
   Rewritten by Jim Meyering.  */

#include <config.h>

#include "posixtm.h"

#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <string.h>

#if USE_UNLOCKED_IO
# include "unlocked-io.h"
#endif

/* ISDIGIT differs from isdigit, as follows:
   - Its arg may be any int or unsigned int; it need not be an unsigned char
     or EOF.
   - It's typically faster.
   POSIX says that only '0' through '9' are digits.  Prefer ISDIGIT to
   isdigit unless it's important to use the locale's definition
   of "digit" even when the host does not conform to POSIX.  */
#define ISDIGIT(c) ((unsigned int) (c) - '0' <= 9)

/*
  POSIX requires:

  touch -t [[CC]YY]mmddhhmm[.ss] FILE...
    8, 10, or 12 digits, followed by optional .ss
    (PDS_LEADING_YEAR | PDS_CENTURY | PDS_SECONDS)

  touch mmddhhmm[YY] FILE... (obsoleted by POSIX 1003.1-2001)
    8 or 10 digits, YY (if present) must be in the range 69-99
    (PDS_TRAILING_YEAR | PDS_PRE_2000)

  date mmddhhmm[[CC]YY]
    8, 10, or 12 digits
    (PDS_TRAILING_YEAR | PDS_CENTURY)

*/

static bool
year (struct tm *tm, const int *digit_pair, size_t n, unsigned int syntax_bits)
{
  switch (n)
    {
    case 1:
      tm->tm_year = *digit_pair;
      /* Deduce the century based on the year.
         POSIX requires that 00-68 be interpreted as 2000-2068,
         and that 69-99 be interpreted as 1969-1999.  */
      if (digit_pair[0] <= 68)
        {
          if (syntax_bits & PDS_PRE_2000)
            return false;
          tm->tm_year += 100;
        }
      break;

    case 2:
      if (! (syntax_bits & PDS_CENTURY))
        return false;
      tm->tm_year = digit_pair[0] * 100 + digit_pair[1] - 1900;
      break;

    case 0:
      {
        time_t now;
        struct tm *tmp;

        /* Use current year.  */
        time (&now);
        tmp = localtime (&now);
        if (! tmp)
          return false;
        tm->tm_year = tmp->tm_year;
      }
      break;

    default:
      abort ();
    }

  return true;
}

static bool
posix_time_parse (struct tm *tm, const char *s, unsigned int syntax_bits)
{
  const char *dot = NULL;
  int pair[6];
  int *p;
  size_t i;

  size_t s_len = strlen (s);
  size_t len = s_len;

  if (syntax_bits & PDS_SECONDS)
    {
      dot = strchr (s, '.');
      if (dot)
        {
          len = dot - s;
          if (s_len - len != 3)
            return false;
        }
    }

  if (! (8 <= len && len <= 12 && len % 2 == 0))
    return false;

  for (i = 0; i < len; i++)
    if (!ISDIGIT (s[i]))
      return false;

  len /= 2;
  for (i = 0; i < len; i++)
    pair[i] = 10 * (s[2*i] - '0') + s[2*i + 1] - '0';

  p = pair;
  if (syntax_bits & PDS_LEADING_YEAR)
    {
      if (! year (tm, p, len - 4, syntax_bits))
        return false;
      p += len - 4;
      len = 4;
    }

  /* Handle 8 digits worth of 'MMDDhhmm'.  */
  tm->tm_mon = *p++ - 1;
  tm->tm_mday = *p++;
  tm->tm_hour = *p++;
  tm->tm_min = *p++;
  len -= 4;

  /* Handle any trailing year.  */
  if (syntax_bits & PDS_TRAILING_YEAR)
    {
      if (! year (tm, p, len, syntax_bits))
        return false;
    }

  /* Handle seconds.  */
  if (!dot)
    tm->tm_sec = 0;
  else if (ISDIGIT (dot[1]) && ISDIGIT (dot[2]))
    tm->tm_sec = 10 * (dot[1] - '0') + dot[2] - '0';
  else
    return false;

  return true;
}

/* Parse a POSIX-style date, returning true if successful.  */

bool
posixtime (time_t *p, const char *s, unsigned int syntax_bits)
{
  struct tm tm0;
  struct tm tm1;
  struct tm const *tm;
  time_t t;

  if (! posix_time_parse (&tm0, s, syntax_bits))
    return false;

  tm1 = tm0;
  tm1.tm_isdst = -1;
  t = mktime (&tm1);

  if (t != (time_t) -1)
    tm = &tm1;
  else
    {
      /* mktime returns -1 for errors, but -1 is also a valid time_t
         value.  Check whether an error really occurred.  */
      tm = localtime (&t);
      if (! tm)
        return false;
    }

  /* Reject dates like "September 31" and times like "25:61".
     However, allow a seconds count of 60 even in time zones that do
     not support leap seconds, treating it as the following second;
     POSIX requires this.  */
  if ((tm0.tm_year ^ tm->tm_year)
      | (tm0.tm_mon ^ tm->tm_mon)
      | (tm0.tm_mday ^ tm->tm_mday)
      | (tm0.tm_hour ^ tm->tm_hour)
      | (tm0.tm_min ^ tm->tm_min)
      | (tm0.tm_sec ^ tm->tm_sec))
    {
      /* Any mismatch without 60 in the tm_sec field is invalid.  */
      if (tm0.tm_sec != 60)
        return false;

      {
        /* Allow times like 01:35:60 or 23:59:60.  */
        time_t dummy;
        char buf[16];
        char *b = stpcpy (buf, s);
        strcpy (b - 2, "59");
        if (!posixtime (&dummy, buf, syntax_bits))
          return false;
      }
    }

  *p = t;
  return true;
}
