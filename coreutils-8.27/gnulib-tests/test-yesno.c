/* Test of yesno module.
   Copyright (C) 2007-2017 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <config.h>

/* Specification.  */
#include "yesno.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "closein.h"
#include "binary-io.h"

/* Test yesno.  Without arguments, read one line.  If first argument
   is zero, close stdin before attempting to read one line.
   Otherwise, read the number of lines specified by first
   argument.  */
int
main (int argc, char **argv)
{
  int i = 1;

  /* yesno recommends that all clients use close_stdin in main.  */
  atexit (close_stdin);
  /* But on mingw, close_stdin leaves stdin's file descriptor at the expected
     position (i.e. where this program left off reading) only if its mode has
     been set to O_BINARY.  If it has been set to O_TEXT, and the file
     descriptor is seekable, and stdin is buffered, the MSVCRT runtime ends up
     setting the file descriptor's position to the expected position _minus_
     the number of LFs not preceded by CR that were read between the expected
     position and the last filled buffer end position.  (I.e. the repositioning
     from the end-of-buffer to the expected position does not work if the input
     file contains end-of-line markers in Unix convention.)  */
  set_binary_mode (0, O_BINARY);

  if (1 < argc)
    i = atoi (argv[1]);
  if (!i)
    {
      i = 1;
      close (0);
    }
  while (i--)
    puts (yesno () ? "Y" : "N");
  return 0;
}
