/* yes - output a string repeatedly until killed
   Copyright (C) 1991-2017 Free Software Foundation, Inc.

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

/* David MacKenzie <djm@gnu.ai.mit.edu> */

#include <config.h>
#include <stdio.h>
#include <sys/types.h>
#include <getopt.h>

#include "system.h"

#include "error.h"
#include "full-write.h"
#include "long-options.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "yes"

#define AUTHORS proper_name ("David MacKenzie")

void
usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("\
Usage: %s [STRING]...\n\
  or:  %s OPTION\n\
"),
              program_name, program_name);

      fputs (_("\
Repeatedly output a line with all specified STRING(s), or 'y'.\n\
\n\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}

int
main (int argc, char **argv)
{
  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdout);

  parse_long_options (argc, argv, PROGRAM_NAME, PACKAGE_NAME, Version,
                      usage, AUTHORS, (char const *) NULL);
  if (getopt_long (argc, argv, "+", NULL, NULL) != -1)
    usage (EXIT_FAILURE);

  char **operands = argv + optind;
  char **operand_lim = argv + argc;
  if (optind == argc)
    *operand_lim++ = bad_cast ("y");

  /* Buffer data locally once, rather than having the
     large overhead of stdio buffering each item.  */
  size_t bufalloc = 0;
  bool reuse_operand_strings = true;
  for (char **operandp = operands; operandp < operand_lim; operandp++)
    {
      size_t operand_len = strlen (*operandp);
      bufalloc += operand_len + 1;
      if (operandp + 1 < operand_lim
          && *operandp + operand_len + 1 != operandp[1])
        reuse_operand_strings = false;
    }

  /* Improve performance by using a buffer size greater than BUFSIZ / 2.  */
  if (bufalloc <= BUFSIZ / 2)
    {
      bufalloc = BUFSIZ;
      reuse_operand_strings = false;
    }

  /* Fill the buffer with one copy of the output.  If possible, reuse
     the operands strings; this wins when the buffer would be large.  */
  char *buf = reuse_operand_strings ? *operands : xmalloc (bufalloc);
  size_t bufused = 0;
  for (char **operandp = operands; operandp < operand_lim; operandp++)
    {
      size_t operand_len = strlen (*operandp);
      if (! reuse_operand_strings)
        memcpy (buf + bufused, *operandp, operand_len);
      bufused += operand_len;
      buf[bufused++] = ' ';
    }
  buf[bufused - 1] = '\n';

  /* If a larger buffer was allocated, fill it by repeating the buffer
     contents.  */
  size_t copysize = bufused;
  for (size_t copies = bufalloc / copysize; --copies; )
    {
      memcpy (buf + bufused, buf, copysize);
      bufused += copysize;
    }

  /* Repeatedly output the buffer until there is a write error; then fail.  */
  while (full_write (STDOUT_FILENO, buf, bufused) == bufused)
    continue;
  error (0, errno, _("standard output"));
  return EXIT_FAILURE;
}
