/* comm -- compare two sorted files line by line.
   Copyright (C) 1986-2017 Free Software Foundation, Inc.

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

/* Written by Richard Stallman and David MacKenzie. */

#include <config.h>

#include <getopt.h>
#include <sys/types.h>
#include "system.h"
#include "linebuffer.h"
#include "die.h"
#include "error.h"
#include "fadvise.h"
#include "hard-locale.h"
#include "quote.h"
#include "stdio--.h"
#include "memcmp2.h"
#include "xmemcoll.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "comm"

#define AUTHORS \
  proper_name ("Richard M. Stallman"), \
  proper_name ("David MacKenzie")

/* Undefine, to avoid warning about redefinition on some systems.  */
#undef min
#define min(x, y) ((x) < (y) ? (x) : (y))

/* True if the LC_COLLATE locale is hard.  */
static bool hard_LC_COLLATE;

/* If true, print lines that are found only in file 1. */
static bool only_file_1;

/* If true, print lines that are found only in file 2. */
static bool only_file_2;

/* If true, print lines that are found in both files. */
static bool both;

/* If nonzero, we have seen at least one unpairable line. */
static bool seen_unpairable;

/* If nonzero, we have warned about disorder in that file. */
static bool issued_disorder_warning[2];

/* line delimiter.  */
static unsigned char delim = '\n';

/* If true, print a summary.  */
static bool total_option;

/* If nonzero, check that the input is correctly ordered. */
static enum
  {
    CHECK_ORDER_DEFAULT,
    CHECK_ORDER_ENABLED,
    CHECK_ORDER_DISABLED
  } check_input_order;

/* Output columns will be delimited with this string, which may be set
   on the command-line with --output-delimiter=STR.  */
static char const *col_sep = "\t";
static size_t col_sep_len = 0;

/* For long options that have no equivalent short option, use a
   non-character as a pseudo short option, starting with CHAR_MAX + 1.  */
enum
{
  CHECK_ORDER_OPTION = CHAR_MAX + 1,
  NOCHECK_ORDER_OPTION,
  OUTPUT_DELIMITER_OPTION,
  TOTAL_OPTION
};

