/* Test of closein module.
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
   along with this program; if not, see <http://www.gnu.org/licenses/>.  */

/* Written by Eric Blake.  */

#include <config.h>

#include "closein.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "binary-io.h"
#include "ignore-value.h"

/* With no arguments, do nothing.  With arguments, attempt to consume
   first 6 bytes of stdin.  In either case, let exit() take care of
   closing std streams and changing exit status if ferror(stdin).  */
int
main (int argc, char **argv)
{
  char buf[7];
  atexit (close_stdin);

  /* close_stdin currently relies on ftell, but mingw ftell is
     unreliable on text mode input.  */
  set_binary_mode (0, O_BINARY);

  if (argc > 2)
    close (0);

  if (argc > 1)
    ignore_value (fread (buf, 1, 6, stdin));
  return 0;
}
