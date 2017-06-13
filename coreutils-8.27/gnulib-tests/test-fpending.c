/* Ensure that __fpending works.

   Copyright (C) 2004, 2007-2017 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.

   Written by Jim Meyering.  */

#include <config.h>

#include "fpending.h"

#include <stdio.h>
#include <stdlib.h>

#include "macros.h"

int
main (void)
{
  ASSERT (__fpending (stdout) == 0);

  fputs ("foo", stdout);
  ASSERT (__fpending (stdout) == 3);

  fflush (stdout);
  ASSERT (__fpending (stdout) == 0);

  exit (0);
}
