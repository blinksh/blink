/* mknod -- make special files
   Copyright (C) 1990-2017 Free Software Foundation, Inc.

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

/* Written by David MacKenzie <djm@ai.mit.edu>  */

#include <config.h>
#include <stdio.h>
#include <getopt.h>
#include <sys/types.h>
#include <selinux/selinux.h>

#include "system.h"
#include "die.h"
#include "error.h"
#include "modechange.h"
#include "quote.h"
#include "selinux.h"
#include "smack.h"
#include "xstrtol.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "mknod"

#define AUTHORS proper_name ("David MacKenzie")

static struct option const longopts[] =
{
  {GETOPT_SELINUX_CONTEXT_OPTION_DECL},
  {"mode", required_argument, NULL, 'm'},
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
      printf (_("Usage: %s [OPTION]... NAME TYPE [MAJOR MINOR]\n"),
              program_name);
      fputs (_("\
Create the special file NAME of the given TYPE.\n\
"), stdout);

      emit_mandatory_arg_note ();

      fputs (_("\
  -m, --mode=MODE    set file permission bits to MODE, not a=rw - umask\n\
"), stdout);
      fputs (_("\
  -Z                   set the SELinux security context to default type\n\
      --context[=CTX]  like -Z, or if CTX is specified then set the SELinux\n\
                         or SMACK security context to CTX\n\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      fputs (_("\
\n\
Both MAJOR and MINOR must be specified when TYPE is b, c, or u, and they\n\
must be omitted when TYPE is p.  If MAJOR or MINOR begins with 0x or 0X,\n\
it is interpreted as hexadecimal; otherwise, if it begins with 0, as octal;\n\
otherwise, as decimal.  TYPE may be:\n\
"), stdout);
      fputs (_("\
\n\
  b      create a block (buffered) special file\n\
  c, u   create a character (unbuffered) special file\n\
  p      create a FIFO\n\
"), stdout);
      printf (USAGE_BUILTIN_WARNING, PROGRAM_NAME);
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}

int
main (int argc, char **argv)
{
  mode_t newmode;
  char const *specified_mode = NULL;
  int optc;
  size_t expected_operands;
  mode_t node_type;
  char const *scontext = NULL;
  bool set_security_context = false;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdout);

  while ((optc = getopt_long (argc, argv, "m:Z", longopts, NULL)) != -1)
    {
      switch (optc)
        {
        case 'm':
          specified_mode = optarg;
          break;
        case 'Z':
          if (is_smack_enabled ())
            {
              /* We don't yet support -Z to restore context with SMACK.  */
              scontext = optarg;
            }
          else if (is_selinux_enabled () > 0)
            {
              if (optarg)
                scontext = optarg;
              else
                set_security_context = true;
            }
          else if (optarg)
            {
              error (0, 0,
                     _("warning: ignoring --context; "
                       "it requires an SELinux/SMACK-enabled kernel"));
            }
          break;
        case_GETOPT_HELP_CHAR;
        case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);
        default:
          usage (EXIT_FAILURE);
        }
    }

  newmode = MODE_RW_UGO;
  if (specified_mode)
    {
      mode_t umask_value;
      struct mode_change *change = mode_compile (specified_mode);
      if (!change)
        die (EXIT_FAILURE, 0, _("invalid mode"));
      umask_value = umask (0);
      umask (umask_value);
      newmode = mode_adjust (newmode, false, umask_value, change, NULL);
      free (change);
      if (newmode & ~S_IRWXUGO)
        die (EXIT_FAILURE, 0,
             _("mode must specify only file permission bits"));
    }

  /* If the number of arguments is 0 or 1,
     or (if it's 2 or more and the second one starts with 'p'), then there
     must be exactly two operands.  Otherwise, there must be four.  */
  expected_operands = (argc <= optind
                       || (optind + 1 < argc && argv[optind + 1][0] == 'p')
                       ? 2 : 4);

  if (argc - optind < expected_operands)
    {
      if (argc <= optind)
        error (0, 0, _("missing operand"));
      else
        error (0, 0, _("missing operand after %s"), quote (argv[argc - 1]));
      if (expected_operands == 4 && argc - optind == 2)
        fprintf (stderr, "%s\n",
                 _("Special files require major and minor device numbers."));
      usage (EXIT_FAILURE);
    }

  if (expected_operands < argc - optind)
    {
      error (0, 0, _("extra operand %s"),
             quote (argv[optind + expected_operands]));
      if (expected_operands == 2 && argc - optind == 4)
        fprintf (stderr, "%s\n",
                 _("Fifos do not have major and minor device numbers."));
      usage (EXIT_FAILURE);
    }

  if (scontext)
    {
      int ret = 0;
      if (is_smack_enabled ())
        ret = smack_set_label_for_self (scontext);
      else
        ret = setfscreatecon (se_const (scontext));

      if (ret < 0)
        die (EXIT_FAILURE, errno,
             _("failed to set default file creation context to %s"),
             quote (scontext));
    }

  /* Only check the first character, to allow mnemonic usage like
     'mknod /dev/rst0 character 18 0'. */

  switch (argv[optind + 1][0])
    {
    case 'b':			/* 'block' or 'buffered' */
#ifndef S_IFBLK
      die (EXIT_FAILURE, 0, _("block special files not supported"));
#else
      node_type = S_IFBLK;
#endif
      goto block_or_character;

    case 'c':			/* 'character' */
    case 'u':			/* 'unbuffered' */
#ifndef S_IFCHR
      die (EXIT_FAILURE, 0, _("character special files not supported"));
#else
      node_type = S_IFCHR;
#endif
      goto block_or_character;

    block_or_character:
      {
        char const *s_major = argv[optind + 2];
        char const *s_minor = argv[optind + 3];
        uintmax_t i_major, i_minor;
        dev_t device;

        if (xstrtoumax (s_major, NULL, 0, &i_major, NULL) != LONGINT_OK
            || i_major != (major_t) i_major)
          die (EXIT_FAILURE, 0,
               _("invalid major device number %s"), quote (s_major));

        if (xstrtoumax (s_minor, NULL, 0, &i_minor, NULL) != LONGINT_OK
            || i_minor != (minor_t) i_minor)
          die (EXIT_FAILURE, 0,
               _("invalid minor device number %s"), quote (s_minor));

        device = makedev (i_major, i_minor);
#ifdef NODEV
        if (device == NODEV)
          die (EXIT_FAILURE, 0, _("invalid device %s %s"),
               s_major, s_minor);
#endif

        if (set_security_context)
          defaultcon (argv[optind], node_type);

        if (mknod (argv[optind], newmode | node_type, device) != 0)
          die (EXIT_FAILURE, errno, "%s", quotef (argv[optind]));
      }
      break;

    case 'p':			/* 'pipe' */
      if (set_security_context)
        defaultcon (argv[optind], S_IFIFO);
      if (mkfifo (argv[optind], newmode) != 0)
        die (EXIT_FAILURE, errno, "%s", quotef (argv[optind]));
      break;

    default:
      error (0, 0, _("invalid device type %s"), quote (argv[optind + 1]));
      usage (EXIT_FAILURE);
    }

  if (specified_mode && lchmod (argv[optind], newmode) != 0)
    die (EXIT_FAILURE, errno, _("cannot set permissions of %s"),
         quoteaf (argv[optind]));

  return EXIT_SUCCESS;
}
