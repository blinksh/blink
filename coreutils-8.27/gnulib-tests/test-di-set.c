/* Test the di-set module.
   Copyright (C) 2010-2017 Free Software Foundation, Inc.

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

#include "di-set.h"

#include "macros.h"

int
main (void)
{
  struct di_set *dis = di_set_alloc ();
  ASSERT (dis);

  ASSERT (di_set_lookup (dis, 2, 5) == 0); /* initial lookup fails */
  ASSERT (di_set_insert (dis, 2, 5) == 1); /* first insertion succeeds */
  ASSERT (di_set_insert (dis, 2, 5) == 0); /* duplicate fails */
  ASSERT (di_set_insert (dis, 3, 5) == 1); /* diff dev, duplicate inode is ok */
  ASSERT (di_set_insert (dis, 2, 8) == 1); /* same dev, different inode is ok */
  ASSERT (di_set_lookup (dis, 2, 5) == 1); /* now, the lookup succeeds */

  /* very large (or negative) inode number */
  ASSERT (di_set_insert (dis, 5, (ino_t) -1) == 1);
  ASSERT (di_set_insert (dis, 5, (ino_t) -1) == 0); /* dup */

  {
    unsigned int i;
    for (i = 0; i < 3000; i++)
      ASSERT (di_set_insert (dis, 9, i) == 1);
    for (i = 0; i < 3000; i++)
      ASSERT (di_set_insert (dis, 9, i) == 0); /* duplicate fails */
  }

  di_set_free (dis);

  return 0;
}
