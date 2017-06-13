/* Test setting the error indicator of a stream.
   Copyright (C) 2007, 2009-2017 Free Software Foundation, Inc.

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

#include "fseterr.h"

#include <stdio.h>
#include <stdlib.h>

int
main ()
{
  /* All streams are initially created with the error indicator cleared.  */
  if (ferror (stdout))
    abort ();

  /* Verify that fseterr() works.  */
  fseterr (stdout);
  if (!ferror (stdout))
    abort ();

  /* Verify fseterr's effect can be undone by clearerr().  */
  clearerr (stdout);
  if (ferror (stdout))
    abort ();

  return 0;
}
