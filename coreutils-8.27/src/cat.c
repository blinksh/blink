/* cat -- concatenate files and print on the standard output.
   Copyright (C) 1988-2017 Free Software Foundation, Inc.

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

/* Differences from the Unix cat:
   * Always unbuffered, -u is ignored.
   * Usually much faster than other versions of cat, the difference
   is especially apparent when using the -v option.

   By tege@sics.se, Torbjorn Granlund, advised by rms, Richard Stallman.  */

#include <config.h>

#include <stdio.h>
#include <getopt.h>
#include <sys/types.h>

#if HAVE_STROPTS_H
# include <stropts.h>
#endif
#include <sys/ioctl.h>

#include "system.h"
#include "ioblksize.h"
#include "die.h"
#include "error.h"
#include "fadvise.h"
#include "full-write.h"
#include "safe-read.h"
#include "xbinary-io.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "cat"

#undef usage
#define usage cat_usage
static void cat_usage (int status);


#define AUTHORS \
  proper_name ("Torbjorn Granlund"), \
  proper_name ("Richard M. Stallman")

/* Name of input file.  May be "-".  */
static char const *infile;

/* Descriptor on which input file is open.  */
static int input_desc;

/* Buffer for line numbers.
   An 11 digit counter may overflow within an hour on a P2/466,
   an 18 digit counter needs about 1000y */
#define LINE_COUNTER_BUF_LEN 20
static char line_buf[LINE_COUNTER_BUF_LEN] =
  {
    ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ',
    ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', '0',
    '\t', '\0'
  };

/* Position in 'line_buf' where printing starts.  This will not change
   unless the number of lines is larger than 999999.  */
static char *line_num_print = line_buf + LINE_COUNTER_BUF_LEN - 8;

/* Position of the first digit in 'line_buf'.  */
static char *line_num_start = line_buf + LINE_COUNTER_BUF_LEN - 3;

/* Position of the last digit in 'line_buf'.  */
static char *line_num_end = line_buf + LINE_COUNTER_BUF_LEN - 3;

/* Preserves the 'cat' function's local 'newlines' between invocations.  */
static int newlines2 = 0;

void
cat_usage (int status)
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
Concatenate FILE(s) to standard output.\n\
"), stdout);

      emit_stdin_note ();

      fputs (_("\
\n\
  -A, --show-all           equivalent to -vET\n\
  -b, --number-nonblank    number nonempty output lines, overrides -n\n\
  -e                       equivalent to -vE\n\
  -E, --show-ends          display $ at end of each line\n\
  -n, --number             number all output lines\n\
  -s, --squeeze-blank      suppress repeated empty output lines\n\
"), stdout);
      fputs (_("\
  -t                       equivalent to -vT\n\
  -T, --show-tabs          display TAB characters as ^I\n\
  -u                       (ignored)\n\
  -v, --show-nonprinting   use ^ and M- notation, except for LFD and TAB\n\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      printf (_("\
\n\
Examples:\n\
  %s f - g  Output f's contents, then standard input, then g's contents.\n\
  %s        Copy standard input to standard output.\n\
"),
              program_name, program_name);
      emit_ancillary_info (PROGRAM_NAME);
    }
  // exit (status);
}

/* Compute the next line number.  */

static void
next_line_num (void)
{
  char *endp = line_num_end;
  do
    {
      if ((*endp)++ < '9')
        return;
      *endp-- = '0';
    }
  while (endp >= line_num_start);
  if (line_num_start > line_buf)
    *--line_num_start = '1';
  else
    *line_buf = '>';
  if (line_num_start < line_num_print)
    line_num_print--;
}

/* Plain cat.  Copies the file behind 'input_desc' to STDOUT_FILENO.
   Return true if successful.  */

