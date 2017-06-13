/* A more useful interface to strtol.

   Copyright (C) 1995-1996, 1998-1999, 2001-2004, 2006-2017 Free Software
   Foundation, Inc.

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

#include "config.h"
#include "xstrtol.h"

#include <stdlib.h>

#include "error.h"
#include "exitfail.h"
#include "gettext.h"

#define N_(msgid) msgid

/* Report an error for an invalid integer in an option argument.

   ERR is the error code returned by one of the xstrto* functions.

   Use OPT_IDX to decide whether to print the short option string "C"
   or "-C" or a long option string derived from LONG_OPTION.  OPT_IDX
   is -2 if the short option "C" was used, without any leading "-"; it
   is -1 if the short option "-C" was used; otherwise it is an index
   into LONG_OPTIONS, which should have a name preceded by two '-'
   characters.

   ARG is the option-argument containing the integer.

   After reporting an error, exit with status EXIT_STATUS if it is
   nonzero.  */

static void
xstrtol_error (enum strtol_error err,
               int opt_idx, char c, struct option const *long_options,
               char const *arg,
               int exit_status)
{
  char const *hyphens = "--";
  char const *msgid;
  char const *option;
  char option_buffer[2];

  switch (err)
    {
    default:
      abort ();

    case LONGINT_INVALID:
      msgid = N_("invalid %s%s argument '%s'");
      break;

    case LONGINT_INVALID_SUFFIX_CHAR:
    case LONGINT_INVALID_SUFFIX_CHAR_WITH_OVERFLOW:
      msgid = N_("invalid suffix in %s%s argument '%s'");
      break;

    case LONGINT_OVERFLOW:
      msgid = N_("%s%s argument '%s' too large");
      break;
    }

  if (opt_idx < 0)
    {
      hyphens -= opt_idx;
      option_buffer[0] = c;
      option_buffer[1] = '\0';
      option = option_buffer;
    }
  else
    option = long_options[opt_idx].name;

  error (exit_status, 0, gettext (msgid), hyphens, option, arg);
}

/* Like xstrtol_error, except exit with a failure status.  */

void
xstrtol_fatal (enum strtol_error err,
               int opt_idx, char c, struct option const *long_options,
               char const *arg)
{
  xstrtol_error (err, opt_idx, c, long_options, arg, exit_failure);
  abort ();
}
