/* kill -- send a signal to a process
   Copyright (C) 2002-2017 Free Software Foundation, Inc.

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

/* Written by Paul Eggert.  */

#include <config.h>
#include <stdio.h>
#include <getopt.h>
#include <sys/types.h>
#include <signal.h>

#include "system.h"
#include "error.h"
#include "sig2str.h"
#include "operand2sig.h"
#include "quote.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "kill"

#define AUTHORS proper_name ("Paul Eggert")

#if ! (HAVE_DECL_STRSIGNAL || defined strsignal)
# if ! (HAVE_DECL_SYS_SIGLIST || defined sys_siglist)
#  if HAVE_DECL__SYS_SIGLIST || defined _sys_siglist
#   define sys_siglist _sys_siglist
#  elif HAVE_DECL___SYS_SIGLIST || defined __sys_siglist
#   define sys_siglist __sys_siglist
#  endif
# endif
# if HAVE_DECL_SYS_SIGLIST || defined sys_siglist
#  define strsignal(signum) (0 <= (signum) && (signum) <= SIGNUM_BOUND \
                             ? sys_siglist[signum] \
                             : 0)
# endif
# ifndef strsignal
#  define strsignal(signum) 0
# endif
#endif

static char const short_options[] =
  "0::1::2::3::4::5::6::7::8::9::"
  "A::B::C::D::E::F::G::H::I::J::K::M::"
  "N::O::P::Q::R::S::T::U::V::W::X::Y::Z::"
  "Lln:s:t";

