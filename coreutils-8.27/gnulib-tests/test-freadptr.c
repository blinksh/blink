/* Test of freadptr() function.
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

/* Written by Bruno Haible <bruno@clisp.org>, 2008.  */

#include <config.h>

#include "freadptr.h"

#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "macros.h"

int
main (int argc, char **argv)
{
  int nbytes = atoi (argv[1]);
  void *buf = malloc (nbytes);
  ASSERT (fread (buf, 1, nbytes, stdin) == nbytes);

  if (lseek (0, 0, SEEK_CUR) == nbytes)
    {
      /* An unbuffered stdio, such as BeOS or on uClibc compiled without
         __STDIO_BUFFERS.  Or stdin is a pipe.  */
      size_t size;
      ASSERT (freadptr (stdin, &size) == NULL);
    }
  else
    {
      /* Normal buffered stdio.  */
      const char stdin_contents[] =
        "#!/bin/sh\n\n./test-freadptr${EXEEXT} 5 < \"$srcdir/test-freadptr.sh\" || exit 1\ncat \"$srcdir/test-freadptr.sh\" | ./test-freadptr${EXEEXT} 5 || exit 1\nexit 0\n";
      const char *expected = stdin_contents + nbytes;
      size_t available1;
      size_t available2;
      size_t available3;

      /* Test normal behaviour.  */
      {
        const char *ptr = freadptr (stdin, &available1);

        ASSERT (ptr != NULL);
        ASSERT (available1 != 0);
        ASSERT (available1 <= strlen (expected));
        ASSERT (memcmp (ptr, expected, available1) == 0);
      }

      /* Test behaviour after normal ungetc.  */
      ungetc (fgetc (stdin), stdin);
      {
        const char *ptr = freadptr (stdin, &available2);

        if (ptr != NULL)
          {
            ASSERT (available2 == available1);
            ASSERT (memcmp (ptr, expected, available2) == 0);
          }
      }

      /* Test behaviour after arbitrary ungetc.  */
      fgetc (stdin);
      ungetc ('@', stdin);
      {
        const char *ptr = freadptr (stdin, &available3);

        if (ptr != NULL)
          {
            ASSERT (available3 == 1 || available3 == available1);
            ASSERT (ptr[0] == '@');
            if (available3 > 1)
              {
                ASSERT (memcmp (ptr + 1, expected + 1, available3 - 1) == 0);
              }
          }
      }
    }

  return 0;
}
