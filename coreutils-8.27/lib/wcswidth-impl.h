/* Determine number of screen columns needed for a size-bounded wide string.
   Copyright (C) 1999, 2011-2017 Free Software Foundation, Inc.
   Written by Bruno Haible <bruno@clisp.org>, 1999.

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

int
wcswidth (const wchar_t *s, size_t n)
{
  int count = 0;
  for (; n > 0; s++, n--)
    {
      wchar_t c = *s;
      if (c == (wchar_t)'\0')
        break;
      {
        int width = wcwidth (c);
        if (width < 0)
          goto found_nonprinting;
        if (width > INT_MAX - count)
          goto overflow;
        count += width;
      }
    }
  return count;

 found_nonprinting:
  return -1;

 overflow:
  return INT_MAX;
}
