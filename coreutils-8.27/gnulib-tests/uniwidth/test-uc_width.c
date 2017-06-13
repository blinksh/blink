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

/* Written by Bruno Haible <bruno@clisp.org>, 2007.  */

#include <config.h>

#include "uniwidth.h"

#include "macros.h"

int
main ()
{
  ucs4_t uc;

  /* Test width of ASCII characters.  */
  for (uc = 0x0020; uc < 0x007F; uc++)
    ASSERT (uc_width (uc, "ISO-8859-2") == 1);

  /* Test width of some non-spacing characters.  */
  ASSERT (uc_width (0x0301, "UTF-8") == 0);
  ASSERT (uc_width (0x05B0, "UTF-8") == 0);

  /* Test width of some format control characters.  */
  ASSERT (uc_width (0x200E, "UTF-8") == 0);
  ASSERT (uc_width (0x2060, "UTF-8") == 0);
  ASSERT (uc_width (0xE0001, "UTF-8") == 0);
  ASSERT (uc_width (0xE0044, "UTF-8") == 0);

  /* Test width of some zero width characters.  */
  ASSERT (uc_width (0x200B, "UTF-8") == 0);
  ASSERT (uc_width (0xFEFF, "UTF-8") == 0);

  /* Test width of some CJK characters.  */
  ASSERT (uc_width (0x3000, "UTF-8") == 2);
  ASSERT (uc_width (0xB250, "UTF-8") == 2);
  ASSERT (uc_width (0xFF1A, "UTF-8") == 2);
  ASSERT (uc_width (0x20369, "UTF-8") == 2);
  ASSERT (uc_width (0x2F876, "UTF-8") == 2);

  return 0;
}
