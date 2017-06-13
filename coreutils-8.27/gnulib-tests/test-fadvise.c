/* Test that fadvise works as advertised.
   Copyright (C) 2010-2017 Free Software Foundation, Inc.

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

/* Written by Pádraig Brady.  */

#include <config.h>
#include <stdio.h>

#include "fadvise.h"

/* We ignore any errors as these hints are only advisory.
 * There is the chance one can pass invalid ADVICE, which will
 * not be indicated, but given the simplicity of the interface
 * this is unlikely.  Also not returning errors allows the
 * unconditional passing of descriptors to non standard files,
 * which will just be ignored if unsupported.  */

int
main (void)
{
  /* Valid.  */
  fadvise (stdin, FADVISE_SEQUENTIAL);
  fdadvise (fileno (stdin), 0, 0, FADVISE_RANDOM);

  /* Ignored.  */
  fadvise (NULL, FADVISE_RANDOM);

  /* Invalid.  */
  fdadvise (42, 0, 0, FADVISE_RANDOM);
  /* Unfortunately C enums are not types.
     One could hack type safety by wrapping in a struct,
     but it's probably not worth the complexity in this case.  */
  fadvise (stdin, FADVISE_SEQUENTIAL + FADVISE_RANDOM);
  fadvise (stdin, 4242);

  return 0;
}
