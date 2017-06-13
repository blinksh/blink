/* Convert wide character to multibyte character.
   Copyright (C) 2011-2017 Free Software Foundation, Inc.
   Written by Bruno Haible <bruno@clisp.org>, 2011.

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
wctomb (char *s, wchar_t wc)
{
  if (s == NULL)
    return 0;
  else
    {
      mbstate_t state;
      size_t result;

      memset (&state, 0, sizeof (mbstate_t));
      result = wcrtomb (s, wc, &state);
      if (result == (size_t)-1)
        return -1;
      return result;
    }
}