static bool
simple_cat (
     /* Pointer to the buffer, used by reads and writes.  */
     char *buf,

     /* Number of characters preferably read or written by each read and write
        call.  */
     size_t bufsize)
{
  /* Actual number of characters read, and therefore written.  */
  size_t n_read;

  /* Loop until the end of the file.  */

  while (true)
    {
      /* Read a block of input.  */

      n_read = safe_read (input_desc, buf, bufsize);
      if (n_read == SAFE_READ_ERROR)
        {
          error (0, errno, "%s", quotef (infile));
          return false;
        }

      /* End of this file?  */

      if (n_read == 0)
        return true;

      /* Write this block out.  */

      {
        /* The following is ok, since we know that 0 < n_read.  */
        size_t n = n_read;
        if (full_write (STDOUT_FILENO, buf, n) != n)
          die (EXIT_FAILURE, errno, _("write error"));
      }
    }
}

/* Write any pending output to STDOUT_FILENO.
   Pending is defined to be the *BPOUT - OUTBUF bytes starting at OUTBUF.
   Then set *BPOUT to OUTPUT if it's not already that value.  */

static inline void
write_pending (char *outbuf, char **bpout)
{
  size_t n_write = *bpout - outbuf;
  if (0 < n_write)
    {
      if (full_write (STDOUT_FILENO, outbuf, n_write) != n_write)
        die (EXIT_FAILURE, errno, _("write error"));
      *bpout = outbuf;
    }
}

/* Cat the file behind INPUT_DESC to the file behind OUTPUT_DESC.
   Return true if successful.
   Called if any option more than -u was specified.

   A newline character is always put at the end of the buffer, to make
   an explicit test for buffer end unnecessary.  */

