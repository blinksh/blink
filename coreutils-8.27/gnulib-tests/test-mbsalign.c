/* Test that mbsalign works as advertised.
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

/* Written by Pádraig Brady.  */

#include <config.h>

#include "mbsalign.h"
#include "macros.h"
#include <stdlib.h>
#include <locale.h>

int
main (void)
{
  char dest[4 * 16 + 1];
  size_t width, n;

  /* Test unibyte truncation.  */
  width = 4;
  n = mbsalign ("t\tés", dest, sizeof dest, &width, MBS_ALIGN_LEFT, 0);
  ASSERT (n == 4);

  /* Test center alignment.  */
  width = 4;
  n = mbsalign ("es", dest, sizeof dest, &width, MBS_ALIGN_CENTER, 0);
  ASSERT (*dest == ' ' && *(dest + n - 1) == ' ');
  ASSERT (n == 4);

  /* Test center alignment, with no trailing padding.  */
  width = 4;
  n = mbsalign ("es", dest, sizeof dest, &width, MBS_ALIGN_CENTER,
                MBA_NO_RIGHT_PAD);
  ASSERT (n == 3);
  ASSERT (*dest == ' ' && *(dest + n - 1) == 's');

  /* Test left alignment, with no trailing padding. (truncate only).  */
  width = 4;
  n = mbsalign ("es", dest, sizeof dest, &width, MBS_ALIGN_LEFT,
                MBA_NO_RIGHT_PAD);
  ASSERT (n == 2);
  ASSERT (*dest == 'e' && *(dest + n - 1) == 's');

  /* Test center alignment, with no padding. (truncate only).  */
  width = 4;
  n = mbsalign ("es", dest, sizeof dest, &width, MBS_ALIGN_CENTER,
                MBA_NO_LEFT_PAD | MBA_NO_RIGHT_PAD);
  ASSERT (n == 2);
  ASSERT (*dest == 'e' && *(dest + n - 1) == 's');

  /* Test center alignment, with no left padding. (may be useful for RTL?)  */
  width = 4;
  n = mbsalign ("es", dest, sizeof dest, &width, MBS_ALIGN_CENTER,
                MBA_NO_LEFT_PAD);
  ASSERT (n == 3);
  ASSERT (*dest == 'e' && *(dest + n - 1) == ' ');

  if (setlocale (LC_ALL, "en_US.UTF8"))
    {
      /* Check invalid input is flagged.  */
      width = 4;
      n = mbsalign ("t\xe1\xe2s", dest, sizeof dest, &width, MBS_ALIGN_LEFT, 0);
      ASSERT (n == (size_t) -1);

      /* Check invalid input is treated as unibyte  */
      width = 4;
      n = mbsalign ("t\xe1\xe2s", dest, sizeof dest, &width,
                    MBS_ALIGN_LEFT, MBA_UNIBYTE_FALLBACK);
      ASSERT (n == 4);

      /* Test multibyte center alignment.  */
      width = 4;
      n = mbsalign ("és", dest, sizeof dest, &width, MBS_ALIGN_CENTER, 0);
      ASSERT (n == 5);
      ASSERT (*dest == ' ' && *(dest + n - 1) == ' ');

      /* Test multibyte left alignment.  */
      width = 4;
      n = mbsalign ("és", dest, sizeof dest, &width, MBS_ALIGN_LEFT, 0);
      ASSERT (n == 5);
      ASSERT (*(dest + n - 1) == ' ' && *(dest + n - 2) == ' ');

      /* Test multibyte right alignment.  */
      width = 4;
      n = mbsalign ("és", dest, sizeof dest, &width, MBS_ALIGN_RIGHT, 0);
      ASSERT (n == 5);
      ASSERT (*(dest) == ' ' && *(dest + 1) == ' ');

      /* multibyte multicell truncation.  */
      width = 4;                /* cells */
      n = mbsalign ("日月火水", dest, sizeof dest, &width,
                    MBS_ALIGN_LEFT, 0);
      ASSERT (n == 6);          /* 2 characters */

      /* multibyte unicell truncation.  */
      width = 3;                /* cells */
      n = mbsalign ("¹²³⁴", dest, sizeof dest, &width, MBS_ALIGN_LEFT, 0);
      ASSERT (n == 6);          /* 3 characters */

      /* Check independence from dest buffer. */
      width = 4;                /* cells */
      n = mbsalign ("¹²³⁴", dest, 0, &width, MBS_ALIGN_LEFT, 0);
      ASSERT (n == 9);          /* 4 characters */

      /* Check that width is updated with cells required before padding.  */
      width = 4;                /* cells */
      n = mbsalign ("¹²³", dest, 0, &width, MBS_ALIGN_LEFT, 0);
      ASSERT (width == 3);

      /* Test case where output is larger than input
         (as tab converted to multi byte replacement char).  */
      width = 4;
      n = mbsalign ("t\tés" /* 6 including NUL */ , dest, sizeof dest,
                    &width, MBS_ALIGN_LEFT, 0);
      ASSERT (n == 7);

      /* Test forced unibyte truncation.  */
      width = 4;
      n = mbsalign ("t\tés", dest, sizeof dest, &width, MBS_ALIGN_LEFT,
                    MBA_UNIBYTE_ONLY);
      ASSERT (n == 4);
    }

  return 0;
}
