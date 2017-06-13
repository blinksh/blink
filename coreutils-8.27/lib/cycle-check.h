/* help detect directory cycles efficiently

   Copyright (C) 2003-2004, 2006, 2009-2017 Free Software Foundation, Inc.

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

#ifndef CYCLE_CHECK_H
# define CYCLE_CHECK_H 1

# include <stdint.h>
# include <stdbool.h>
# include "dev-ino.h"
# include "same-inode.h"

struct cycle_check_state
{
  struct dev_ino dev_ino;
  uintmax_t chdir_counter;
  int magic;
};

void cycle_check_init (struct cycle_check_state *state);
bool cycle_check (struct cycle_check_state *state, struct stat const *sb);

# define CYCLE_CHECK_REFLECT_CHDIR_UP(State, SB_dir, SB_subdir) \
  do                                                            \
    {                                                           \
      /* You must call cycle_check at least once before using this macro.  */ \
      if ((State)->chdir_counter == 0)                          \
        abort ();                                               \
      if (SAME_INODE ((State)->dev_ino, SB_subdir))             \
        {                                                       \
          (State)->dev_ino.st_dev = (SB_dir).st_dev;            \
          (State)->dev_ino.st_ino = (SB_dir).st_ino;            \
        }                                                       \
    }                                                           \
  while (0)

#endif
