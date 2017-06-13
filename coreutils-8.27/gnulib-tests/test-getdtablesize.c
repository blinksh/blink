/* Test of getdtablesize() function.
   Copyright (C) 2008-2017 Free Software Foundation, Inc.

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

#include <unistd.h>

#include "signature.h"
SIGNATURE_CHECK (getdtablesize, int, (void));

#include "macros.h"

int
main (int argc, char *argv[])
{
  ASSERT (getdtablesize () >= 3);
  ASSERT (dup2 (0, getdtablesize() - 1) == getdtablesize () - 1);
  ASSERT (dup2 (0, getdtablesize()) == -1);

  return 0;
}
