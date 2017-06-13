/* Test suite for exclude.
   Copyright (C) 2009-2017 Free Software Foundation, Inc.
   This file is part of the GNUlib Library.

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
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <stdbool.h>
#include <fnmatch.h>

#include "exclude.h"
#include "error.h"
#include "argmatch.h"

#ifndef FNM_CASEFOLD
# define FNM_CASEFOLD 0
#endif
#ifndef FNM_LEADING_DIR
# define FNM_LEADING_DIR 0
#endif

char const * const exclude_keywords[] = {
  "noescape",
  "pathname",
  "period",
  "leading_dir",
  "casefold",
  "anchored",
  "include",
  "wildcards",
  NULL
};

int exclude_flags[] = {
  FNM_NOESCAPE,
  FNM_PATHNAME,
  FNM_PERIOD,
  FNM_LEADING_DIR,
  FNM_CASEFOLD,
  EXCLUDE_ANCHORED,
  EXCLUDE_INCLUDE,
  EXCLUDE_WILDCARDS
};

ARGMATCH_VERIFY (exclude_keywords, exclude_flags);

/* Some packages define ARGMATCH_DIE and ARGMATCH_DIE_DECL in <config.h>, and
   thus must link with a definition of that function.  Provide it here.  */
#ifdef ARGMATCH_DIE_DECL

_Noreturn ARGMATCH_DIE_DECL;
ARGMATCH_DIE_DECL { exit (1); }

#endif

int
main (int argc, char **argv)
{
  int exclude_options = 0;
  struct exclude *exclude = new_exclude ();

  if (argc == 1)
    error (1, 0, "usage: %s file -- words...", argv[0]);

  while (--argc)
    {
      char *opt = *++argv;
      if (opt[0] == '-')
        {
          int neg = 0;
          int flag;
          char *s = opt + 1;

          if (opt[1] == '-' && opt[2] == 0)
            {
              argc--;
              break;
            }
          if (strlen (s) > 3 && memcmp (s, "no-", 3) == 0)
            {
              neg = 1;
              s += 3;
            }
          flag = XARGMATCH (opt, s, exclude_keywords, exclude_flags);
          if (neg)
            exclude_options &= ~flag;
          else
            exclude_options |= flag;

          /* Skip this test if invoked with -leading-dir on a system that
             lacks support for FNM_LEADING_DIR. */
          if (strcmp (s, "leading_dir") == 0 && FNM_LEADING_DIR == 0)
            exit (77);

          /* Likewise for -casefold and FNM_CASEFOLD.  */
          if (strcmp (s, "casefold") == 0 && FNM_CASEFOLD == 0)
            exit (77);
        }
      else if (add_exclude_file (add_exclude, exclude, opt,
                                 exclude_options, '\n') != 0)
        error (1, errno, "error loading %s", opt);
    }

  for (; argc; --argc)
    {
      char *word = *++argv;

      printf ("%s: %d\n", word, excluded_file_name (exclude, word));
    }

  free_exclude (exclude);
  return 0;
}
