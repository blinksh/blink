/* hostname - set or print the name of current host system
   Copyright (C) 1994-2017 Free Software Foundation, Inc.

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

/* Written by Jim Meyering.  */

#include <config.h>
#include <getopt.h>
#include <stdio.h>
#include <sys/types.h>

#include "system.h"
#include "long-options.h"
#include "die.h"
#include "error.h"
#include "quote.h"
#include "xgethostname.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "hostname"

#define AUTHORS proper_name ("Jim Meyering")

#if !defined HAVE_SETHOSTNAME && defined HAVE_SYSINFO && \
     defined HAVE_SYS_SYSTEMINFO_H
# include <sys/systeminfo.h>

static int
sethostname (char *name, size_t namelen)
{
  /* Using sysinfo() is the SVR4 mechanism to set a hostname. */
  return (sysinfo (SI_SET_HOSTNAME, name, namelen) < 0 ? -1 : 0);
}

# define HAVE_SETHOSTNAME 1  /* Now we have it... */
#endif

void
usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("\
Usage: %s [NAME]\n\
  or:  %s OPTION\n\
Print or set the hostname of the current system.\n\
\n\
"),
             program_name, program_name);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}

int
main (int argc, char **argv)
{
  char *hostname;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdout);

  parse_long_options (argc, argv, PROGRAM_NAME, PACKAGE_NAME, Version,
                      usage, AUTHORS, (char const *) NULL);
  if (getopt_long (argc, argv, "", NULL, NULL) != -1)
    usage (EXIT_FAILURE);

  if (argc == optind + 1)
    {
#ifdef HAVE_SETHOSTNAME
      /* Set hostname to operand.  */
      char const *name = argv[optind];
      if (sethostname (name, strlen (name)) != 0)
        die (EXIT_FAILURE, errno, _("cannot set name to %s"),
             quote (name));
#else
      die (EXIT_FAILURE, 0,
           _("cannot set hostname; this system lacks the functionality"));
#endif
    }

  if (argc <= optind)
    {
      hostname = xgethostname ();
      if (hostname == NULL)
        die (EXIT_FAILURE, errno, _("cannot determine hostname"));
      printf ("%s\n", hostname);
    }

  if (optind + 1 < argc)
    {
      error (0, 0, _("extra operand %s"), quote (argv[optind + 1]));
      usage (EXIT_FAILURE);
    }

  return EXIT_SUCCESS;
}