static struct option const long_options[] =
{
  {"list", no_argument, NULL, 'l'},
  {"signal", required_argument, NULL, 's'},
  {"table", no_argument, NULL, 't'},
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
Usage: %s [-s SIGNAL | -SIGNAL] PID...\n\
  or:  %s -l [SIGNAL]...\n\
  or:  %s -t [SIGNAL]...\n\
"),
              program_name, program_name, program_name);
      fputs (_("\
Send signals to processes, or list signals.\n\
"), stdout);

      emit_mandatory_arg_note ();

      fputs (_("\
  -s, --signal=SIGNAL, -SIGNAL\n\
                   specify the name or number of the signal to be sent\n\
  -l, --list       list signal names, or convert signal names to/from numbers\n\
  -t, --table      print a table of signal information\n\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      fputs (_("\n\
SIGNAL may be a signal name like 'HUP', or a signal number like '1',\n\
or the exit status of a process terminated by a signal.\n\
PID is an integer; if negative it identifies a process group.\n\
"), stdout);
      printf (USAGE_BUILTIN_WARNING, PROGRAM_NAME);
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}

/* Print a row of 'kill -t' output.  NUM_WIDTH is the maximum signal
   number width, and SIGNUM is the signal number to print.  The
   maximum name width is NAME_WIDTH, and SIGNAME is the name to print.  */

static void
print_table_row (int num_width, int signum,
                 int name_width, char const *signame)
{
  char const *description = strsignal (signum);
  printf ("%*d %-*s %s\n", num_width, signum, name_width, signame,
          description ? description : "?");
}

/* Print a list of signal names.  If TABLE, print a table.
   Print the names specified by ARGV if nonzero; otherwise,
   print all known names.  Return a suitable exit status.  */

static int
list_signals (bool table, char *const *argv)
{
  int signum;
  int status = EXIT_SUCCESS;
  char signame[SIG2STR_MAX];

  if (table)
    {
      unsigned int name_width = 0;

      /* Compute the maximum width of a signal number.  */
      unsigned int num_width = 1;
      for (signum = 1; signum <= SIGNUM_BOUND / 10; signum *= 10)
        num_width++;

      /* Compute the maximum width of a signal name.  */
      for (signum = 1; signum <= SIGNUM_BOUND; signum++)
        if (sig2str (signum, signame) == 0)
          {
            size_t len = strlen (signame);
            if (name_width < len)
              name_width = len;
          }

      if (argv)
        for (; *argv; argv++)
          {
            signum = operand2sig (*argv, signame);
            if (signum < 0)
              status = EXIT_FAILURE;
            else
              print_table_row (num_width, signum, name_width, signame);
          }
      else
        for (signum = 1; signum <= SIGNUM_BOUND; signum++)
          if (sig2str (signum, signame) == 0)
            print_table_row (num_width, signum, name_width, signame);
    }
  else
    {
      if (argv)
        for (; *argv; argv++)
          {
            signum = operand2sig (*argv, signame);
            if (signum < 0)
              status = EXIT_FAILURE;
            else
              {
                if (ISDIGIT (**argv))
                  puts (signame);
                else
                  printf ("%d\n", signum);
              }
          }
      else
        for (signum = 1; signum <= SIGNUM_BOUND; signum++)
          if (sig2str (signum, signame) == 0)
            puts (signame);
    }

  return status;
}

/* Send signal SIGNUM to all the processes or process groups specified
   by ARGV.  Return a suitable exit status.  */

static int
send_signals (int signum, char *const *argv)
{
  int status = EXIT_SUCCESS;
  char const *arg = *argv;

  do
    {
      char *endp;
      intmax_t n = (errno = 0, strtoimax (arg, &endp, 10));
      pid_t pid = n;

      if (errno == ERANGE || pid != n || arg == endp || *endp)
        {
          error (0, 0, _("%s: invalid process id"), quote (arg));
          status = EXIT_FAILURE;
        }
      else if (kill (pid, signum) != 0)
        {
          error (0, errno, "%s", quote (arg));
          status = EXIT_FAILURE;
        }
    }
  while ((arg = *++argv));

  return status;
}

int
main (int argc, char **argv)
{
  int optc;
  bool list = false;
  bool table = false;
  int signum = -1;
  char signame[SIG2STR_MAX];

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdout);

  while ((optc = getopt_long (argc, argv, short_options, long_options, NULL))
         != -1)
    switch (optc)
      {
      case '0': case '1': case '2': case '3': case '4':
      case '5': case '6': case '7': case '8': case '9':
        if (optind != 2)
          {
            /* This option is actually a process-id.  */
            optind--;
            goto no_more_options;
          }
        /* Fall through.  */
      case 'A': case 'B': case 'C': case 'D': case 'E':
      case 'F': case 'G': case 'H': case 'I': case 'J':
      case 'K': /*case 'L':*/ case 'M': case 'N': case 'O':
      case 'P': case 'Q': case 'R': case 'S': case 'T':
      case 'U': case 'V': case 'W': case 'X': case 'Y':
      case 'Z':
        if (! optarg)
          optarg = argv[optind - 1] + strlen (argv[optind - 1]);
        if (optarg != argv[optind - 1] + 2)
          {
            error (0, 0, _("invalid option -- %c"), optc);
            usage (EXIT_FAILURE);
          }
        optarg--;
        /* Fall through.  */
      case 'n': /* -n is not documented, but is for Bash compatibility.  */
      case 's':
        if (0 <= signum)
          {
            error (0, 0, _("%s: multiple signals specified"), quote (optarg));
            usage (EXIT_FAILURE);
          }
        signum = operand2sig (optarg, signame);
        if (signum < 0)
          usage (EXIT_FAILURE);
        break;

      case 'L': /* -L is not documented, but is for procps compatibility.  */
      case 't':
        table = true;
        /* Fall through.  */
      case 'l':
        if (list)
          {
            error (0, 0, _("multiple -l or -t options specified"));
            usage (EXIT_FAILURE);
          }
        list = true;
        break;

      case_GETOPT_HELP_CHAR;
      case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);
      default:
        usage (EXIT_FAILURE);
      }
 no_more_options:

  if (signum < 0)
    signum = SIGTERM;
  else if (list)
    {
      error (0, 0, _("cannot combine signal with -l or -t"));
      usage (EXIT_FAILURE);
    }

  if ( ! list && argc <= optind)
    {
      error (0, 0, _("no process ID specified"));
      usage (EXIT_FAILURE);
    }

  return (list
          ? list_signals (table, optind < argc ? argv + optind : NULL)
          : send_signals (signum, argv + optind));
}
