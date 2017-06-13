/* Test argv iterator
   Copyright (C) 2008-2017 Free Software Foundation, Inc.

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

#include "argv-iter.h"

#include <stdio.h>
#include <string.h>

#include "macros.h"

#define ARRAY_CARDINALITY(Array) (sizeof (Array) / sizeof *(Array))
#define STREQ(a, b) (strcmp (a, b) == 0)

static FILE *
write_nul_delimited_argv (char **argv)
{
  FILE *fp = tmpfile ();
  ASSERT (fp);
  while (*argv)
    {
      size_t len = strlen (*argv) + 1;
      ASSERT (fwrite (*argv, len, 1, fp) == 1);
      argv++;
    }
  ASSERT (fflush (fp) == 0);
  rewind (fp);
  return fp;
}

int
main (void)
{
  static char one[] = "1";
  static char two[] = "2";
  static char three[] = "3";
  static char *av[][4] = {
    {NULL},
    {one, NULL},
    {one, two, NULL},
    {one, two, three, NULL}
  };

  int use_stream;
  for (use_stream = 0; use_stream < 2; use_stream++)
    {
      size_t i;
      for (i = 0; i < ARRAY_CARDINALITY (av); i++)
        {
          FILE *fp;
          struct argv_iterator *ai;
          size_t n_found = 0;
          if (use_stream)
            {
              /* Generate an identical list to be read via FP.  */
              ASSERT ((fp = write_nul_delimited_argv (av[i])) != NULL);
              ai = argv_iter_init_stream (fp);
            }
          else
            {
              fp = NULL;
              ai = argv_iter_init_argv (av[i]);
            }
          ASSERT (ai);

          while (1)
            {
              enum argv_iter_err ai_err;
              char *s = argv_iter (ai, &ai_err);
              ASSERT ((i == n_found) == (ai_err == AI_ERR_EOF));
              ASSERT ((s == NULL) ^ (ai_err == AI_ERR_OK));
              ASSERT (ai_err == AI_ERR_OK || ai_err == AI_ERR_EOF);
              if (ai_err == AI_ERR_OK)
                ++n_found;
              if (ai_err == AI_ERR_EOF)
                break;
              /* In stream mode, the strings are equal, but
                 in argv mode the actual pointers are equal.  */
              ASSERT (use_stream
                      ? STREQ (s, av[i][n_found - 1])
                      : s == av[i][n_found - 1]);
            }
          ASSERT (argv_iter_n_args (ai) == i);
          argv_iter_free (ai);
          if (fp)
            ASSERT (fclose (fp) == 0);
        }
    }

  return 0;
}
