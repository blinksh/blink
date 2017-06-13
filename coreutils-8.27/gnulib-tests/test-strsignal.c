/* Test of strsignal() function.
   Copyright (C) 2008-2017 Free Software Foundation, Inc.

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

/* Written by Colin Watson <cjwatson@debian.org>, 2008.  */

#include <config.h>

#include <string.h>

#include "signature.h"
SIGNATURE_CHECK (strsignal, char *, (int));

#include <signal.h>

#include "macros.h"

#if HAVE_DECL_SYS_SIGLIST
# define ASSERT_DESCRIPTION(got, expect)
#else
/* In this case, we can guarantee some signal descriptions.  */
# define ASSERT_DESCRIPTION(got, expect) ASSERT (!strcmp (got, expect))
#endif

int
main (void)
{
  /* Work around bug in cygwin 1.5.25 <string.h> by declaring str as
     const char *, even though strsignal is supposed to return char *.
     At any rate, this doesn't hurt, since POSIX 200x states that "The
     string pointed to shall not be modified by the application."  */
  const char *str;

  /* We try a couple of signals, since not all signals are supported
     everywhere.  Notwithstanding the #ifdef for neatness, SIGINT should in
     fact be available on all platforms.  */

#ifdef SIGHUP
  str = strsignal (SIGHUP);
  ASSERT (str);
  ASSERT (*str);
  ASSERT_DESCRIPTION (str, "Hangup");
#endif

#ifdef SIGINT
  str = strsignal (SIGINT);
  ASSERT (str);
  ASSERT (*str);
  ASSERT_DESCRIPTION (str, "Interrupt");
#endif

  /* Test that for out-of-range signal numbers the result is usable.  */

  str = strsignal (-1);
  ASSERT (str);
  ASSERT (str != (char *) -1);
  ASSERT (strlen (str));

  str = strsignal (9249234);
  ASSERT (str);
  ASSERT (str != (char *) -1);
  ASSERT (strlen (str));

  return 0;
}
