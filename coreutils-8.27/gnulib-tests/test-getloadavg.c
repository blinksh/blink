/* Test of getting load average.
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

#include <config.h>

#include <stdlib.h>

#include "signature.h"
SIGNATURE_CHECK (getloadavg, int, (double [], int));

#include <errno.h>
#include <stdio.h>
#include <unistd.h>

static void
check_avg (int minutes, double avg, int printit)
{
  if (printit)
    printf ("%d-minute: %f  ", minutes, avg);
  else
    {
      /* Plausibility checks.  */
      if (avg < 0.01)
        printf ("suspiciously low %d-minute average: %f\n", minutes, avg);
      if (avg > 1000000)
        printf ("suspiciously high %d-minute average: %f\n", minutes, avg);
    }
  if (avg < 0 || avg != avg)
    exit (minutes);
}

/* This program can also be used as a manual test, by invoking it with
   an argument; it then prints the load average.  If the argument is
   nonzero, the manual test repeats forever, sleeping for the stated
   interval between each iteration.  */
int
main (int argc, char **argv)
{
  int naptime = 0;

  if (argc > 1)
    naptime = atoi (argv[1]);

  while (1)
    {
      double avg[3];
      int loads = getloadavg (avg, 3);
      if (loads == -1)
        {
          if (! (errno == ENOSYS || errno == ENOTSUP || errno == ENOENT))
            return 1;
          perror ("Skipping test; load average not supported");
          return 77;
        }
      if (loads > 0)
        check_avg (1, avg[0], argc > 1);
      if (loads > 1)
        check_avg (5, avg[1], argc > 1);
      if (loads > 2)
        check_avg (15, avg[1], argc > 1);
      if (loads > 0 && argc > 1)
        putchar ('\n');

      if (naptime == 0)
        break;
      sleep (naptime);
    }

  return 0;
}
