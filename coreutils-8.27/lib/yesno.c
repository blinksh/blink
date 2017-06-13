/* yesno.c -- read a yes/no response from stdin

   Copyright (C) 1990, 1998, 2001, 2003-2017 Free Software Foundation, Inc.

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

#include "config.h"

#include "yesno.h"

#include "stdlib.h"
#include <stdio.h>

/* Return true if we read an affirmative line from standard input.

   Since this function uses stdin, it is suggested that the caller not
   use STDIN_FILENO directly, and also that the line
   atexit(close_stdin) be added to main().  */

bool
yesno (void)
{
  bool yes;

#if ENABLE_NLS
  char *response = NULL;
  size_t response_size = 0;
  ssize_t response_len = getline (&response, &response_size, stdin);

  if (response_len <= 0)
    yes = false;
  else
    {
      /* Remove EOL if present as that's not part of the matched response,
         and not matched by $ for example.  */
      if (response[response_len - 1] == '\n')
        response[response_len - 1] = '\0';
      yes = (0 < rpmatch (response));
    }

  free (response);
#else
  /* Test against "^[yY]", hardcoded to avoid requiring getline,
     regex, and rpmatch.  */
  int c = getchar ();
  yes = (c == 'y' || c == 'Y');
  while (c != '\n' && c != EOF)
    c = getchar ();
#endif

  return yes;
}
