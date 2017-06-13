/* Test of freadahead() function.
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

#include "freadahead.h"

#include <stdlib.h>
#include <unistd.h>

#include "macros.h"

int
main (int argc, char **argv)
{
  int nbytes = atoi (argv[1]);
  if (nbytes > 0)
    {
      void *buf = malloc (nbytes);
      ASSERT (fread (buf, 1, nbytes, stdin) == nbytes);
    }

  if (nbytes == 0)
    ASSERT (freadahead (stdin) == 0);
  else
    {
      if (lseek (0, 0, SEEK_CUR) == nbytes)
        /* An unbuffered stdio, such as BeOS or on uClibc compiled without
           __STDIO_BUFFERS.  */
        ASSERT (freadahead (stdin) == 0);
      else
        {
          /* Normal buffered stdio.  */
          size_t buffered;
          int c, c2;

          ASSERT (freadahead (stdin) != 0);
          buffered = freadahead (stdin);

          c = fgetc (stdin);
          ASSERT (freadahead (stdin) == buffered - 1);
          ungetc (c, stdin);
          ASSERT (freadahead (stdin) == buffered);
          c2 = fgetc (stdin);
          ASSERT (c2 == c);
          ASSERT (freadahead (stdin) == buffered - 1);

          c = '@';
          ungetc (c, stdin);
          ASSERT (freadahead (stdin) == buffered);
          c2 = fgetc (stdin);
          ASSERT (c2 == c);
          ASSERT (freadahead (stdin) == buffered - 1);
        }
    }

  return 0;
}
