/* sync - update the super block
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

/* Written by Jim Meyering */

#include <config.h>
#include <assert.h>
#include <getopt.h>
#include <stdio.h>
#include <sys/types.h>

#include "system.h"
#include "die.h"
#include "error.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "sync"

#define AUTHORS                                 \
  proper_name ("Jim Meyering"),                 \
  proper_name ("Giuseppe Scrivano")

#ifndef HAVE_SYNCFS
# define HAVE_SYNCFS 0
#endif

enum sync_mode
{
  MODE_FILE,
  MODE_DATA,
  MODE_FILE_SYSTEM,
  MODE_SYNC
};

static struct option const long_options[] =
{
  {"data", no_argument, NULL, 'd'},
  {"file-system", no_argument, NULL, 'f'},
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
      printf (_("Usage: %s [OPTION] [FILE]...\n"), program_name);
      fputs (_("\
Synchronize cached writes to persistent storage\n\
\n\
If one or more files are specified, sync only them,\n\
or their containing file systems.\n\
\n\
"), stdout);

      fputs (_("\
  -d, --data             sync only file data, no unneeded metadata\n\
"), stdout);
      fputs (_("\
  -f, --file-system      sync the file systems that contain the files\n\
"), stdout);

      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}

/* Sync the specified FILE, or file systems associated with FILE.
   Return 1 on success.  */

static bool
sync_arg (enum sync_mode mode, char const *file)
{
  bool ret = true;
  int open_flags = O_RDONLY | O_NONBLOCK;
  int fd;

#ifdef _AIX
  /* AIX 7.1 fsync requires write access to file.  */
  if (mode == MODE_FILE)
    open_flags = O_WRONLY | O_NONBLOCK;
#endif

  /* Note O_PATH might be supported with syncfs(),
     though as of Linux 3.18 is not.  */
  fd = open (file, open_flags);
  if (fd < 0)
    {
      /* Use the O_RDONLY errno, which is significant
         with directories for example.  */
      int rd_errno = errno;
      if (open_flags != (O_WRONLY | O_NONBLOCK))
        fd = open (file, O_WRONLY | O_NONBLOCK);
      if (fd < 0)
        error (0, rd_errno, _("error opening %s"), quoteaf (file));
      return false;
    }

  /* We used O_NONBLOCK above to not hang with fifos,
     so reset that here.  */
  int fdflags = fcntl (fd, F_GETFL);
  if (fdflags == -1
      || fcntl (fd, F_SETFL, fdflags & ~O_NONBLOCK) < 0)
    {
      error (0, errno, _("couldn't reset non-blocking mode %s"),
             quoteaf (file));
      ret = false;
    }

  if (ret == true)
    {
      int sync_status = -1;

      switch (mode)
        {
        case MODE_DATA:
          sync_status = fdatasync (fd);
          break;

        case MODE_FILE:
          sync_status = fsync (fd);
          break;

#if HAVE_SYNCFS
        case MODE_FILE_SYSTEM:
          sync_status = syncfs (fd);
          break;
#endif

        default:
          assert ("invalid sync_mode");
        }

      if (sync_status < 0)
        {
          error (0, errno, _("error syncing %s"), quoteaf (file));
          ret = false;
        }
    }

  if (close (fd) < 0)
    {
      error (0, errno, _("failed to close %s"), quoteaf (file));
      ret = false;
    }

  return ret;
}

int
main (int argc, char **argv)
{
  int c;
  bool args_specified;
  bool arg_data = false, arg_file_system = false;
  enum sync_mode mode;
  bool ok = true;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdout);

  while ((c = getopt_long (argc, argv, "df", long_options, NULL))
         != -1)
    {
      switch (c)
        {
        case 'd':
          arg_data = true;
          break;

        case 'f':
          arg_file_system = true;
          break;

        case_GETOPT_HELP_CHAR;

        case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);

        default:
          usage (EXIT_FAILURE);
        }
    }

  args_specified = optind < argc;

  if (arg_data && arg_file_system)
    {
      die (EXIT_FAILURE, 0,
           _("cannot specify both --data and --file-system"));
    }

  if (!args_specified && arg_data)
    die (EXIT_FAILURE, 0, _("--data needs at least one argument"));

  if (! args_specified || (arg_file_system && ! HAVE_SYNCFS))
    mode = MODE_SYNC;
  else if (arg_file_system)
    mode = MODE_FILE_SYSTEM;
  else if (! arg_data)
    mode = MODE_FILE;
  else
    mode = MODE_DATA;

  if (mode == MODE_SYNC)
    sync ();
  else
    {
      for (; optind < argc; optind++)
        ok &= sync_arg (mode, argv[optind]);
    }

  return ok ? EXIT_SUCCESS : EXIT_FAILURE;
}
