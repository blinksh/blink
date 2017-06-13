/* operand2sig.c -- common function for parsing signal specifications
   Copyright (C) 2008-2017 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* Extracted from kill.c/timeout.c by Pádraig Brady.
   FIXME: Move this to gnulib/str2sig.c */


/* Convert OPERAND to a signal number with printable representation SIGNAME.
   Return the signal number, or -1 if unsuccessful.  */

#include <config.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/wait.h>

#include "system.h"
#include "error.h"
#include "quote.h"
#include "sig2str.h"
#include "operand2sig.h"

extern int
operand2sig (char const *operand, char *signame)
{
  int signum;

  if (ISDIGIT (*operand))
    {
      /* Note we don't put a limit on the maximum value passed,
         because we're checking shell $? values here, and ksh for
         example will add 256 to the signal value, thus being wider
         than the number of WEXITSTATUS bits.
         We could validate that values were not above say
         ((WEXITSTATUS (~0) << 1) + 1), which would cater for ksh.
         But some shells may use other adjustments in future to be
         (forward) compatible with systems that support
         wider exit status values as discussed at
         http://austingroupbugs.net/view.php?id=947  */

      char *endp;
      long int l = (errno = 0, strtol (operand, &endp, 10));
      int i = l;
      signum = (operand == endp || *endp || errno || i != l ? -1
                : WIFSIGNALED (i) ? WTERMSIG (i) : i);
    }
  else
    {
      /* Convert signal to upper case in the C locale, not in the
         current locale.  Don't assume ASCII; it might be EBCDIC.  */
      char *upcased = xstrdup (operand);
      char *p;
      for (p = upcased; *p; p++)
        if (strchr ("abcdefghijklmnopqrstuvwxyz", *p))
          *p += 'A' - 'a';

      /* Look for the signal name, possibly prefixed by "SIG",
         and possibly lowercased.  */
      if (!(str2sig (upcased, &signum) == 0
            || (upcased[0] == 'S' && upcased[1] == 'I' && upcased[2] == 'G'
                && str2sig (upcased + 3, &signum) == 0)))
        signum = -1;

      free (upcased);
    }

  if (signum < 0 || sig2str (signum, signame) != 0)
    {
      error (0, 0, _("%s: invalid signal"), quote (operand));
      return -1;
    }

  return signum;
}