static bool
cat (
     /* Pointer to the beginning of the input buffer.  */
     char *inbuf,

     /* Number of characters read in each read call.  */
     size_t insize,

     /* Pointer to the beginning of the output buffer.  */
     char *outbuf,

     /* Number of characters written by each write call.  */
     size_t outsize,

     /* Variables that have values according to the specified options.  */
     bool show_nonprinting,
     bool show_tabs,
     bool number,
     bool number_nonblank,
     bool show_ends,
     bool squeeze_blank)
{
  /* Last character read from the input buffer.  */
  unsigned char ch;

  /* Pointer to the next character in the input buffer.  */
  char *bpin;

  /* Pointer to the first non-valid byte in the input buffer, i.e., the
     current end of the buffer.  */
  char *eob;

  /* Pointer to the position where the next character shall be written.  */
  char *bpout;

  /* Number of characters read by the last read call.  */
  size_t n_read;

  /* Determines how many consecutive newlines there have been in the
     input.  0 newlines makes NEWLINES -1, 1 newline makes NEWLINES 1,
     etc.  Initially 0 to indicate that we are at the beginning of a
     new line.  The "state" of the procedure is determined by
     NEWLINES.  */
  int newlines = newlines2;

#ifdef FIONREAD
  /* If nonzero, use the FIONREAD ioctl, as an optimization.
     (On Ultrix, it is not supported on NFS file systems.)  */
  bool use_fionread = true;
#endif

  /* The inbuf pointers are initialized so that BPIN > EOB, and thereby input
     is read immediately.  */

  eob = inbuf;
  bpin = eob + 1;

  bpout = outbuf;

  while (true)
    {
      do
        {
          /* Write if there are at least OUTSIZE bytes in OUTBUF.  */

          if (outbuf + outsize <= bpout)
            {
              char *wp = outbuf;
              size_t remaining_bytes;
              do
                {
                  if (full_write (STDOUT_FILENO, wp, outsize) != outsize)
                    die (EXIT_FAILURE, errno, _("write error"));
                  wp += outsize;
                  remaining_bytes = bpout - wp;
                }
              while (outsize <= remaining_bytes);

              /* Move the remaining bytes to the beginning of the
                 buffer.  */

              memmove (outbuf, wp, remaining_bytes);
              bpout = outbuf + remaining_bytes;
            }

          /* Is INBUF empty?  */

          if (bpin > eob)
            {
              bool input_pending = false;
#ifdef FIONREAD
              int n_to_read = 0;

              /* Is there any input to read immediately?
                 If not, we are about to wait,
                 so write all buffered output before waiting.  */

              if (use_fionread
                  && ioctl (input_desc, FIONREAD, &n_to_read) < 0)
                {
                  /* Ultrix returns EOPNOTSUPP on NFS;
                     HP-UX returns ENOTTY on pipes.
                     SunOS returns EINVAL and
                     More/BSD returns ENODEV on special files
                     like /dev/null.
                     Irix-5 returns ENOSYS on pipes.  */
                  if (errno == EOPNOTSUPP || errno == ENOTTY
                      || errno == EINVAL || errno == ENODEV
                      || errno == ENOSYS)
                    use_fionread = false;
                  else
                    {
                      error (0, errno, _("cannot do ioctl on %s"),
                             quoteaf (infile));
                      newlines2 = newlines;
                      return false;
                    }
                }
              if (n_to_read != 0)
                input_pending = true;
#endif

              if (!input_pending)
                write_pending (outbuf, &bpout);

              /* Read more input into INBUF.  */

              n_read = safe_read (input_desc, inbuf, insize);
              if (n_read == SAFE_READ_ERROR)
                {
                  error (0, errno, "%s", quotef (infile));
                  write_pending (outbuf, &bpout);
                  newlines2 = newlines;
                  return false;
                }
              if (n_read == 0)
                {
                  write_pending (outbuf, &bpout);
                  newlines2 = newlines;
                  return true;
                }

              /* Update the pointers and insert a sentinel at the buffer
                 end.  */

              bpin = inbuf;
              eob = bpin + n_read;
              *eob = '\n';
            }
          else
            {
              /* It was a real (not a sentinel) newline.  */

              /* Was the last line empty?
                 (i.e., have two or more consecutive newlines been read?)  */

              if (++newlines > 0)
                {
                  if (newlines >= 2)
                    {
                      /* Limit this to 2 here.  Otherwise, with lots of
                         consecutive newlines, the counter could wrap
                         around at INT_MAX.  */
                      newlines = 2;

                      /* Are multiple adjacent empty lines to be substituted
                         by single ditto (-s), and this was the second empty
                         line?  */
                      if (squeeze_blank)
                        {
                          ch = *bpin++;
                          continue;
                        }
                    }

                  /* Are line numbers to be written at empty lines (-n)?  */

                  if (number && !number_nonblank)
                    {
                      next_line_num ();
                      bpout = stpcpy (bpout, line_num_print);
                    }
                }

              /* Output a currency symbol if requested (-e).  */

              if (show_ends)
                *bpout++ = '$';

              /* Output the newline.  */

              *bpout++ = '\n';
            }
          ch = *bpin++;
        }
      while (ch == '\n');

      /* Are we at the beginning of a line, and line numbers are requested?  */

      if (newlines >= 0 && number)
        {
          next_line_num ();
          bpout = stpcpy (bpout, line_num_print);
        }

      /* Here CH cannot contain a newline character.  */

      /* The loops below continue until a newline character is found,
         which means that the buffer is empty or that a proper newline
         has been found.  */

      /* If quoting, i.e., at least one of -v, -e, or -t specified,
         scan for chars that need conversion.  */
      if (show_nonprinting)
        {
          while (true)
            {
              if (ch >= 32)
                {
                  if (ch < 127)
                    *bpout++ = ch;
                  else if (ch == 127)
                    {
                      *bpout++ = '^';
                      *bpout++ = '?';
                    }
                  else
                    {
                      *bpout++ = 'M';
                      *bpout++ = '-';
                      if (ch >= 128 + 32)
                        {
                          if (ch < 128 + 127)
                            *bpout++ = ch - 128;
                          else
                            {
                              *bpout++ = '^';
                              *bpout++ = '?';
                            }
                        }
                      else
                        {
                          *bpout++ = '^';
                          *bpout++ = ch - 128 + 64;
                        }
                    }
                }
              else if (ch == '\t' && !show_tabs)
                *bpout++ = '\t';
              else if (ch == '\n')
                {
                  newlines = -1;
                  break;
                }
              else
                {
                  *bpout++ = '^';
                  *bpout++ = ch + 64;
                }

              ch = *bpin++;
            }
        }
      else
        {
          /* Not quoting, neither of -v, -e, or -t specified.  */
          while (true)
            {
              if (ch == '\t' && show_tabs)
                {
                  *bpout++ = '^';
                  *bpout++ = ch + 64;
                }
              else if (ch != '\n')
                *bpout++ = ch;
              else
                {
                  newlines = -1;
                  break;
                }

              ch = *bpin++;
            }
        }
    }
}

