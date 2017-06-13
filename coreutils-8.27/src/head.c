/* head -- output first part of file(s)
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

/* Options: (see usage)
   Reads from standard input if no files are given or when a filename of
   ''-'' is encountered.
   By default, filename headers are printed only if more than one file
   is given.
   By default, prints the first 10 lines (head -n 10).

   David MacKenzie <djm@gnu.ai.mit.edu> */

#include <config.h>

#include <stdio.h>
#include <getopt.h>
#include <sys/types.h>

#include "system.h"

#include "die.h"
#include "error.h"
#include "full-read.h"
#include "quote.h"
#include "safe-read.h"
#include "stat-size.h"
#include "xbinary-io.h"
#include "xdectoint.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "head"

#define AUTHORS \
  proper_name ("David MacKenzie"), \
  proper_name ("Jim Meyering")

/* Number of lines/chars/blocks to head. */
#define DEFAULT_NUMBER 10

/* Useful only when eliding tail bytes or lines.
   If true, skip the is-regular-file test used to determine whether
   to use the lseek optimization.  Instead, use the more general (and
   more expensive) code unconditionally. Intended solely for testing.  */
static bool presume_input_pipe;

/* If true, print filename headers. */
static bool print_headers;

/* Character to split lines by. */
static char line_end;

/* When to print the filename banners. */
enum header_mode
{
  multiple_files, always, never
};

/* Have we ever read standard input?  */
static bool have_read_stdin;

enum Copy_fd_status
  {
    COPY_FD_OK = 0,
    COPY_FD_READ_ERROR,
    COPY_FD_UNEXPECTED_EOF
  };

/* For long options that have no equivalent short option, use a
   non-character as a pseudo short option, starting with CHAR_MAX + 1.  */
enum
{
  PRESUME_INPUT_PIPE_OPTION = CHAR_MAX + 1
};

