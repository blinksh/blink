/* Convert decimal strings with bounds checking and exit on error.

   Copyright (C) 2014-2017 Free Software Foundation, Inc.

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

#include "xdectoint.h"

#include <errno.h>
#include <inttypes.h>
#include <stdlib.h>

#include "error.h"
#include "quote.h"
#include "xstrtol.h"

/* Parse numeric string N_STR of base BASE, and return the value.
   Exit on parse error or if MIN or MAX are exceeded.
   Strings can have multiplicative SUFFIXES if specified.
   ERR is printed along with N_STR on error.  */

__xdectoint_t
__xnumtoint (const char *n_str, int base, __xdectoint_t min, __xdectoint_t max,
             const char *suffixes, const char *err, int err_exit)
{
  strtol_error s_err;

  __xdectoint_t tnum;
  s_err = __xstrtol (n_str, NULL, base, &tnum, suffixes);

  if (s_err == LONGINT_OK)
    {
      if (tnum < min || max < tnum)
        {
          s_err = LONGINT_OVERFLOW;
          /* Use have the INT range as a heuristic to distinguish
             type overflow rather than other min/max limits.  */
          if (tnum > INT_MAX/2)
            errno = EOVERFLOW;
#if __xdectoint_signed
          else if (tnum < INT_MIN/2)
            errno = EOVERFLOW;
#endif
          else
            errno = ERANGE;
        }
    }
  else if (s_err == LONGINT_OVERFLOW)
    errno = EOVERFLOW;
  else if (s_err == LONGINT_INVALID_SUFFIX_CHAR_WITH_OVERFLOW)
    errno = 0; /* Don't show ERANGE errors for invalid numbers.  */

  if (s_err != LONGINT_OK)
    {
      /* EINVAL error message is redundant in this context.  */
      error (err_exit ? err_exit : EXIT_FAILURE, errno == EINVAL ? 0 : errno,
             "%s: %s", err, quote (n_str));
    }

  return tnum;
}

/* Parse decimal string N_STR, and return the value.
   Exit on parse error or if MIN or MAX are exceeded.
   Strings can have multiplicative SUFFIXES if specified.
   ERR is printed along with N_STR on error.  */

__xdectoint_t
__xdectoint (const char *n_str, __xdectoint_t min, __xdectoint_t max,
             const char *suffixes, const char *err, int err_exit)
{
  return __xnumtoint (n_str, 10, min, max, suffixes, err, err_exit);
}
