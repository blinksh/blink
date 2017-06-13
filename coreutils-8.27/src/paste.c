/* paste - merge lines of files
   Copyright (C) 1997-2017 Free Software Foundation, Inc.
   Copyright (C) 1984 David M. Ihnat

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

/* Written by David Ihnat.  */

/* The list of valid escape sequences has been expanded over the Unix
   version, to include \b, \f, \r, and \v.

   POSIX changes, bug fixes, long-named options, and cleanup
   by David MacKenzie <djm@gnu.ai.mit.edu>.

   Options:
   --serial
   -s				Paste one file at a time rather than
                                one line from each file.
   --delimiters=delim-list
   -d delim-list		Consecutively use the characters in
                                DELIM-LIST instead of tab to separate
                                merged lines.  When DELIM-LIST is exhausted,
                                start again at its beginning.
   A FILE of '-' means standard input.
   If no FILEs are given, standard input is used. */

#include <config.h>

#include <stdio.h>
#include <getopt.h>
#include <sys/types.h>
#include "system.h"
#include "die.h"
#include "error.h"
#include "fadvise.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "paste"

#define AUTHORS \
  proper_name ("David M. Ihnat"), \
  proper_name ("David MacKenzie")

/* Indicates that no delimiter should be added in the current position. */
#define EMPTY_DELIM '\0'

/* If nonzero, we have read standard input at some point. */
static bool have_read_stdin;

/* If nonzero, merge subsequent lines of each file rather than
   corresponding lines from each file in parallel. */
static bool serial_merge;

/* The delimiters between lines of input files (used cyclically). */
static char *delims;

/* A pointer to the character after the end of 'delims'. */
static char const *delim_end;

static unsigned char line_delim = '\n';

static struct option const longopts[] =
{
  {"serial", no_argument, NULL, 's'},
  {"delimiters", required_argument, NULL, 'd'},
  {"zero-terminated", no_argument, NULL, 'z'},
  {GETOPT_HELP_OPTION_DECL},
  {GETOPT_VERSION_OPTION_DECL},
  {NULL, 0, NULL, 0}
};

/* Set globals delims and delim_end.  Copy STRPTR to DELIMS, converting
   backslash representations of special characters in STRPTR to their actual
   values. The set of possible backslash characters has been expanded beyond
   that recognized by the Unix version.
   Return 0 upon success.
   If the string ends in an odd number of backslashes, ignore the
   final backslash and return nonzero.  */

static int
collapse_escapes (char const *strptr)
{
  char *strout = xstrdup (strptr);
  bool backslash_at_end = false;

  delims = strout;

  while (*strptr)
    {
      if (*strptr != '\\')	/* Is it an escape character? */
        *strout++ = *strptr++;	/* No, just transfer it. */
      else
        {
          switch (*++strptr)
            {
            case '0':
              *strout++ = EMPTY_DELIM;
              break;

            case 'b':
              *strout++ = '\b';
              break;

            case 'f':
              *strout++ = '\f';
              break;

            case 'n':
              *strout++ = '\n';
              break;

            case 'r':
              *strout++ = '\r';
              break;

            case 't':
              *strout++ = '\t';
              break;

            case 'v':
              *strout++ = '\v';
              break;

            case '\\':
              *strout++ = '\\';
              break;

            case '\0':
              backslash_at_end = true;
              goto done;

            default:
              *strout++ = *strptr;
              break;
            }
          strptr++;
        }
    }

 done:

  delim_end = strout;
  return backslash_at_end ? 1 : 0;
}

/* Report a write error and exit.  */

static void write_error (void) ATTRIBUTE_NORETURN;
static void
write_error (void)
{
  die (EXIT_FAILURE, errno, _("write error"));
}

/* Output a single byte, reporting any write errors.  */

static inline void
xputchar (char c)
{
  if (putchar (c) < 0)
    write_error ();
}

/* Perform column paste on the NFILES files named in FNAMPTR.
   Return true if successful, false if one or more files could not be
   opened or read. */