static struct option const long_options[] =
{
  {"bytes", required_argument, NULL, 'c'},
  {"lines", required_argument, NULL, 'n'},
  {"-presume-input-pipe", no_argument, NULL,
   PRESUME_INPUT_PIPE_OPTION}, /* do not document */
  {"quiet", no_argument, NULL, 'q'},
  {"silent", no_argument, NULL, 'q'},
  {"verbose", no_argument, NULL, 'v'},
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
Usage: %s [OPTION]... [FILE]...\n\
"),
              program_name);
      printf (_("\
Print the first %d lines of each FILE to standard output.\n\
With more than one FILE, precede each with a header giving the file name.\n\
"), DEFAULT_NUMBER);

      emit_stdin_note ();
      emit_mandatory_arg_note ();

      printf (_("\
  -c, --bytes=[-]NUM       print the first NUM bytes of each file;\n\
                             with the leading '-', print all but the last\n\
                             NUM bytes of each file\n\
  -n, --lines=[-]NUM       print the first NUM lines instead of the first %d;\n\
                             with the leading '-', print all but the last\n\
                             NUM lines of each file\n\
"), DEFAULT_NUMBER);
      fputs (_("\
  -q, --quiet, --silent    never print headers giving file names\n\
  -v, --verbose            always print headers giving file names\n\
"), stdout);
      fputs (_("\
  -z, --zero-terminated    line delimiter is NUL, not newline\n\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      fputs (_("\
\n\
NUM may have a multiplier suffix:\n\
b 512, kB 1000, K 1024, MB 1000*1000, M 1024*1024,\n\
GB 1000*1000*1000, G 1024*1024*1024, and so on for T, P, E, Z, Y.\n\
"), stdout);
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}

static void
diagnose_copy_fd_failure (enum Copy_fd_status err, char const *filename)
{
  switch (err)
    {
    case COPY_FD_READ_ERROR:
      error (0, errno, _("error reading %s"), quoteaf (filename));
      break;
    case COPY_FD_UNEXPECTED_EOF:
      error (0, errno, _("%s: file has shrunk too much"), quotef (filename));
      break;
    default:
      abort ();
    }
}

static void
write_header (const char *filename)
{
  static bool first_file = true;

  printf ("%s==> %s <==\n", (first_file ? "" : "\n"), filename);
  first_file = false;
}

/* Write N_BYTES from BUFFER to stdout.
   Exit immediately on error with a single diagnostic.  */

static void
xwrite_stdout (char const *buffer, size_t n_bytes)
{
  if (n_bytes > 0 && fwrite (buffer, 1, n_bytes, stdout) < n_bytes)
    {
      clearerr (stdout); /* To avoid redundant close_stdout diagnostic.  */
      die (EXIT_FAILURE, errno, _("error writing %s"),
           quoteaf ("standard output"));
    }
}

/* Copy no more than N_BYTES from file descriptor SRC_FD to stdout.
   Return an appropriate indication of success or read failure.  */

static enum Copy_fd_status
copy_fd (int src_fd, uintmax_t n_bytes)
{
  char buf[BUFSIZ];
  const size_t buf_size = sizeof (buf);

  /* Copy the file contents.  */
  while (0 < n_bytes)
    {
      size_t n_to_read = MIN (buf_size, n_bytes);
      size_t n_read = safe_read (src_fd, buf, n_to_read);
      if (n_read == SAFE_READ_ERROR)
        return COPY_FD_READ_ERROR;

      n_bytes -= n_read;

      if (n_read == 0 && n_bytes != 0)
        return COPY_FD_UNEXPECTED_EOF;

      xwrite_stdout (buf, n_read);
    }

  return COPY_FD_OK;
}

/* Call lseek (FD, OFFSET, WHENCE), where file descriptor FD
   corresponds to the file FILENAME.  WHENCE must be SEEK_SET or
   SEEK_CUR.  Return the resulting offset.  Give a diagnostic and
   return -1 if lseek fails.  */

static off_t
elseek (int fd, off_t offset, int whence, char const *filename)
{
  off_t new_offset = lseek (fd, offset, whence);
  char buf[INT_BUFSIZE_BOUND (offset)];

  if (new_offset < 0)
    error (0, errno,
           _(whence == SEEK_SET
             ? N_("%s: cannot seek to offset %s")
             : N_("%s: cannot seek to relative offset %s")),
           quotef (filename),
           offtostr (offset, buf));

  return new_offset;
}

/* For an input file with name FILENAME and descriptor FD,
   output all but the last N_ELIDE_0 bytes.
   If CURRENT_POS is nonnegative, assume that the input file is
   positioned at CURRENT_POS and that it should be repositioned to
   just before the elided bytes before returning.
   Return true upon success.
   Give a diagnostic and return false upon error.  */
static bool
elide_tail_bytes_pipe (const char *filename, int fd, uintmax_t n_elide_0,
                       off_t current_pos)
{
  size_t n_elide = n_elide_0;
  uintmax_t desired_pos = current_pos;
  bool ok = true;

#ifndef HEAD_TAIL_PIPE_READ_BUFSIZE
# define HEAD_TAIL_PIPE_READ_BUFSIZE BUFSIZ
#endif
#define READ_BUFSIZE HEAD_TAIL_PIPE_READ_BUFSIZE

  /* If we're eliding no more than this many bytes, then it's ok to allocate
     more memory in order to use a more time-efficient algorithm.
     FIXME: use a fraction of available memory instead, as in sort.
     FIXME: is this even worthwhile?  */
#ifndef HEAD_TAIL_PIPE_BYTECOUNT_THRESHOLD
# define HEAD_TAIL_PIPE_BYTECOUNT_THRESHOLD 1024 * 1024
#endif

#if HEAD_TAIL_PIPE_BYTECOUNT_THRESHOLD < 2 * READ_BUFSIZE
  "HEAD_TAIL_PIPE_BYTECOUNT_THRESHOLD must be at least 2 * READ_BUFSIZE"
#endif

  if (SIZE_MAX < n_elide_0 + READ_BUFSIZE)
    {
      char umax_buf[INT_BUFSIZE_BOUND (n_elide_0)];
      die (EXIT_FAILURE, 0, _("%s: number of bytes is too large"),
           umaxtostr (n_elide_0, umax_buf));
    }

  /* Two cases to consider...
     1) n_elide is small enough that we can afford to double-buffer:
        allocate 2 * (READ_BUFSIZE + n_elide) bytes
     2) n_elide is too big for that, so we allocate only
        (READ_BUFSIZE + n_elide) bytes

     FIXME: profile, to see if double-buffering is worthwhile

     CAUTION: do not fail (out of memory) when asked to elide
     a ridiculous amount, but when given only a small input.  */

  if (n_elide <= HEAD_TAIL_PIPE_BYTECOUNT_THRESHOLD)
    {
      bool first = true;
      bool eof = false;
      size_t n_to_read = READ_BUFSIZE + n_elide;
      bool i;
      char *b[2];
      b[0] = xnmalloc (2, n_to_read);
      b[1] = b[0] + n_to_read;

      for (i = false; ! eof ; i = !i)
        {
          size_t n_read = full_read (fd, b[i], n_to_read);
          size_t delta = 0;
          if (n_read < n_to_read)
            {
              if (errno != 0)
                {
                  error (0, errno, _("error reading %s"), quoteaf (filename));
                  ok = false;
                  break;
                }

              /* reached EOF */
              if (n_read <= n_elide)
                {
                  if (first)
                    {
                      /* The input is no larger than the number of bytes
                         to elide.  So there's nothing to output, and
                         we're done.  */
                    }
                  else
                    {
                      delta = n_elide - n_read;
                    }
                }
              eof = true;
            }

          /* Output any (but maybe just part of the) elided data from
             the previous round.  */
          if (! first)
            {
              desired_pos += n_elide - delta;
              xwrite_stdout (b[!i] + READ_BUFSIZE, n_elide - delta);
            }
          first = false;

          if (n_elide < n_read)
            {
              desired_pos += n_read - n_elide;
              xwrite_stdout (b[i], n_read - n_elide);
            }
        }

      free (b[0]);
    }
  else
    {
      /* Read blocks of size READ_BUFSIZE, until we've read at least n_elide
         bytes.  Then, for each new buffer we read, also write an old one.  */

      bool eof = false;
      size_t n_read;
      bool buffered_enough;
      size_t i, i_next;
      char **b = NULL;
      /* Round n_elide up to a multiple of READ_BUFSIZE.  */
      size_t rem = READ_BUFSIZE - (n_elide % READ_BUFSIZE);
      size_t n_elide_round = n_elide + rem;
      size_t n_bufs = n_elide_round / READ_BUFSIZE + 1;
      size_t n_alloc = 0;
      size_t n_array_alloc = 0;

      buffered_enough = false;
      for (i = 0, i_next = 1; !eof; i = i_next, i_next = (i_next + 1) % n_bufs)
        {
          if (n_array_alloc == i)
            {
              /* reallocate between 16 and n_bufs entries.  */
              if (n_array_alloc == 0)
                n_array_alloc = MIN (n_bufs, 16);
              else if (n_array_alloc <= n_bufs / 2)
                n_array_alloc *= 2;
              else
                n_array_alloc = n_bufs;
              b = xnrealloc (b, n_array_alloc, sizeof *b);
            }

          if (! buffered_enough)
            {
              b[i] = xmalloc (READ_BUFSIZE);
              n_alloc = i + 1;
            }
          n_read = full_read (fd, b[i], READ_BUFSIZE);
          if (n_read < READ_BUFSIZE)
            {
              if (errno != 0)
                {
                  error (0, errno, _("error reading %s"), quoteaf (filename));
                  ok = false;
                  goto free_mem;
                }
              eof = true;
            }

          if (i + 1 == n_bufs)
            buffered_enough = true;

          if (buffered_enough)
            {
              desired_pos += n_read;
              xwrite_stdout (b[i_next], n_read);
            }
        }

      /* Output any remainder: rem bytes from b[i] + n_read.  */
      if (rem)
        {
          if (buffered_enough)
            {
              size_t n_bytes_left_in_b_i = READ_BUFSIZE - n_read;
              desired_pos += rem;
              if (rem < n_bytes_left_in_b_i)
                {
                  xwrite_stdout (b[i] + n_read, rem);
                }
              else
                {
                  xwrite_stdout (b[i] + n_read, n_bytes_left_in_b_i);
                  xwrite_stdout (b[i_next], rem - n_bytes_left_in_b_i);
                }
            }
          else if (i + 1 == n_bufs)
            {
              /* This happens when n_elide < file_size < n_elide_round.

                 |READ_BUF.|
                 |                      |  rem |
                 |---------!---------!---------!---------|
                 |---- n_elide ---------|
                 |                      | x |
                 |                   |y |
                 |---- file size -----------|
                 |                   |n_read|
                 |---- n_elide_round ----------|
               */
              size_t y = READ_BUFSIZE - rem;
              size_t x = n_read - y;
              desired_pos += x;
              xwrite_stdout (b[i_next], x);
            }
        }

    free_mem:
      for (i = 0; i < n_alloc; i++)
        free (b[i]);
      free (b);
    }

  if (0 <= current_pos && elseek (fd, desired_pos, SEEK_SET, filename) < 0)
    ok = false;
  return ok;
}

/* For the file FILENAME with descriptor FD, output all but the last N_ELIDE
   bytes.  If SIZE is nonnegative, this is a regular file positioned
   at CURRENT_POS with SIZE bytes.  Return true on success.
   Give a diagnostic and return false upon error.  */

/* NOTE: if the input file shrinks by more than N_ELIDE bytes between
   the length determination and the actual reading, then head fails.  */

static bool
elide_tail_bytes_file (const char *filename, int fd, uintmax_t n_elide,
                       struct stat const *st, off_t current_pos)
{
  off_t size = st->st_size;
  if (presume_input_pipe || current_pos < 0 || size <= ST_BLKSIZE (*st))
    return elide_tail_bytes_pipe (filename, fd, n_elide, current_pos);
  else
    {
      /* Be careful here.  The current position may actually be
         beyond the end of the file.  */
      off_t diff = size - current_pos;
      off_t bytes_remaining = diff < 0 ? 0 : diff;

      if (bytes_remaining <= n_elide)
        return true;

      enum Copy_fd_status err = copy_fd (fd, bytes_remaining - n_elide);
      if (err == COPY_FD_OK)
        return true;

      diagnose_copy_fd_failure (err, filename);
      return false;
    }
}

/* For an input file with name FILENAME and descriptor FD,
   output all but the last N_ELIDE_0 bytes.
   If CURRENT_POS is nonnegative, the input file is positioned there
   and should be repositioned to just before the elided bytes.
   Buffer the specified number of lines as a linked list of LBUFFERs,
   adding them as needed.  Return true if successful.  */

static bool
elide_tail_lines_pipe (const char *filename, int fd, uintmax_t n_elide,
                       off_t current_pos)
{
  struct linebuffer
  {
    char buffer[BUFSIZ];
    size_t nbytes;
    size_t nlines;
    struct linebuffer *next;
  };
  uintmax_t desired_pos = current_pos;
  typedef struct linebuffer LBUFFER;
  LBUFFER *first, *last, *tmp;
  size_t total_lines = 0;	/* Total number of newlines in all buffers.  */
  bool ok = true;
  size_t n_read;		/* Size in bytes of most recent read */

  first = last = xmalloc (sizeof (LBUFFER));
  first->nbytes = first->nlines = 0;
  first->next = NULL;
  tmp = xmalloc (sizeof (LBUFFER));

  /* Always read into a fresh buffer.
     Read, (producing no output) until we've accumulated at least
     n_elide newlines, or until EOF, whichever comes first.  */
  while (1)
    {
      n_read = safe_read (fd, tmp->buffer, BUFSIZ);
      if (n_read == 0 || n_read == SAFE_READ_ERROR)
        break;

      if (! n_elide)
        {
          desired_pos += n_read;
          xwrite_stdout (tmp->buffer, n_read);
          continue;
        }

      tmp->nbytes = n_read;
      tmp->nlines = 0;
      tmp->next = NULL;

      /* Count the number of newlines just read.  */
      {
        char const *buffer_end = tmp->buffer + n_read;
        char const *p = tmp->buffer;
        while ((p = memchr (p, line_end, buffer_end - p)))
          {
            ++p;
            ++tmp->nlines;
          }
      }
      total_lines += tmp->nlines;

      /* If there is enough room in the last buffer read, just append the new
         one to it.  This is because when reading from a pipe, 'n_read' can
         often be very small.  */
      if (tmp->nbytes + last->nbytes < BUFSIZ)
        {
          memcpy (&last->buffer[last->nbytes], tmp->buffer, tmp->nbytes);
          last->nbytes += tmp->nbytes;
          last->nlines += tmp->nlines;
        }
      else
        {
          /* If there's not enough room, link the new buffer onto the end of
             the list, then either free up the oldest buffer for the next
             read if that would leave enough lines, or else malloc a new one.
             Some compaction mechanism is possible but probably not
             worthwhile.  */
          last = last->next = tmp;
          if (n_elide < total_lines - first->nlines)
            {
              desired_pos += first->nbytes;
              xwrite_stdout (first->buffer, first->nbytes);
              tmp = first;
              total_lines -= first->nlines;
              first = first->next;
            }
          else
            tmp = xmalloc (sizeof (LBUFFER));
        }
    }

  free (tmp);

  if (n_read == SAFE_READ_ERROR)
    {
      error (0, errno, _("error reading %s"), quoteaf (filename));
      ok = false;
      goto free_lbuffers;
    }

  /* If we read any bytes at all, count the incomplete line
     on files that don't end with a newline.  */
  if (last->nbytes && last->buffer[last->nbytes - 1] != line_end)
    {
      ++last->nlines;
      ++total_lines;
    }

  for (tmp = first; n_elide < total_lines - tmp->nlines; tmp = tmp->next)
    {
      desired_pos += tmp->nbytes;
      xwrite_stdout (tmp->buffer, tmp->nbytes);
      total_lines -= tmp->nlines;
    }

  /* Print the first 'total_lines - n_elide' lines of tmp->buffer.  */
  if (n_elide < total_lines)
    {
      size_t n = total_lines - n_elide;
      char const *buffer_end = tmp->buffer + tmp->nbytes;
      char const *p = tmp->buffer;
      while (n && (p = memchr (p, line_end, buffer_end - p)))
        {
          ++p;
          ++tmp->nlines;
          --n;
        }
      desired_pos += p - tmp->buffer;
      xwrite_stdout (tmp->buffer, p - tmp->buffer);
    }

free_lbuffers:
  while (first)
    {
      tmp = first->next;
      free (first);
      first = tmp;
    }

  if (0 <= current_pos && elseek (fd, desired_pos, SEEK_SET, filename) < 0)
    ok = false;
  return ok;
}

/* Output all but the last N_LINES lines of the input stream defined by
   FD, START_POS, and SIZE.
   START_POS is the starting position of the read pointer for the file
   associated with FD (may be nonzero).
   SIZE is the file size in bytes.
   Return true upon success.
   Give a diagnostic and return false upon error.

   NOTE: this code is very similar to that of tail.c's file_lines function.
   Unfortunately, factoring out some common core looks like it'd result
   in a less efficient implementation or a messy interface.  */
static bool
elide_tail_lines_seekable (const char *pretty_filename, int fd,
                           uintmax_t n_lines,
                           off_t start_pos, off_t size)
{
  char buffer[BUFSIZ];
  size_t bytes_read;
  off_t pos = size;

  /* Set 'bytes_read' to the size of the last, probably partial, buffer;
     0 < 'bytes_read' <= 'BUFSIZ'.  */
  bytes_read = (pos - start_pos) % BUFSIZ;
  if (bytes_read == 0)
    bytes_read = BUFSIZ;
  /* Make 'pos' a multiple of 'BUFSIZ' (0 if the file is short), so that all
     reads will be on block boundaries, which might increase efficiency.  */
  pos -= bytes_read;
  if (elseek (fd, pos, SEEK_SET, pretty_filename) < 0)
    return false;
  bytes_read = safe_read (fd, buffer, bytes_read);
  if (bytes_read == SAFE_READ_ERROR)
    {
      error (0, errno, _("error reading %s"), quoteaf (pretty_filename));
      return false;
    }

  /* n_lines == 0 case needs special treatment. */
  const bool all_lines = !n_lines;

  /* Count the incomplete line on files that don't end with a newline.  */
  if (n_lines && bytes_read && buffer[bytes_read - 1] != line_end)
    --n_lines;

  while (1)
    {
      /* Scan backward, counting the newlines in this bufferfull.  */

      size_t n = bytes_read;
      while (n)
        {
          if (all_lines)
            n -= 1;
          else
            {
              char const *nl;
              nl = memrchr (buffer, line_end, n);
              if (nl == NULL)
                break;
              n = nl - buffer;
            }
          if (n_lines-- == 0)
            {
              /* Found it.  */
              /* If necessary, restore the file pointer and copy
                 input to output up to position, POS.  */
              if (start_pos < pos)
                {
                  enum Copy_fd_status err;
                  if (elseek (fd, start_pos, SEEK_SET, pretty_filename) < 0)
                    return false;

                  err = copy_fd (fd, pos - start_pos);
                  if (err != COPY_FD_OK)
                    {
                      diagnose_copy_fd_failure (err, pretty_filename);
                      return false;
                    }
                }

              /* Output the initial portion of the buffer
                 in which we found the desired newline byte.  */
              xwrite_stdout (buffer, n + 1);

              /* Set file pointer to the byte after what we've output.  */
              return 0 <= elseek (fd, pos + n + 1, SEEK_SET, pretty_filename);
            }
        }

      /* Not enough newlines in that bufferfull.  */
      if (pos == start_pos)
        {
          /* Not enough lines in the file.  */
          return true;
        }
      pos -= BUFSIZ;
      if (elseek (fd, pos, SEEK_SET, pretty_filename) < 0)
        return false;

      bytes_read = safe_read (fd, buffer, BUFSIZ);
      if (bytes_read == SAFE_READ_ERROR)
        {
          error (0, errno, _("error reading %s"), quoteaf (pretty_filename));
          return false;
        }

      /* FIXME: is this dead code?
         Consider the test, pos == start_pos, above. */
      if (bytes_read == 0)
        return true;
    }
}

/* For the file FILENAME with descriptor FD, output all but the last N_ELIDE
   lines.  If SIZE is nonnegative, this is a regular file positioned
   at START_POS with SIZE bytes.  Return true on success.
   Give a diagnostic and return nonzero upon error.  */

static bool
elide_tail_lines_file (const char *filename, int fd, uintmax_t n_elide,
                       struct stat const *st, off_t current_pos)
{
  off_t size = st->st_size;
  if (presume_input_pipe || current_pos < 0 || size <= ST_BLKSIZE (*st))
    return elide_tail_lines_pipe (filename, fd, n_elide, current_pos);
  else
    {
      /* Find the offset, OFF, of the Nth newline from the end,
         but not counting the last byte of the file.
         If found, write from current position to OFF, inclusive.
         Otherwise, just return true.  */

      return (size <= current_pos
              || elide_tail_lines_seekable (filename, fd, n_elide,
                                            current_pos, size));
    }
}

static bool
head_bytes (const char *filename, int fd, uintmax_t bytes_to_write)
{
  char buffer[BUFSIZ];
  size_t bytes_to_read = BUFSIZ;

  while (bytes_to_write)
    {
      size_t bytes_read;
      if (bytes_to_write < bytes_to_read)
        bytes_to_read = bytes_to_write;
      bytes_read = safe_read (fd, buffer, bytes_to_read);
      if (bytes_read == SAFE_READ_ERROR)
        {
          error (0, errno, _("error reading %s"), quoteaf (filename));
          return false;
        }
      if (bytes_read == 0)
        break;
      xwrite_stdout (buffer, bytes_read);
      bytes_to_write -= bytes_read;
    }
  return true;
}

static bool
head_lines (const char *filename, int fd, uintmax_t lines_to_write)
{
  char buffer[BUFSIZ];

  while (lines_to_write)
    {
      size_t bytes_read = safe_read (fd, buffer, BUFSIZ);
      size_t bytes_to_write = 0;

      if (bytes_read == SAFE_READ_ERROR)
        {
          error (0, errno, _("error reading %s"), quoteaf (filename));
          return false;
        }
      if (bytes_read == 0)
        break;
      while (bytes_to_write < bytes_read)
        if (buffer[bytes_to_write++] == line_end && --lines_to_write == 0)
          {
            off_t n_bytes_past_EOL = bytes_read - bytes_to_write;
            /* If we have read more data than that on the specified number
               of lines, try to seek back to the position we would have
               gotten to had we been reading one byte at a time.  */
            if (lseek (fd, -n_bytes_past_EOL, SEEK_CUR) < 0)
              {
                struct stat st;
                if (fstat (fd, &st) != 0 || S_ISREG (st.st_mode))
                  elseek (fd, -n_bytes_past_EOL, SEEK_CUR, filename);
              }
            break;
          }
      xwrite_stdout (buffer, bytes_to_write);
    }
  return true;
}

static bool
head (const char *filename, int fd, uintmax_t n_units, bool count_lines,
      bool elide_from_end)
{
  if (print_headers)
    write_header (filename);

  if (elide_from_end)
    {
      off_t current_pos = -1;
      struct stat st;
      if (fstat (fd, &st) != 0)
        {
          error (0, errno, _("cannot fstat %s"),
                 quoteaf (filename));
          return false;
        }
      if (! presume_input_pipe && usable_st_size (&st))
        {
          current_pos = elseek (fd, 0, SEEK_CUR, filename);
          if (current_pos < 0)
            return false;
        }
      if (count_lines)
        return elide_tail_lines_file (filename, fd, n_units, &st, current_pos);
      else
        return elide_tail_bytes_file (filename, fd, n_units, &st, current_pos);
    }
  if (count_lines)
    return head_lines (filename, fd, n_units);
  else
    return head_bytes (filename, fd, n_units);
}

static bool
head_file (const char *filename, uintmax_t n_units, bool count_lines,
           bool elide_from_end)
{
  int fd;
  bool ok;
  bool is_stdin = STREQ (filename, "-");

  if (is_stdin)
    {
      have_read_stdin = true;
      fd = STDIN_FILENO;
      filename = _("standard input");
      xset_binary_mode (STDIN_FILENO, O_BINARY);
    }
  else
    {
      fd = open (filename, O_RDONLY | O_BINARY);
      if (fd < 0)
        {
          error (0, errno, _("cannot open %s for reading"), quoteaf (filename));
          return false;
        }
    }

  ok = head (filename, fd, n_units, count_lines, elide_from_end);
  if (!is_stdin && close (fd) != 0)
    {
      error (0, errno, _("failed to close %s"), quoteaf (filename));
      return false;
    }
  return ok;
}

/* Convert a string of decimal digits, N_STRING, with an optional suffix
   to an integral value.  Upon successful conversion,
   return that value.  If it cannot be converted, give a diagnostic and exit.
   COUNT_LINES indicates whether N_STRING is a number of bytes or a number
   of lines.  It is used solely to give a more specific diagnostic.  */

static uintmax_t
string_to_integer (bool count_lines, const char *n_string)
{
  return xdectoumax (n_string, 0, UINTMAX_MAX, "bkKmMGTPEZY0",
                     count_lines ? _("invalid number of lines")
                                 : _("invalid number of bytes"), 0);
}

int
main (int argc, char **argv)
{
  enum header_mode header_mode = multiple_files;
  bool ok = true;
  int c;
  size_t i;

  /* Number of items to print. */
  uintmax_t n_units = DEFAULT_NUMBER;

  /* If true, interpret the numeric argument as the number of lines.
     Otherwise, interpret it as the number of bytes.  */
  bool count_lines = true;

  /* Elide the specified number of lines or bytes, counting from
     the end of the file.  */
  bool elide_from_end = false;

  /* Initializer for file_list if no file-arguments
     were specified on the command line.  */
  static char const *const default_file_list[] = {"-", NULL};
  char const *const *file_list;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdout);

  have_read_stdin = false;

  print_headers = false;

  line_end = '\n';

  if (1 < argc && argv[1][0] == '-' && ISDIGIT (argv[1][1]))
    {
      char *a = argv[1];
      char *n_string = ++a;
      char *end_n_string;
      char multiplier_char = 0;

      /* Old option syntax; a dash, one or more digits, and one or
         more option letters.  Move past the number. */
      do ++a;
      while (ISDIGIT (*a));

      /* Pointer to the byte after the last digit.  */
      end_n_string = a;

      /* Parse any appended option letters. */
      for (; *a; a++)
        {
          switch (*a)
            {
            case 'c':
              count_lines = false;
              multiplier_char = 0;
              break;

            case 'b':
            case 'k':
            case 'm':
              count_lines = false;
              multiplier_char = *a;
              break;

            case 'l':
              count_lines = true;
              break;

            case 'q':
              header_mode = never;
              break;

            case 'v':
              header_mode = always;
              break;

            case 'z':
              line_end = '\0';
              break;

            default:
              error (0, 0, _("invalid trailing option -- %c"), *a);
              usage (EXIT_FAILURE);
            }
        }

      /* Append the multiplier character (if any) onto the end of
         the digit string.  Then add NUL byte if necessary.  */
      *end_n_string = multiplier_char;
      if (multiplier_char)
        *(++end_n_string) = 0;

      n_units = string_to_integer (count_lines, n_string);

      /* Make the options we just parsed invisible to getopt. */
      argv[1] = argv[0];
      argv++;
      argc--;
    }

  while ((c = getopt_long (argc, argv, "c:n:qvz0123456789", long_options, NULL))
         != -1)
    {
      switch (c)
        {
        case PRESUME_INPUT_PIPE_OPTION:
          presume_input_pipe = true;
          break;

        case 'c':
          count_lines = false;
          elide_from_end = (*optarg == '-');
          if (elide_from_end)
            ++optarg;
          n_units = string_to_integer (count_lines, optarg);
          break;

        case 'n':
          count_lines = true;
          elide_from_end = (*optarg == '-');
          if (elide_from_end)
            ++optarg;
          n_units = string_to_integer (count_lines, optarg);
          break;

        case 'q':
          header_mode = never;
          break;

        case 'v':
          header_mode = always;
          break;

        case 'z':
          line_end = '\0';
          break;

        case_GETOPT_HELP_CHAR;

        case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);

        default:
          if (ISDIGIT (c))
            error (0, 0, _("invalid trailing option -- %c"), c);
          usage (EXIT_FAILURE);
        }
    }

  if (header_mode == always
      || (header_mode == multiple_files && optind < argc - 1))
    print_headers = true;

  if ( ! count_lines && elide_from_end && OFF_T_MAX < n_units)
    {
      char umax_buf[INT_BUFSIZE_BOUND (n_units)];
      die (EXIT_FAILURE, EOVERFLOW, "%s: %s", _("invalid number of bytes"),
           quote (umaxtostr (n_units, umax_buf)));
    }

  file_list = (optind < argc
               ? (char const *const *) &argv[optind]
               : default_file_list);

  xset_binary_mode (STDOUT_FILENO, O_BINARY);

  for (i = 0; file_list[i]; ++i)
    ok &= head_file (file_list[i], n_units, count_lines, elide_from_end);

  if (have_read_stdin && close (STDIN_FILENO) < 0)
    die (EXIT_FAILURE, errno, "-");

  return ok ? EXIT_SUCCESS : EXIT_FAILURE;
}
