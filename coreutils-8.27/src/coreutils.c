/* Copyright (C) 2014-2017 Free Software Foundation, Inc.

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

/* coreutils.c aggregates the functionality of every other tool into a single
   binary multiplexed by the value of argv[0]. This is enabled by passing
   --enable-single-binary to configure.

   Written by Alex Deymo <deymo@chromium.org>.  */

#include <config.h>
#include <getopt.h>
#include <stdio.h>
#if HAVE_PRCTL
# include <sys/prctl.h>
#endif

#include "system.h"
#include "die.h"
#include "error.h"
#include "quote.h"

#ifdef SINGLE_BINARY
/* Declare the main function on each one of the selected tools.  This name
   needs to match the one passed as CFLAGS on single-binary.mk (generated
   by gen-single-binary.sh). */
# define SINGLE_BINARY_PROGRAM(prog_name_str, main_name) \
  int single_binary_main_##main_name (int, char **);
# include "coreutils.h"
# undef SINGLE_BINARY_PROGRAM
#endif

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "coreutils"

#define AUTHORS \
  proper_name ("Alex Deymo")

static struct option const long_options[] =
{
  {GETOPT_HELP_OPTION_DECL},
  {GETOPT_VERSION_OPTION_DECL},
  {NULL, 0, NULL, 0}
};


void
usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("\
Usage: %s --coreutils-prog=PROGRAM_NAME [PARAMETERS]... \n"),
              program_name);
      fputs (_("\
Execute the PROGRAM_NAME built-in program with the given PARAMETERS.\n\
\n"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);

#ifdef SINGLE_BINARY
/* XXX: Ideally we'd like to present "install" here, not "ginstall".  */
      char const *prog_name_list =
# define SINGLE_BINARY_PROGRAM(prog_name_str, main_name) " " prog_name_str
# include "coreutils.h"
# undef SINGLE_BINARY_PROGRAM
      ;
      printf ("\n\
Built-in programs:\n\
%s\n", prog_name_list);
#endif

      printf (_("\
\n\
Use: '%s --coreutils-prog=PROGRAM_NAME --help' for individual program help.\n"),
              program_name);
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}

static void
launch_program (const char *prog_name, int prog_argc, char **prog_argv)
{
  int (*prog_main) (int, char **) = NULL;

  /* Ensure that at least one parameter was passed.  */
  if (!prog_argc || !prog_argv || !prog_argv[0] || !prog_name)
    return;

#ifdef SINGLE_BINARY
  if (false);
  /* Look up the right main program.  */
# define SINGLE_BINARY_PROGRAM(prog_name_str, main_name) \
  else if (STREQ (prog_name_str, prog_name)) \
    prog_main = single_binary_main_##main_name;
# include "coreutils.h"
# undef SINGLE_BINARY_PROGRAM
#endif

  if (! prog_main)
    return;

#if HAVE_PRCTL && defined PR_SET_NAME
  /* Not being able to set the program name is not a fatal error.  */
  prctl (PR_SET_NAME, prog_argv[0]);
#endif
#if HAVE_PRCTL && defined PR_SET_MM_ARG_START
  /* Shift the beginning of the command line to prog_argv[0] (if set) so
     /proc/pid/cmdline reflects the right value.  */
  prctl (PR_SET_MM_ARG_START, prog_argv[0]);
#endif

  exit (prog_main (prog_argc, prog_argv));
}

int
main (int argc, char **argv)
{
  char *prog_name = last_component (argv[0]);
  int optc;

  /* Map external name to internal name.  */
  char ginstall[] = "ginstall";
  if (STREQ (prog_name, "install"))
    prog_name = ginstall;

  /* If this program is called directly as "coreutils" or if the value of
     argv[0] is an unknown tool (which "coreutils" is), we proceed and parse
     the options.  */
  launch_program (prog_name, argc, argv);

  /* No known program was selected via argv[0].  Try parsing the first
     argument as --coreutils-prog=PROGRAM to determine the program.  The
     invocation for this case should be:
       path/to/coreutils --coreutils-prog=someprog someprog ...
     The third argument is what the program will see as argv[0].  */

  if (argc >= 2)
    {
      size_t nskip = 0;
      char *arg_name = NULL;

      /* If calling coreutils directly, the "script" name isn't passed.
         Distinguish the two cases with a -shebang suffix.  */
      if (STRPREFIX (argv[1], "--coreutils-prog="))
        {
          nskip = 1;
          arg_name = prog_name = argv[1] + strlen ("--coreutils-prog=");
        }
      else if (STRPREFIX (argv[1], "--coreutils-prog-shebang="))
        {
          nskip = 2;
          prog_name = argv[1] + strlen ("--coreutils-prog-shebang=");
          if (argc >= 3)
            arg_name = last_component (argv[2]);
          else
            arg_name = prog_name;
        }

      if (nskip)
        {
          argv[nskip] = arg_name; /* XXX: Discards any specified path.  */
          launch_program (prog_name, argc - nskip, argv + nskip);
          die (EXIT_FAILURE, 0, _("unknown program %s"),
               quote (prog_name));
        }
    }

  /* No known program was selected.  From here on, we behave like any other
     coreutils program.  */
  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);
  atexit (close_stdout);

  if ((optc = getopt_long (argc, argv, "", long_options, NULL)) != -1)
    switch (optc)
      {
      case_GETOPT_HELP_CHAR;

      case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);
      }

  /* Only print the error message when no options have been passed
     to coreutils.  */
  if (optind == 1 && prog_name && !STREQ (prog_name, "coreutils"))
    error (0, 0, _("unknown program %s"),
           quote (prog_name));

  usage (EXIT_FAILURE);
}
