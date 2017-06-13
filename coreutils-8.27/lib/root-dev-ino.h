/* Root device and inode number checking.

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

#ifndef ROOT_DEV_INO_H
# define ROOT_DEV_INO_H 1

# include "dev-ino.h"
# include "same-inode.h"

struct dev_ino *
get_root_dev_ino (struct dev_ino *root_d_i);

/* These macros are common to the programs that support the
   --preserve-root and --no-preserve-root options.  */

# define ROOT_DEV_INO_CHECK(Root_dev_ino, Dir_statbuf) \
    (Root_dev_ino && SAME_INODE (*Dir_statbuf, *Root_dev_ino))

# define ROOT_DEV_INO_WARN(Dirname)					\
  do									\
    {									\
      if (STREQ (Dirname, "/"))						\
        error (0, 0, _("it is dangerous to operate recursively on %s"),	\
               quoteaf (Dirname));					\
      else								\
        error (0, 0,							\
               _("it is dangerous to operate recursively on %s (same as %s)"), \
               quoteaf_n (0, Dirname), quoteaf_n (1, "/"));		\
      error (0, 0, _("use --no-preserve-root to override this failsafe")); \
    }									\
  while (0)

#endif
