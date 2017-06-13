/* Test of uc_width() function.
   Copyright (C) 2007-2017 Free Software Foundation, Inc.

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

/* Written by Bruno Haible <bruno@clisp.org>, 2008.  */

#include <config.h>

#include "uniwidth.h"

#include <stdio.h>

#include "macros.h"

/* One of 0, '0', '1', 'A', '2'.  */
static char current_width;
/* The interval for which the current_width holds.  */
static ucs4_t current_start;
static ucs4_t current_end;

static void
finish_interval (void)
{
  if (current_width != 0)
    {
      if (current_start == current_end)
        printf ("%04X\t\t%c\n", (unsigned) current_start, current_width);
      else
        printf ("%04X..%04X\t%c\n", (unsigned) current_start,
                (unsigned) current_end, current_width);
      current_width = 0;
    }
}

static void
add_to_interval (ucs4_t uc, char width)
{
  if (current_width == width && uc == current_end + 1)
    current_end = uc;
  else
    {
      finish_interval ();
      current_width = width;
      current_start = current_end = uc;
    }
}

int
main ()
{
  ucs4_t uc;

  for (uc = 0; uc < 0x110000; uc++)
    {
      int w1 = uc_width (uc, "UTF-8");
      int w2 = uc_width (uc, "GBK");
      char width =
        (w1 == 0 && w2 == 0 ? '0' :
         w1 == 1 && w2 == 1 ? '1' :
         w1 == 1 && w2 == 2 ? 'A' :
         w1 == 2 && w2 == 2 ? '2' :
         0);
      if (width == 0)
        {
          /* uc must be a control character.  */
          ASSERT (w1 < 0 && w2 < 0);
        }
      else
        add_to_interval (uc, width);
    }
  finish_interval ();

  return 0;
}
