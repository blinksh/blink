/* Test the simple ring buffer.
   Copyright (C) 2006-2017 Free Software Foundation, Inc.

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

/* written by Jim Meyering */

#include <config.h>

#include "i-ring.h"

#include "macros.h"

int
main (void)
{
  int o;
  I_ring ir;
  i_ring_init (&ir, -1);
  o = i_ring_push (&ir, 1);
  ASSERT (o == -1);
  o = i_ring_push (&ir, 2);
  ASSERT (o == -1);
  o = i_ring_push (&ir, 3);
  ASSERT (o == -1);
  o = i_ring_push (&ir, 4);
  ASSERT (o == -1);
  o = i_ring_push (&ir, 5);
  ASSERT (o == 1);
  o = i_ring_push (&ir, 6);
  ASSERT (o == 2);
  o = i_ring_push (&ir, 7);
  ASSERT (o == 3);

  o = i_ring_pop (&ir);
  ASSERT (o == 7);
  o = i_ring_pop (&ir);
  ASSERT (o == 6);
  o = i_ring_pop (&ir);
  ASSERT (o == 5);
  o = i_ring_pop (&ir);
  ASSERT (o == 4);
  ASSERT (i_ring_empty (&ir));

  o = i_ring_push (&ir, 8);
  ASSERT (o == -1);
  o = i_ring_pop (&ir);
  ASSERT (o == 8);
  ASSERT (i_ring_empty (&ir));

  return 0;
}