int
cat_main (int argc, char **argv)
{
  /* Optimal size of i/o operations of output.  */
  size_t outsize;

  /* Optimal size of i/o operations of input.  */
  size_t insize;

  size_t page_size = getpagesize ();

  /* Pointer to the input buffer.  */
  char *inbuf;

  /* Pointer to the output buffer.  */
  char *outbuf;

  bool ok = true;
  int c;

  /* Index in argv to processed argument.  */
  int argind;

  /* Device number of the output (file or whatever).  */
  dev_t out_dev;

  /* I-node number of the output.  */
  ino_t out_ino;

  /* True if the output is a regular file.  */
  bool out_isreg;

  /* Nonzero if we have ever read standard input.  */
  bool have_read_stdin = false;

  struct stat stat_buf;

  /* Variables that are set according to the specified options.  */
  bool number = false;
  bool number_nonblank = false;
  bool squeeze_blank = false;
  bool show_ends = false;
  bool show_nonprinting = false;
  bool show_tabs = false;
  int file_open_mode = O_RDONLY;

  static struct option const long_options[] =
  {
    {"number-nonblank", no_argument, NULL, 'b'},
    {"number", no_argument, NULL, 'n'},
    {"squeeze-blank", no_argument, NULL, 's'},
    {"show-nonprinting", no_argument, NULL, 'v'},
    {"show-ends", no_argument, NULL, 'E'},
    {"show-tabs", no_argument, NULL, 'T'},
    {"show-all", no_argument, NULL, 'A'},
    {GETOPT_HELP_OPTION_DECL},
    {GETOPT_VERSION_OPTION_DECL},
    {NULL, 0, NULL, 0}
  };

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  /* Arrange to close stdout if we exit via the
     case_GETOPT_HELP_CHAR or case_GETOPT_VERSION_CHAR code.
     Normally STDOUT_FILENO is used rather than stdout, so
     close_stdout does nothing.  */
  atexit (close_stdout);

  /* Parse command line options.  */

  while ((c = getopt_long (argc, argv, "benstuvAET", long_options, NULL))
         != -1)
    {
      switch (c)
        {
        case 'b':
          number = true;
          number_nonblank = true;
          break;

        case 'e':
          show_ends = true;
          show_nonprinting = true;
          break;

        case 'n':
          number = true;
          break;

        case 's':
          squeeze_blank = true;
          break;

        case 't':
          show_tabs = true;
          show_nonprinting = true;
          break;

        case 'u':
          /* We provide the -u feature unconditionally.  */
          break;

        case 'v':
          show_nonprinting = true;
          break;

        case 'A':
          show_nonprinting = true;
          show_ends = true;
          show_tabs = true;
          break;

        case 'E':
          show_ends = true;
          break;

        case 'T':
          show_tabs = true;
          break;

        case_GETOPT_HELP_CHAR;

        case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);

        default:
          cat_usage (EXIT_FAILURE);
            return EXIT_FAILURE;
        }
    }

  /* Get device, i-node number, and optimal blocksize of output.  */

  if (fstat (STDOUT_FILENO, &stat_buf) < 0)
    die (EXIT_FAILURE, errno, _("standard output"));

  outsize = io_blksize (stat_buf);
  out_dev = stat_buf.st_dev;
  out_ino = stat_buf.st_ino;
  out_isreg = S_ISREG (stat_buf.st_mode) != 0;

  if (! (number || show_ends || squeeze_blank))
    {
      file_open_mode |= O_BINARY;
      xset_binary_mode (STDOUT_FILENO, O_BINARY);
    }

  /* Check if any of the input files are the same as the output file.  */

  /* Main loop.  */

  infile = "-";
  argind = optind;

  do
    {
      if (argind < argc)
        infile = argv[argind];

      if (STREQ (infile, "-"))
        {
          have_read_stdin = true;
          input_desc = STDIN_FILENO;
          if (file_open_mode & O_BINARY)
            xset_binary_mode (STDIN_FILENO, O_BINARY);
        }
      else
        {
          input_desc = open (infile, file_open_mode);
          if (input_desc < 0)
            {
              error (0, errno, "%s", quotef (infile));
              ok = false;
              continue;
            }
        }

      if (fstat (input_desc, &stat_buf) < 0)
        {
          error (0, errno, "%s", quotef (infile));
          ok = false;
          goto contin;
        }
      insize = io_blksize (stat_buf);

      fdadvise (input_desc, 0, 0, FADVISE_SEQUENTIAL);

      /* Don't copy a nonempty regular file to itself, as that would
         merely exhaust the output device.  It's better to catch this
         error earlier rather than later.  */

      if (out_isreg
          && stat_buf.st_dev == out_dev && stat_buf.st_ino == out_ino
          && lseek (input_desc, 0, SEEK_CUR) < stat_buf.st_size)
        {
          error (0, 0, _("%s: input file is output file"), quotef (infile));
          ok = false;
          goto contin;
        }

      /* Select which version of 'cat' to use.  If any format-oriented
         options were given use 'cat'; otherwise use 'simple_cat'.  */

      if (! (number || show_ends || show_nonprinting
             || show_tabs || squeeze_blank))
        {
          insize = MAX (insize, outsize);
          inbuf = xmalloc (insize + page_size - 1);

          ok &= simple_cat (ptr_align (inbuf, page_size), insize);
        }
      else
        {
          inbuf = xmalloc (insize + 1 + page_size - 1);

          /* Why are
             (OUTSIZE - 1 + INSIZE * 4 + LINE_COUNTER_BUF_LEN + PAGE_SIZE - 1)
             bytes allocated for the output buffer?

             A test whether output needs to be written is done when the input
             buffer empties or when a newline appears in the input.  After
             output is written, at most (OUTSIZE - 1) bytes will remain in the
             buffer.  Now INSIZE bytes of input is read.  Each input character
             may grow by a factor of 4 (by the prepending of M-^).  If all
             characters do, and no newlines appear in this block of input, we
             will have at most (OUTSIZE - 1 + INSIZE * 4) bytes in the buffer.
             If the last character in the preceding block of input was a
             newline, a line number may be written (according to the given
             options) as the first thing in the output buffer. (Done after the
             new input is read, but before processing of the input begins.)
             A line number requires seldom more than LINE_COUNTER_BUF_LEN
             positions.

             Align the output buffer to a page size boundary, for efficiency
             on some paging implementations, so add PAGE_SIZE - 1 bytes to the
             request to make room for the alignment.  */

          outbuf = xmalloc (outsize - 1 + insize * 4 + LINE_COUNTER_BUF_LEN
                            + page_size - 1);

          ok &= cat (ptr_align (inbuf, page_size), insize,
                     ptr_align (outbuf, page_size), outsize, show_nonprinting,
                     show_tabs, number, number_nonblank, show_ends,
                     squeeze_blank);

          free (outbuf);
        }

      free (inbuf);

    contin:
      if (!STREQ (infile, "-") && close (input_desc) < 0)
        {
          error (0, errno, "%s", quotef (infile));
          ok = false;
        }
    }
  while (++argind < argc);

  if (have_read_stdin && close (STDIN_FILENO) < 0)
    die (EXIT_FAILURE, errno, _("closing standard input"));

  return ok ? EXIT_SUCCESS : EXIT_FAILURE;
}
