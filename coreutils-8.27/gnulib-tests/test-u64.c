/* Test of <u64.h>
   Copyright (C) 2009-2017 Free Software Foundation, Inc.

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

/* Written by Simon Josefsson <simon@josefsson.org>, 2009.  */

#include <config.h>

#include <u64.h>

int
main (void)
{
  u64 i = u64init (42, 4711);
  u64 j, k, l;

  j = u64hilo (42, 4711);

  if (u64lt (i, j) || u64lt (j, i))
    return 1;

  i = u64hilo (0, 42);
  j = u64hilo (0, 43);

  if (!u64lt (i, j))
    return 1;

  k = u64plus (i, j);
  l = u64hilo (0, 42 + 43);

  if (u64lt (k, l) || u64lt (l, k))
    return 1;

  return 0;
}
