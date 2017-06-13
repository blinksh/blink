/* Determine whether we can write any file.

   Copyright (C) 2007, 2009-2017 Free Software Foundation, Inc.

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

/* Written by Paul Eggert.  */

#include "config.h"

#include "write-any-file.h"
#include "priv-set.h"
#include "root-uid.h"

#include <unistd.h>

/* Return true if we know that we can write any file, including
   writing directories.  */

bool
can_write_any_file (void)
{
  static bool initialized;
  static bool can_write;

  if (! initialized)
    {
      bool can = false;
#if defined PRIV_FILE_DAC_WRITE
      can = (priv_set_ismember (PRIV_FILE_DAC_WRITE) == 1);
#else
      /* In traditional Unix, only root can unlink directories.  */
      can = (geteuid () == ROOT_UID);
#endif
      can_write = can;
      initialized = true;
    }

  return can_write;
}
