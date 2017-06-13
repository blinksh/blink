/* Test of freadseek() function.
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

#include "freadseek.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "macros.h"

int
main (int argc, char **argv)
{
  static const char stdin_contents[] =
    "#!/bin/sh\n\n./test-freadseek${EXEEXT} 5 19 6 7 18 9 19 < \"$srcdir/test-freadseek.sh\" || exit 1\ncat \"$srcdir/test-freadseek.sh\" | ./test-freadseek${EXEEXT} 5 19 6 7 18 9 19 || exit 1\nexit 0\n";
  int nbytes1 = atoi (argv[1]);
  int nbytes2 = atoi (argv[2]);
  int nbytes3 = atoi (argv[3]);
  int nbytes4 = atoi (argv[4]);
  int nbytes5 = atoi (argv[5]);
  int nbytes6 = atoi (argv[6]);
  int nbytes7 = atoi (argv[7]);
  void *buf1 = malloc (nbytes1);
  void *buf3 = malloc (nbytes3);
  void *buf5 = malloc (nbytes5);
  void *buf7 = malloc (nbytes7);
  /* A private variable to keep track of the position.  */
  size_t position = 0;

  ASSERT (fread (buf1, 1, nbytes1, stdin) == nbytes1);
  ASSERT (memcmp (buf1, stdin_contents + position, nbytes1) == 0);
  position += nbytes1;

  /* Test normal behaviour.  */
  ASSERT (freadseek (stdin, nbytes2) == 0);
  position += nbytes2;

  ASSERT (fread (buf3, 1, nbytes3, stdin) == nbytes3);
  ASSERT (memcmp (buf3, stdin_contents + position, nbytes3) == 0);
  position += nbytes3;

  /* Test behaviour after normal ungetc.  */
  ungetc (fgetc (stdin), stdin);
  ASSERT (freadseek (stdin, nbytes4) == 0);
  position += nbytes4;

  ASSERT (fread (buf5, 1, nbytes5, stdin) == nbytes5);
  ASSERT (memcmp (buf5, stdin_contents + position, nbytes5) == 0);
  position += nbytes5;

  /* Test behaviour after arbitrary ungetc.  */
  fgetc (stdin);
  ungetc ('@', stdin);
  ASSERT (freadseek (stdin, nbytes6) == 0);
  position += nbytes6;

  ASSERT (fread (buf7, 1, nbytes7, stdin) == nbytes7);
  ASSERT (memcmp (buf7, stdin_contents + position, nbytes7) == 0);
  position += nbytes7;

  /* Test move to end of file.  */
  ASSERT (freadseek (stdin, strlen (stdin_contents) - position) == 0);
  ASSERT (fgetc (stdin) == EOF);
  ASSERT (!ferror (stdin));

#if !defined __MINT__ /* FreeMiNT has problems seeking past end of file */
  /* Test move beyond end of file.  */
  ASSERT (freadseek (stdin, 1000000) == 0);
  ASSERT (fgetc (stdin) == EOF);
  ASSERT (!ferror (stdin));
#endif

  return 0;
}
