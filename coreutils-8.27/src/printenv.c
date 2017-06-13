/* printenv -- print all or part of environment
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

/* Usage: printenv [variable...]

   If no arguments are given, print the entire environment.
   If one or more variable names are given, print the value of
   each one that is set, and nothing for ones that are not set.

   Exit status:
   0 if all variables specified were found
   1 if not
   2 if some other error occurred

   David MacKenzie and Richard Mlynarik */

#include <config.h>
#include <stdio.h>
#include <sys/types.h>
#include <getopt.h>

#include "system.h"

/* Exit status for syntax errors, etc.  */
enum { PRINTENV_FAILURE = 2 };

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "printenv"

#undef usage
#define usage printenv_usage
static void printenv_usage (int status);


#define AUTHORS \
  proper_name ("David MacKenzie"), \
  proper_name ("Richard Mlynarik")

static struct option const longopts[] =
{
  {"null", no_argument, NULL, '0'},
  {GETOPT_HELP_OPTION_DECL},
  {GETOPT_VERSION_OPTION_DECL},
  {NULL, 0, NULL, 0}
};

void
printenv_usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("\
Usage: %s [OPTION]... [VARIABLE]...\n\r\
Print the values of the specified environment VARIABLE(s).\n\r\
If no VARIABLE is specified, print name and value pairs for them all.\n\r\
\n\r\
"),
              program_name);
      fputs (_("\
  -0, --null     end each output line with NUL, not newline\n\r\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      printf (USAGE_BUILTIN_WARNING, PROGRAM_NAME);
      emit_ancillary_info (PROGRAM_NAME);
    }
  // exit (status);
}

int
printenv_main (int argc, char **argv)
{
  char **env;
  char *ep, *ap;
  int i;
  bool ok;
  int optc;
  bool opt_nul_terminate_output = false;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  initialize_exit_failure (PRINTENV_FAILURE);
  atexit (close_stdout);

  while ((optc = getopt_long (argc, argv, "+iu:0", longopts, NULL)) != -1)
    {
      switch (optc)
        {
        case '0':
          opt_nul_terminate_output = true;
          break;
        case_GETOPT_HELP_CHAR;
        case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);
        default:
          printenv_usage (PRINTENV_FAILURE);
          return PRINTENV_FAILURE;
        }
    }

  if (optind >= argc)
    {
        for (env = environ; *env != NULL; ++env)
            if (opt_nul_terminate_output)
                printf ("%s%c", *env, '\0');
            else
                printf ("%s\n\r", *env);
      ok = true;
    }
  else
    {
      int matches = 0;

      for (i = optind; i < argc; ++i)
        {
          bool matched = false;

          /* 'printenv a=b' is silent, even if 'a=b=c' is in environ.  */
          if (strchr (argv[i], '='))
            continue;

          for (env = environ; *env; ++env)
            {
              ep = *env;
              ap = argv[i];
              while (*ep != '\0' && *ap != '\0' && *ep++ == *ap++)
                {
                    if (*ep == '=' && *ap == '\0')
                    {
                        if (opt_nul_terminate_output)
                            printf ("%s%c", ep + 1, '\0');
                        else
                            printf ("%s\n\r", ep + 1);
                        matched = true;
                        break;
                    }
                }
            }

          matches += matched;
        }

      ok = (matches == argc - optind);
    }

  return ok ? EXIT_SUCCESS : EXIT_FAILURE;
}
