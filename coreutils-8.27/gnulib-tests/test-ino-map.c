/* Test the ino-map module.
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

#include "ino-map.h"

#include "macros.h"

int
main ()
{
  enum { INO_MAP_INIT = 123 };
  struct ino_map *ino_map = ino_map_alloc (INO_MAP_INIT);
  ASSERT (ino_map != NULL);

  ASSERT (ino_map_insert (ino_map, 42) == INO_MAP_INIT);
  ASSERT (ino_map_insert (ino_map, 42) == INO_MAP_INIT);
  ASSERT (ino_map_insert (ino_map, 398) == INO_MAP_INIT + 1);
  ASSERT (ino_map_insert (ino_map, 398) == INO_MAP_INIT + 1);
  ASSERT (ino_map_insert (ino_map, 0) == INO_MAP_INIT + 2);
  ASSERT (ino_map_insert (ino_map, 0) == INO_MAP_INIT + 2);

  {
    int i;
    for (i = 0; i < 100; i++)
      {
        ASSERT (ino_map_insert (ino_map, 10000 + i) == INO_MAP_INIT + 3 + i);
      }
  }

  ino_map_free (ino_map);

  return 0;
}
