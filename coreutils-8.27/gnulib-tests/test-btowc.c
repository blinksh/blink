/* Test of conversion of unibyte character to wide character.
   Copyright (C) 2008-2017 Free Software Foundation, Inc.

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

#include <wchar.h>

#include "signature.h"
SIGNATURE_CHECK (btowc, wint_t, (int));

#include <locale.h>
#include <stdio.h>

#include "macros.h"

int
main (int argc, char *argv[])
{
  int c;

  /* configure should already have checked that the locale is supported.  */
  if (setlocale (LC_ALL, "") == NULL)
    return 1;

  ASSERT (btowc (EOF) == WEOF);

  if (argc > 1)
    switch (argv[1][0])
      {
      case '1':
        /* Locale encoding is ISO-8859-1 or ISO-8859-15.  */
        for (c = 0; c < 0x80; c++)
          ASSERT (btowc (c) == c);
        for (c = 0xA0; c < 0x100; c++)
          ASSERT (btowc (c) != WEOF);
        return 0;

      case '2':
        /* Locale encoding is UTF-8.  */
        for (c = 0; c < 0x80; c++)
          ASSERT (btowc (c) == c);
        for (c = 0x80; c < 0x100; c++)
          ASSERT (btowc (c) == WEOF);
        return 0;
      }

  return 1;
}
