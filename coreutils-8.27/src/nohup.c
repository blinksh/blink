/* nohup -- run a command immune to hangups, with output to a non-tty
   Copyright (C) 2003-2017 Free Software Foundation, Inc.

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

/* Written by Jim Meyering  */

#include <config.h>
#include <getopt.h>
#include <stdio.h>
#include <sys/types.h>
#include <signal.h>

#include "system.h"

#include "cloexec.h"
#include "error.h"
#include "filenamecat.h"
#include "fd-reopen.h"
#include "long-options.h"
#include "unistd--.h"

#define PROGRAM_NAME "nohup"

#define AUTHORS proper_name ("Jim Meyering")

/* Exit statuses.  */
enum
  {
    /* 'nohup' itself failed.  */
    POSIX_NOHUP_FAILURE = 127
  };

void
usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("\
Usage: %s COMMAND [ARG]...\n\
  or:  %s OPTION\n\
"),
              program_name, program_name);

      fputs (_("\
Run COMMAND, ignoring hangup signals.\n\
\n\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      printf (_("\n\
If standard input is a terminal, redirect it from an unreadable file.\n\
If standard output is a terminal, append output to 'nohup.out' if possible,\n\
'$HOME/nohup.out' otherwise.\n\
If standard error is a terminal, redirect it to standard output.\n\
To save output to FILE, use '%s COMMAND > FILE'.\n"),
              program_name);
      printf (USAGE_BUILTIN_WARNING, PROGRAM_NAME);
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}

int
main (int argc, char **argv)
{
  int out_fd = STDOUT_FILENO;
  int saved_stderr_fd = STDERR_FILENO;
  bool ignoring_input;
  bool redirecting_stdout;
  bool stdout_is_closed;
  bool redirecting_stderr;
  int exit_internal_failure;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  /* POSIX 2008 requires that internal failure give status 127; unlike
     for env, exec, nice, time, and xargs where it requires internal
     failure give something in the range 1-125.  For consistency with
     other tools, fail with EXIT_CANCELED unless POSIXLY_CORRECT.  */
  exit_internal_failure = (getenv ("POSIXLY_CORRECT")
                           ? POSIX_NOHUP_FAILURE : EXIT_CANCELED);
  initialize_exit_failure (exit_internal_failure);
  atexit (close_stdout);

  parse_long_options (argc, argv, PROGRAM_NAME, PACKAGE_NAME, Version,
                      usage, AUTHORS, (char const *) NULL);
  if (getopt_long (argc, argv, "+", NULL, NULL) != -1)
    usage (exit_internal_failure);

  if (argc <= optind)
    {
      error (0, 0, _("missing operand"));
      usage (exit_internal_failure);
    }

  ignoring_input = isatty (STDIN_FILENO);
  redirecting_stdout = isatty (STDOUT_FILENO);
  stdout_is_closed = (!redirecting_stdout && errno == EBADF);
  redirecting_stderr = isatty (STDERR_FILENO);

  /* If standard input is a tty, replace it with /dev/null if possible.
     Note that it is deliberately opened for *writing*,
     to ensure any read evokes an error.  */
  if (ignoring_input)
    {
      if (fd_reopen (STDIN_FILENO, "/dev/null", O_WRONLY, 0) < 0)
        error (exit_internal_failure, errno,
               _("failed to render standard input unusable"));
      if (!redirecting_stdout && !redirecting_stderr)
        error (0, 0, _("ignoring input"));
    }

  /* If standard output is a tty, redirect it (appending) to a file.
     First try nohup.out, then $HOME/nohup.out.  If standard error is
     a tty and standard output is closed, open nohup.out or
     $HOME/nohup.out without redirecting anything.  */
  if (redirecting_stdout || (redirecting_stderr && stdout_is_closed))
    {
      char *in_home = NULL;
      char const *file = "nohup.out";
      int flags = O_CREAT | O_WRONLY | O_APPEND;
      mode_t mode = S_IRUSR | S_IWUSR;
      mode_t umask_value = umask (~mode);
      out_fd = (redirecting_stdout
                ? fd_reopen (STDOUT_FILENO, file, flags, mode)
                : open (file, flags, mode));

      if (out_fd < 0)
        {
          int saved_errno = errno;
          char const *home = getenv ("HOME");
          if (home)
            {
              in_home = file_name_concat (home, file, NULL);
              out_fd = (redirecting_stdout
                        ? fd_reopen (STDOUT_FILENO, in_home, flags, mode)
                        : open (in_home, flags, mode));
            }
          if (out_fd < 0)
            {
              int saved_errno2 = errno;
              error (0, saved_errno, _("failed to open %s"), quoteaf (file));
              if (in_home)
                error (0, saved_errno2, _("failed to open %s"),
                       quoteaf (in_home));
              return exit_internal_failure;
            }
          file = in_home;
        }

      umask (umask_value);
      error (0, 0,
             _(ignoring_input
               ? N_("ignoring input and appending output to %s")
               : N_("appending output to %s")),
             quoteaf (file));
      free (in_home);
    }

  /* If standard error is a tty, redirect it.  */
  if (redirecting_stderr)
    {
      /* Save a copy of stderr before redirecting, so we can use the original
         if execve fails.  It's no big deal if this dup fails.  It might
         not change anything, and at worst, it'll lead to suppression of
         the post-failed-execve diagnostic.  */
      saved_stderr_fd = dup (STDERR_FILENO);

      if (0 <= saved_stderr_fd
          && set_cloexec_flag (saved_stderr_fd, true) != 0)
        error (exit_internal_failure, errno,
               _("failed to set the copy of stderr to close on exec"));

      if (!redirecting_stdout)
        error (0, 0,
               _(ignoring_input
                 ? N_("ignoring input and redirecting stderr to stdout")
                 : N_("redirecting stderr to stdout")));

      if (dup2 (out_fd, STDERR_FILENO) < 0)
        error (exit_internal_failure, errno,
               _("failed to redirect standard error"));

      if (stdout_is_closed)
        close (out_fd);
    }

  /* error() flushes stderr, but does not check for write failure.
     Normally, we would catch this via our atexit() hook of
     close_stdout, but execvp() gets in the way.  If stderr
     encountered a write failure, there is no need to try calling
     error() again, particularly since we may have just changed the
     underlying fd out from under stderr.  */
  if (ferror (stderr))
    return exit_internal_failure;

  signal (SIGHUP, SIG_IGN);

  char **cmd = argv + optind;
  execvp (*cmd, cmd);
  int exit_status = errno == ENOENT ? EXIT_ENOENT : EXIT_CANNOT_INVOKE;
  int saved_errno = errno;

  /* The execve failed.  Output a diagnostic to stderr only if:
     - stderr was initially redirected to a non-tty, or
     - stderr was initially directed to a tty, and we
     can dup2 it to point back to that same tty.
     In other words, output the diagnostic if possible, but only if
     it will go to the original stderr.  */
  if (dup2 (saved_stderr_fd, STDERR_FILENO) == STDERR_FILENO)
    error (0, saved_errno, _("failed to run command %s"), quoteaf (*cmd));

  return exit_status;
}