static bool
paste_parallel (size_t nfiles, char **fnamptr)
{
  bool ok = true;
  /* If all files are just ready to be closed, or will be on this
     round, the string of delimiters must be preserved.
     delbuf[0] through delbuf[nfiles]
     store the delimiters for closed files. */
  char *delbuf = xmalloc (nfiles + 2);

  /* Streams open to the files to process; NULL if the corresponding
     stream is closed.  */
  FILE **fileptr = xnmalloc (nfiles + 1, sizeof *fileptr);

  /* Number of files still open to process.  */
  size_t files_open;

  /* True if any fopen got fd == STDIN_FILENO.  */
  bool opened_stdin = false;

  /* Attempt to open all files.  This could be expanded to an infinite
     number of files, but at the (considerable) expense of remembering
     each file and its current offset, then opening/reading/closing.  */

  for (files_open = 0; files_open < nfiles; ++files_open)
    {
      if (STREQ (fnamptr[files_open], "-"))
        {
          have_read_stdin = true;
          fileptr[files_open] = stdin;
        }
      else
        {
          fileptr[files_open] = fopen (fnamptr[files_open], "r");
          if (fileptr[files_open] == NULL)
            die (EXIT_FAILURE, errno, "%s", quotef (fnamptr[files_open]));
          else if (fileno (fileptr[files_open]) == STDIN_FILENO)
            opened_stdin = true;
          fadvise (fileptr[files_open], FADVISE_SEQUENTIAL);
        }
    }

  if (opened_stdin && have_read_stdin)
    die (EXIT_FAILURE, 0, _("standard input is closed"));

  /* Read a line from each file and output it to stdout separated by a
     delimiter, until we go through the loop without successfully
     reading from any of the files. */

  while (files_open)
    {
      /* Set up for the next line. */
      bool somedone = false;
      char const *delimptr = delims;
      size_t delims_saved = 0;	/* Number of delims saved in 'delbuf'. */
      size_t i;

      for (i = 0; i < nfiles && files_open; i++)
        {
          int chr IF_LINT ( = 0);	/* Input character. */
          int err IF_LINT ( = 0);	/* Input errno value.  */
          bool sometodo = false;	/* Input chars to process.  */

          if (fileptr[i])
            {
              chr = getc (fileptr[i]);
              err = errno;
              if (chr != EOF && delims_saved)
                {
                  if (fwrite (delbuf, 1, delims_saved, stdout) != delims_saved)
                    write_error ();
                  delims_saved = 0;
                }

              while (chr != EOF)
                {
                  sometodo = true;
                  if (chr == line_delim)
                    break;
                  xputchar (chr);
                  chr = getc (fileptr[i]);
                  err = errno;
                }
            }

          if (! sometodo)
            {
              /* EOF, read error, or closed file.
                 If an EOF or error, close the file.  */
              if (fileptr[i])
                {
                  if (ferror (fileptr[i]))
                    {
                      error (0, err, "%s", quotef (fnamptr[i]));
                      ok = false;
                    }
                  if (fileptr[i] == stdin)
                    clearerr (fileptr[i]); /* Also clear EOF. */
                  else if (fclose (fileptr[i]) == EOF)
                    {
                      error (0, errno, "%s", quotef (fnamptr[i]));
                      ok = false;
                    }

                  fileptr[i] = NULL;
                  files_open--;
                }

              if (i + 1 == nfiles)
                {
                  /* End of this output line.
                     Is this the end of the whole thing? */
                  if (somedone)
                    {
                      /* No.  Some files were not closed for this line. */
                      if (delims_saved)
                        {
                          if (fwrite (delbuf, 1, delims_saved, stdout)
                              != delims_saved)
                            write_error ();
                          delims_saved = 0;
                        }
                      xputchar (line_delim);
                    }
                  continue;	/* Next read of files, or exit. */
                }
              else
                {
                  /* Closed file; add delimiter to 'delbuf'. */
                  if (*delimptr != EMPTY_DELIM)
                    delbuf[delims_saved++] = *delimptr;
                  if (++delimptr == delim_end)
                    delimptr = delims;
                }
            }
          else
            {
              /* Some data read. */
              somedone = true;

              /* Except for last file, replace last newline with delim. */
              if (i + 1 != nfiles)
                {
                  if (chr != line_delim && chr != EOF)
                    xputchar (chr);
                  if (*delimptr != EMPTY_DELIM)
                    xputchar (*delimptr);
                  if (++delimptr == delim_end)
                    delimptr = delims;
                }
              else
                {
                  /* If the last line of the last file lacks a newline,
                     print one anyhow.  POSIX requires this.  */
                  char c = (chr == EOF ? line_delim : chr);
                  xputchar (c);
                }
            }
        }
    }
  free (fileptr);
  free (delbuf);
  return ok;
}

