/* whoami -- print effective userid

   Copyright (C) 1989-2017 Free Software Foundation, Inc.

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

/* Equivalent to 'id -un'. */
/* Written by Richard Mlynarik. */

#include <config.h>
#include <stdio.h>
#include <sys/types.h>
#include <pwd.h>
#include <getopt.h>

#include "system.h"
#include "die.h"
#include "error.h"
#include "long-options.h"
#include "quote.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "whoami"
#undef usage
#define usage whoami_usage
static void whoami_usage (int status);

#define AUTHORS proper_name ("Richard Mlynarik")

void
whoami_usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("Usage: %s [OPTION]...\n\r"), program_name);
      fputs (_("\
Print the user name associated with the current effective user ID.\n\r\
Same as id -un.\n\r\
\n\r\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      emit_ancillary_info (PROGRAM_NAME);
    }
  // exit (status);
}

int
whoami_main (int argc, char **argv)
{
  struct passwd *pw;
  uid_t uid;
  uid_t NO_UID = -1;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdout);

  parse_long_options (argc, argv, PROGRAM_NAME, PACKAGE_NAME, Version,
                      usage, AUTHORS, (char const *) NULL);
    if (getopt_long (argc, argv, "", NULL, NULL) != -1) {
        usage (EXIT_FAILURE);
        return (EXIT_FAILURE);
    }

  if (optind != argc)
    {
      error (0, 0, _("extra operand %s"), quote (argv[optind]));
      usage (EXIT_FAILURE);
      return (EXIT_FAILURE);
    }

  errno = 0;
  uid = geteuid ();
  pw = (uid == NO_UID && errno ? NULL : getpwuid (uid));
  if (!pw)
    die (EXIT_FAILURE, errno, _("cannot find name for user ID %lu"),
         (unsigned long int) uid);
  puts (pw->pw_name);
  puts ("\r");
  return EXIT_SUCCESS;
}
