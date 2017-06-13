/* Test raising a signal.
   Copyright (C) 2011-2017 Free Software Foundation, Inc.

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

#include <config.h>

#include <signal.h>

#include "signature.h"
SIGNATURE_CHECK (raise, int, (int));

#include <stdlib.h>

#include "macros.h"

/* It is safe to use _Noreturn here: exit() never returns, and GCC knows that
   exit() is a non-returning function, even on platforms where its declaration
   in <stdlib.h> does not have the 'noreturn' attribute.  */
static _Noreturn void
handler (int sig)
{
  exit (0);
}

int
main (void)
{
  /* Test behaviour for invalid argument.  */
  ASSERT (raise (-1) != 0);

  /* Test behaviour for SIGINT.  */
  ASSERT (signal (SIGINT, handler) != SIG_ERR);

  raise (SIGINT);

  /* We should not get here, because the handler takes away the control.  */
  exit (1);
}
