/* xfts.c -- a wrapper for fts_open

   Copyright (C) 2003-2017 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* Written by Jim Meyering.  */

#include "config.h"

#include <stdbool.h>
#include <stdlib.h>
#include <errno.h>
#include <assert.h>

#include "xalloc.h"
#include "xfts.h"

/* Fail with a proper diagnostic if fts_open fails.  */

FTS *
xfts_open (char * const *argv, int options,
           int (*compar) (const FTSENT **, const FTSENT **))
{
    // Need to prevent this from calling system::fts_open, instead call the one from fts.c
  FTS *fts = _fts_open (argv, options | FTS_CWDFD, compar);
  if (fts == NULL)
    {
      /* This can fail in two ways: out of memory or with errno==EINVAL,
         which indicates it was called with invalid bit_flags.  */
      assert (errno != EINVAL);
      xalloc_die ();
    }

  return fts;
}

/* When fts_read returns FTS_DC to indicate a directory cycle,
   it may or may not indicate a real problem.  When a program like
   chgrp performs a recursive traversal that requires traversing
   symbolic links, it is *not* a problem.  However, when invoked
   with "-P -R", it deserves a warning.  The fts_options member
   records the options that control this aspect of fts's behavior,
   so test that.  */
bool
cycle_warning_required (FTS const *fts, FTSENT const *ent)
{
#define ISSET(Fts,Opt) ((Fts)->fts_options & (Opt))
  /* When dereferencing no symlinks, or when dereferencing only
     those listed on the command line and we're not processing
     a command-line argument, then a cycle is a serious problem. */
  return ((ISSET (fts, FTS_PHYSICAL) && !ISSET (fts, FTS_COMFOLLOW))
          || (ISSET (fts, FTS_PHYSICAL) && ISSET (fts, FTS_COMFOLLOW)
              && ent->fts_level != FTS_ROOTLEVEL));
}