static struct option const long_options[] =
{
  {"check-order", no_argument, NULL, CHECK_ORDER_OPTION},
  {"nocheck-order", no_argument, NULL, NOCHECK_ORDER_OPTION},
  {"output-delimiter", required_argument, NULL, OUTPUT_DELIMITER_OPTION},
  {"total", no_argument, NULL, TOTAL_OPTION},
  {"zero-terminated", no_argument, NULL, 'z'},
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
Usage: %s [OPTION]... FILE1 FILE2\n\
"),
              program_name);
      fputs (_("\
Compare sorted files FILE1 and FILE2 line by line.\n\
"), stdout);
      fputs (_("\
\n\
When FILE1 or FILE2 (not both) is -, read standard input.\n\
"), stdout);
      fputs (_("\
\n\
With no options, produce three-column output.  Column one contains\n\
lines unique to FILE1, column two contains lines unique to FILE2,\n\
and column three contains lines common to both files.\n\
"), stdout);
      fputs (_("\
\n\
  -1              suppress column 1 (lines unique to FILE1)\n\
  -2              suppress column 2 (lines unique to FILE2)\n\
  -3              suppress column 3 (lines that appear in both files)\n\
"), stdout);
      fputs (_("\
\n\
  --check-order     check that the input is correctly sorted, even\n\
                      if all input lines are pairable\n\
  --nocheck-order   do not check that the input is correctly sorted\n\
"), stdout);
      fputs (_("\
  --output-delimiter=STR  separate columns with STR\n\
"), stdout);
      fputs (_("\
  --total           output a summary\n\
"), stdout);
      fputs (_("\
  -z, --zero-terminated    line delimiter is NUL, not newline\n\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      fputs (_("\
\n\
Note, comparisons honor the rules specified by 'LC_COLLATE'.\n\
"), stdout);
      printf (_("\
\n\
Examples:\n\
  %s -12 file1 file2  Print only lines present in both file1 and file2.\n\
  %s -3 file1 file2  Print lines in file1 not in file2, and vice versa.\n\
"),
              program_name, program_name);
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}

/* Output the line in linebuffer LINE to stream STREAM
   provided the switches say it should be output.
   CLASS is 1 for a line found only in file 1,
   2 for a line only in file 2, 3 for a line in both. */

static void
writeline (struct linebuffer const *line, FILE *stream, int class)
{
  switch (class)
    {
    case 1:
      if (!only_file_1)
        return;
      break;

    case 2:
      if (!only_file_2)
        return;
      if (only_file_1)
        fwrite (col_sep, 1, col_sep_len, stream);
      break;

    case 3:
      if (!both)
        return;
      if (only_file_1)
        fwrite (col_sep, 1, col_sep_len, stream);
      if (only_file_2)
        fwrite (col_sep, 1, col_sep_len, stream);
      break;
    }

  fwrite (line->buffer, sizeof (char), line->length, stream);
}

/* Check that successive input lines PREV and CURRENT from input file
   WHATFILE are presented in order.

   If the user specified --nocheck-order, the check is not made.
   If the user specified --check-order, the problem is fatal.
   Otherwise (the default), the message is simply a warning.

   A message is printed at most once per input file.

   This function was copied (nearly) verbatim from 'src/join.c'. */

static void
check_order (struct linebuffer const *prev,
             struct linebuffer const *current,
             int whatfile)
{

  if (check_input_order != CHECK_ORDER_DISABLED
      && ((check_input_order == CHECK_ORDER_ENABLED) || seen_unpairable))
    {
      if (!issued_disorder_warning[whatfile - 1])
        {
          int order;

          if (hard_LC_COLLATE)
            order = xmemcoll (prev->buffer, prev->length - 1,
                              current->buffer, current->length - 1);
          else
            order = memcmp2 (prev->buffer, prev->length - 1,
                             current->buffer, current->length - 1);

          if (0 < order)
            {
              error ((check_input_order == CHECK_ORDER_ENABLED
                      ? EXIT_FAILURE : 0),
                     0, _("file %d is not in sorted order"), whatfile);

              /* If we get to here, the message was just a warning, but we
                 want only to issue it once. */
              issued_disorder_warning[whatfile - 1] = true;
            }
        }
    }
}

/* Compare INFILES[0] and INFILES[1].
   If either is "-", use the standard input for that file.
   Assume that each input file is sorted;
   merge them and output the result.  */

static void
compare_files (char **infiles)
{
  /* For each file, we have four linebuffers in lba. */
  struct linebuffer lba[2][4];

  /* thisline[i] points to the linebuffer holding the next available line
     in file i, or is NULL if there are no lines left in that file.  */
  struct linebuffer *thisline[2];

  /* all_line[i][alt[i][0]] also points to the linebuffer holding the
     current line in file i. We keep two buffers of history around so we
     can look two lines back when we get to the end of a file. */
  struct linebuffer *all_line[2][4];

  /* This is used to rotate through the buffers for each input file. */
  int alt[2][3];

  /* streams[i] holds the input stream for file i.  */
  FILE *streams[2];

  /* Counters for the summary.  */
  uintmax_t total[] = {0, 0, 0};

  int i, j;

  /* Initialize the storage. */
  for (i = 0; i < 2; i++)
    {
      for (j = 0; j < 4; j++)
        {
          initbuffer (&lba[i][j]);
          all_line[i][j] = &lba[i][j];
        }
      alt[i][0] = 0;
      alt[i][1] = 0;
      alt[i][2] = 0;
      streams[i] = (STREQ (infiles[i], "-") ? stdin : fopen (infiles[i], "r"));
      if (!streams[i])
        die (EXIT_FAILURE, errno, "%s", quotef (infiles[i]));

      fadvise (streams[i], FADVISE_SEQUENTIAL);

      thisline[i] = readlinebuffer_delim (all_line[i][alt[i][0]], streams[i],
                                          delim);
      if (ferror (streams[i]))
        die (EXIT_FAILURE, errno, "%s", quotef (infiles[i]));
    }

  while (thisline[0] || thisline[1])
    {
      int order;
      bool fill_up[2] = { false, false };

      /* Compare the next available lines of the two files.  */

      if (!thisline[0])
        order = 1;
      else if (!thisline[1])
        order = -1;
      else
        {
          if (hard_LC_COLLATE)
            order = xmemcoll (thisline[0]->buffer, thisline[0]->length - 1,
                              thisline[1]->buffer, thisline[1]->length - 1);
          else
            {
              size_t len = min (thisline[0]->length, thisline[1]->length) - 1;
              order = memcmp (thisline[0]->buffer, thisline[1]->buffer, len);
              if (order == 0)
                order = (thisline[0]->length < thisline[1]->length
                         ? -1
                         : thisline[0]->length != thisline[1]->length);
            }
        }

      /* Output the line that is lesser. */
      if (order == 0)
        {
          /* Line is seen in both files.  */
          total[2]++;
          writeline (thisline[1], stdout, 3);
        }
      else
        {
          seen_unpairable = true;
          if (order <= 0)
            {
              /* Line is seen in file 1 only.  */
              total[0]++;
              writeline (thisline[0], stdout, 1);
            }
          else
            {
              /* Line is seen in file 2 only.  */
              total[1]++;
              writeline (thisline[1], stdout, 2);
            }
        }

      /* Step the file the line came from.
         If the files match, step both files.  */
      if (0 <= order)
        fill_up[1] = true;
      if (order <= 0)
        fill_up[0] = true;

      for (i = 0; i < 2; i++)
        if (fill_up[i])
          {
            /* Rotate the buffers for this file. */
            alt[i][2] = alt[i][1];
            alt[i][1] = alt[i][0];
            alt[i][0] = (alt[i][0] + 1) & 0x03;

            thisline[i] = readlinebuffer_delim (all_line[i][alt[i][0]],
                                                streams[i], delim);

            if (thisline[i])
              check_order (all_line[i][alt[i][1]], thisline[i], i + 1);

            /* If this is the end of the file we may need to re-check
               the order of the previous two lines, since we might have
               discovered an unpairable match since we checked before. */
            else if (all_line[i][alt[i][2]]->buffer)
              check_order (all_line[i][alt[i][2]],
                           all_line[i][alt[i][1]], i + 1);

            if (ferror (streams[i]))
              die (EXIT_FAILURE, errno, "%s", quotef (infiles[i]));

            fill_up[i] = false;
          }
    }

  for (i = 0; i < 2; i++)
    if (fclose (streams[i]) != 0)
      die (EXIT_FAILURE, errno, "%s", quotef (infiles[i]));

  if (total_option)
    {
      /* Print the summary, minding the column and line delimiters.  */
      char buf1[INT_BUFSIZE_BOUND (uintmax_t)];
      char buf2[INT_BUFSIZE_BOUND (uintmax_t)];
      char buf3[INT_BUFSIZE_BOUND (uintmax_t)];
      printf ("%s%s%s%s%s%s%s%c",
              umaxtostr (total[0], buf1), col_sep,
              umaxtostr (total[1], buf2), col_sep,
              umaxtostr (total[2], buf3), col_sep,
              _("total"), delim);
    }
}

int
main (int argc, char **argv)
{
  int c;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);
  hard_LC_COLLATE = hard_locale (LC_COLLATE);

  atexit (close_stdout);

  only_file_1 = true;
  only_file_2 = true;
  both = true;

  seen_unpairable = false;
  issued_disorder_warning[0] = issued_disorder_warning[1] = false;
  check_input_order = CHECK_ORDER_DEFAULT;
  total_option = false;

  while ((c = getopt_long (argc, argv, "123z", long_options, NULL)) != -1)
    switch (c)
      {
      case '1':
        only_file_1 = false;
        break;

      case '2':
        only_file_2 = false;
        break;

      case '3':
        both = false;
        break;

      case 'z':
        delim = '\0';
        break;

      case NOCHECK_ORDER_OPTION:
        check_input_order = CHECK_ORDER_DISABLED;
        break;

      case CHECK_ORDER_OPTION:
        check_input_order = CHECK_ORDER_ENABLED;
        break;

      case OUTPUT_DELIMITER_OPTION:
        if (col_sep_len && !STREQ (col_sep, optarg))
          die (EXIT_FAILURE, 0, _("multiple output delimiters specified"));
        col_sep = optarg;
        col_sep_len = *optarg ? strlen (optarg) : 1;
        break;

      case TOTAL_OPTION:
        total_option = true;
        break;

      case_GETOPT_HELP_CHAR;

      case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);

      default:
        usage (EXIT_FAILURE);
      }

  if (! col_sep_len)
    col_sep_len = 1;

  if (argc - optind < 2)
    {
      if (argc <= optind)
        error (0, 0, _("missing operand"));
      else
        error (0, 0, _("missing operand after %s"), quote (argv[argc - 1]));
      usage (EXIT_FAILURE);
    }

  if (2 < argc - optind)
    {
      error (0, 0, _("extra operand %s"), quote (argv[optind + 2]));
      usage (EXIT_FAILURE);
    }

  compare_files (argv + optind);

  if (issued_disorder_warning[0] || issued_disorder_warning[1])
    return EXIT_FAILURE;
  else
    return EXIT_SUCCESS;
}
