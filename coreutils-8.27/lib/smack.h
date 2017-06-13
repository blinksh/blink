/* Include and determine availability of smack routines
   Copyright (C) 2013-2017 Free Software Foundation, Inc.

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

/* Here we replace or wrap the most common smack functions used by coreutils.
   Others will need to be protected by HAVE_SMACK.  */

#include "config.h"

#ifdef HAVE_SMACK
# include <sys/smack.h>
#else
static inline ssize_t
smack_new_label_from_self (char **label)
{
  return -1;
}

static inline int
smack_set_label_for_self (const char *label)
{
  return -1;
}
#endif

static inline bool
is_smack_enabled (void)
{
#ifdef HAVE_SMACK
  return smack_smackfs_path () != NULL;
#else
  return false;
#endif
}
