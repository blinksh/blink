/* help detect directory cycles efficiently

   Copyright (C) 2003-2006, 2009-2017 Free Software Foundation, Inc.

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

/* Written by Jim Meyering */

#include "config.h"

#include "cycle-check.h"

#include <sys/types.h>
#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

#include "assure.h"

#define CC_MAGIC 9827862

/* Return true if I is a power of 2, or is zero.  */

static bool
is_zero_or_power_of_two (uintmax_t i)
{
  return (i & (i - 1)) == 0;
}

void
cycle_check_init (struct cycle_check_state *state)
{
  state->chdir_counter = 0;
  state->magic = CC_MAGIC;
}

/* In traversing a directory hierarchy, call this function once for each
   descending chdir call, with SB corresponding to the chdir operand.
   If SB corresponds to a directory that has already been seen,
   return true to indicate that there is a directory cycle.
   Note that this is done "lazily", which means that some of
   the directories in the cycle may be processed twice before
   the cycle is detected.  */

bool
cycle_check (struct cycle_check_state *state, struct stat const *sb)
{
  assure (state->magic == CC_MAGIC);

  /* If the current directory ever happens to be the same
     as the one we last recorded for the cycle detection,
     then it's obviously part of a cycle.  */
  if (state->chdir_counter && SAME_INODE (*sb, state->dev_ino))
    return true;

  /* If the number of "descending" chdir calls is a power of two,
     record the dev/ino of the current directory.  */
  if (is_zero_or_power_of_two (++(state->chdir_counter)))
    {
      /* On all architectures that we know about, if the counter
         overflows then there is a directory cycle here somewhere,
         even if we haven't detected it yet.  Typically this happens
         only after the counter is incremented 2**64 times, so it's a
         fairly theoretical point.  */
      if (state->chdir_counter == 0)
        return true;

      state->dev_ino.st_dev = sb->st_dev;
      state->dev_ino.st_ino = sb->st_ino;
    }

  return false;
}
