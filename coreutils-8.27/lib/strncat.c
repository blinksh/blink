/* Concatenate strings.
   Copyright (C) 1999, 2002, 2006, 2010-2017 Free Software Foundation, Inc.
   Written by Bruno Haible <bruno@clisp.org>, 2002.

   This program is free software: you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published
   by the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

#include <config.h>

/* Specification.  */
#include <string.h>

char *
strncat (char *dest, const char *src, size_t n)
{
  char *destptr = dest + strlen (dest);

  for (; n > 0 && (*destptr = *src) != '\0'; src++, destptr++, n--)
    ;
  if (n == 0)
    *destptr = '\0';
  return dest;
}
