/* Test of case-insensitive string comparison function.
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

#include <string.h>

#include <locale.h>

#include "macros.h"

int
main ()
{
  /* configure should already have checked that the locale is supported.  */
  if (setlocale (LC_ALL, "") == NULL)
    return 1;

  ASSERT (mbscasecmp ("paragraph", "Paragraph") == 0);

  ASSERT (mbscasecmp ("paragrapH", "parAgRaph") == 0);

  ASSERT (mbscasecmp ("paragraph", "paraLyzed") < 0);
  ASSERT (mbscasecmp ("paraLyzed", "paragraph") > 0);

  ASSERT (mbscasecmp ("para", "paragraph") < 0);
  ASSERT (mbscasecmp ("paragraph", "para") > 0);

  /* The following tests shows how mbscasecmp() is different from
     strcasecmp().  */

  ASSERT (mbscasecmp ("\303\266zg\303\274r", "\303\226ZG\303\234R") == 0); /* özgür */
  ASSERT (mbscasecmp ("\303\226ZG\303\234R", "\303\266zg\303\274r") == 0); /* özgür */

  /* This test shows how strings of different size can compare equal.  */
  ASSERT (mbscasecmp ("turkish", "TURK\304\260SH") == 0);
  ASSERT (mbscasecmp ("TURK\304\260SH", "turkish") == 0);

  return 0;
}