/* Perform serial paste on the NFILES files named in FNAMPTR.
   Return true if no errors, false if one or more files could not be
   opened or read. */

static bool
paste_serial (size_t nfiles, char **fnamptr)
{
  bool ok = true;	/* false if open or read errors occur. */
  int charnew, charold; /* Current and previous char read. */
  char const *delimptr;	/* Current delimiter char. */
  FILE *fileptr;	/* Open for reading current file. */

  for (; nfiles; nfiles--, fnamptr++)
    {
      int saved_errno;
      bool is_stdin = STREQ (*fnamptr, "-");
      if (is_stdin)
        {
          have_read_stdin = true;
          fileptr = stdin;
        }
      else
        {
          fileptr = fopen (*fnamptr, "r");
          if (fileptr == NULL)
            {
              error (0, errno, "%s", quotef (*fnamptr));
              ok = false;
              continue;
            }
          fadvise (fileptr, FADVISE_SEQUENTIAL);
        }

      delimptr = delims;	/* Set up for delimiter string. */

      charold = getc (fileptr);
      saved_errno = errno;
      if (charold != EOF)
        {
          /* 'charold' is set up.  Hit it!
             Keep reading characters, stashing them in 'charnew';
             output 'charold', converting to the appropriate delimiter
             character if needed.  After the EOF, output 'charold'
             if it's a newline; otherwise, output it and then a newline. */

          while ((charnew = getc (fileptr)) != EOF)
            {
              /* Process the old character. */
              if (charold == line_delim)
                {
                  if (*delimptr != EMPTY_DELIM)
                    xputchar (*delimptr);

                  if (++delimptr == delim_end)
                    delimptr = delims;
                }
              else
                xputchar (charold);

              charold = charnew;
            }
          saved_errno = errno;

          /* Hit EOF.  Process that last character. */
          xputchar (charold);
        }

      if (charold != line_delim)
        xputchar (line_delim);

      if (ferror (fileptr))
        {
          error (0, saved_errno, "%s", quotef (*fnamptr));
          ok = false;
        }
      if (is_stdin)
        clearerr (fileptr);	/* Also clear EOF. */
      else if (fclose (fileptr) == EOF)
        {
          error (0, errno, "%s", quotef (*fnamptr));
          ok = false;
        }
    }
  return ok;
}

void
usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("\
Usage: %s [OPTION]... [FILE]...\n\
"),
              program_name);
      fputs (_("\
Write lines consisting of the sequentially corresponding lines from\n\
each FILE, separated by TABs, to standard output.\n\
"), stdout);

      emit_stdin_note ();
      emit_mandatory_arg_note ();

      fputs (_("\
  -d, --delimiters=LIST   reuse characters from LIST instead of TABs\n\
  -s, --serial            paste one file at a time instead of in parallel\n\
"), stdout);
      fputs (_("\
  -z, --zero-terminated    line delimiter is NUL, not newline\n\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      /* FIXME: add a couple of examples.  */
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}

int
main (int argc, char **argv)
{
  int optc;
  char const *delim_arg = "\t";

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdout);

  have_read_stdin = false;
  serial_merge = false;

  while ((optc = getopt_long (argc, argv, "d:sz", longopts, NULL)) != -1)
    {
      switch (optc)
        {
        case 'd':
          /* Delimiter character(s). */
          delim_arg = (optarg[0] == '\0' ? "\\0" : optarg);
          break;

        case 's':
          serial_merge = true;
          break;

        case 'z':
          line_delim = '\0';
          break;

        case_GETOPT_HELP_CHAR;

        case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);

        default:
          usage (EXIT_FAILURE);
        }
    }

  int nfiles = argc - optind;
  if (nfiles == 0)
    {
      argv[optind] = bad_cast ("-");
      nfiles++;
    }

  if (collapse_escapes (delim_arg))
    {
      /* Don't use the quote() quoting style, because that would double the
         number of displayed backslashes, making the diagnostic look bogus.  */
      die (EXIT_FAILURE, 0,
           _("delimiter list ends with an unescaped backslash: %s"),
           quotearg_n_style_colon (0, c_maybe_quoting_style, delim_arg));
    }

  bool ok = ((serial_merge ? paste_serial : paste_parallel)
             (nfiles, &argv[optind]));

  free (delims);

  if (have_read_stdin && fclose (stdin) == EOF)
    die (EXIT_FAILURE, errno, "-");
  return ok ? EXIT_SUCCESS : EXIT_FAILURE;
}
