/* Test of strncat() function.
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

/* Written by Bruno Haible <bruno@clisp.org>, 2010.  */

#include <config.h>

#include <string.h>

#include "signature.h"
SIGNATURE_CHECK (strncat, char *, (char *, const char *, size_t));

#include <stdlib.h>

#include "zerosize-ptr.h"
#include "macros.h"

#define UNIT char
#define U_STRNCAT strncat
#define MAGIC ((char) 0xBA)
#include "unistr/test-strncat.h"

int
main ()
{
  /* Simple string.  */
  { /* "Grüß Gott. Здравствуйте! x=(-b±sqrt(b²-4ac))/(2a)  日本語,中文,한글"
       in UTF-8 encoding.  */
    static const char input[] =
      { 'G', 'r', (char) 0xC3, (char) 0xBC, (char) 0xC3, (char) 0x9F, ' ',
        'G', 'o', 't', 't', '.', ' ', (char) 0xD0, (char) 0x97, (char) 0xD0,
        (char) 0xB4, (char) 0xD1, (char) 0x80, (char) 0xD0, (char) 0xB0,
        (char) 0xD0, (char) 0xB2, (char) 0xD1, (char) 0x81, (char) 0xD1,
        (char) 0x82, (char) 0xD0, (char) 0xB2, (char) 0xD1, (char) 0x83,
        (char) 0xD0, (char) 0xB9, (char) 0xD1, (char) 0x82, (char) 0xD0,
        (char) 0xB5, '!', ' ', 'x', '=', '(', '-', 'b', (char) 0xC2,
        (char) 0xB1, 's', 'q', 'r', 't', '(', 'b', (char) 0xC2, (char) 0xB2,
        '-', '4', 'a', 'c', ')', ')', '/', '(', '2', 'a', ')', ' ', ' ',
        (char) 0xE6, (char) 0x97, (char) 0xA5, (char) 0xE6, (char) 0x9C,
        (char) 0xAC, (char) 0xE8, (char) 0xAA, (char) 0x9E, ',', (char) 0xE4,
        (char) 0xB8, (char) 0xAD, (char) 0xE6, (char) 0x96, (char) 0x87, ',',
        (char) 0xED, (char) 0x95, (char) 0x9C, (char) 0xEA, (char) 0xB8,
        (char) 0x80, '\0'
      };
    check (input, SIZEOF (input));
  }

  return 0;
}
