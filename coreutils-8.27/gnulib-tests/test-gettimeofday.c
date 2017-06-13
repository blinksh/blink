/*
 * Copyright (C) 2005, 2007, 2009-2017 Free Software Foundation, Inc.
 * Written by Jim Meyering.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

#include <config.h>

#include <sys/time.h>

#include "signature.h"
SIGNATURE_CHECK (gettimeofday, int,
                 (struct timeval *, GETTIMEOFDAY_TIMEZONE *));

#include <time.h>

#include <stdio.h>
#include <string.h>

int
main (void)
{
  time_t t = 0;
  struct tm *lt;
  struct tm saved_lt;
  struct timeval tv;
  lt = localtime (&t);
  saved_lt = *lt;
  gettimeofday (&tv, NULL);
  if (memcmp (lt, &saved_lt, sizeof (struct tm)) != 0)
    {
      fprintf (stderr, "gettimeofday still clobbers the localtime buffer!\n");
      return 1;
    }
  return 0;
}
