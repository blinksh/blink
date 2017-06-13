/* tail -- output the last part of file(s)
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

/* Can display any amount of data, unlike the Unix version, which uses
   a fixed size buffer and therefore can only deliver a limited number
   of lines.

   Original version by Paul Rubin <phr@ocf.berkeley.edu>.
   Extensions by David MacKenzie <djm@gnu.ai.mit.edu>.
   tail -f for multiple files by Ian Lance Taylor <ian@airs.com>.
   inotify back-end by Giuseppe Scrivano <gscrivano@gnu.org>.  */

#include <config.h>

#include <stdio.h>
#include <assert.h>
#include <getopt.h>
#include <sys/types.h>
#include <signal.h>

#include "system.h"
#include "argmatch.h"
#include "c-strtod.h"
#include "die.h"
#include "error.h"
#include "fcntl--.h"
#include "isapipe.h"
#include "posixver.h"
#include "quote.h"
#include "safe-read.h"
#include "stat-size.h"
#include "stat-time.h"
#include "xbinary-io.h"
#include "xdectoint.h"
#include "xnanosleep.h"
#include "xstrtol.h"
#include "xstrtod.h"

#if HAVE_INOTIFY
# include "hash.h"
# include <sys/inotify.h>
/* 'select' is used by tail_forever_inotify.  */
# include <sys/select.h>

/* inotify needs to know if a file is local.  */
# include "fs.h"
# include "fs-is-local.h"
# if HAVE_SYS_STATFS_H
#  include <sys/statfs.h>
# elif HAVE_SYS_VFS_H
#  include <sys/vfs.h>
# endif
#endif

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "tail"

#define AUTHORS \
  proper_name ("Paul Rubin"), \
  proper_name ("David MacKenzie"), \
  proper_name ("Ian Lance Taylor"), \
  proper_name ("Jim Meyering")

/* Number of items to tail.  */
#define DEFAULT_N_LINES 10

/* Special values for dump_remainder's N_BYTES parameter.  */
#define COPY_TO_EOF UINTMAX_MAX
#define COPY_A_BUFFER (UINTMAX_MAX - 1)

/* FIXME: make Follow_name the default?  */
#define DEFAULT_FOLLOW_MODE Follow_descriptor

enum Follow_mode
{
  /* Follow the name of each file: if the file is renamed, try to reopen
     that name and track the end of the new file if/when it's recreated.
     This is useful for tracking logs that are occasionally rotated.  */
  Follow_name = 1,

  /* Follow each descriptor obtained upon opening a file.
     That means we'll continue to follow the end of a file even after
     it has been renamed or unlinked.  */
  Follow_descriptor = 2
};

/* The types of files for which tail works.  */
#define IS_TAILABLE_FILE_TYPE(Mode) \
  (S_ISREG (Mode) || S_ISFIFO (Mode) || S_ISSOCK (Mode) || S_ISCHR (Mode))

static char const *const follow_mode_string[] =
{
  "descriptor", "name", NULL
};

static enum Follow_mode const follow_mode_map[] =
{
  Follow_descriptor, Follow_name,
};

struct File_spec
{
  /* The actual file name, or "-" for stdin.  */
  char *name;

  /* Attributes of the file the last time we checked.  */
  off_t size;
  struct timespec mtime;
  dev_t dev;
  ino_t ino;
  mode_t mode;

  /* The specified name initially referred to a directory or some other
     type for which tail isn't meaningful.  Unlike for a permission problem
     (tailable, below) once this is set, the name is not checked ever again.  */
  bool ignore;

  /* See the description of fremote.  */
  bool remote;

  /* A file is tailable if it exists, is readable, and is of type
     IS_TAILABLE_FILE_TYPE.  */
  bool tailable;

  /* File descriptor on which the file is open; -1 if it's not open.  */
  int fd;

  /* The value of errno seen last time we checked this file.  */
  int errnum;

  /* 1 if O_NONBLOCK is clear, 0 if set, -1 if not known.  */
  int blocking;

#if HAVE_INOTIFY
  /* The watch descriptor used by inotify.  */
  int wd;

  /* The parent directory watch descriptor.  It is used only
   * when Follow_name is used.  */
  int parent_wd;

  /* Offset in NAME of the basename part.  */
  size_t basename_start;
#endif

  /* See description of DEFAULT_MAX_N_... below.  */
  uintmax_t n_unchanged_stats;
};

/* Keep trying to open a file even if it is inaccessible when tail starts
   or if it becomes inaccessible later -- useful only with -f.  */
static bool reopen_inaccessible_files;

/* If true, interpret the numeric argument as the number of lines.
   Otherwise, interpret it as the number of bytes.  */
static bool count_lines;

/* Whether we follow the name of each file or the file descriptor
   that is initially associated with each name.  */
static enum Follow_mode follow_mode = Follow_descriptor;

/* If true, read from the ends of all specified files until killed.  */
static bool forever;

/* If true, count from start of file instead of end.  */
static bool from_start;

/* If true, print filename headers.  */
static bool print_headers;

/* Character to split lines by. */
static char line_end;

/* When to print the filename banners.  */
enum header_mode
{
  multiple_files, always, never
};

/* When tailing a file by name, if there have been this many consecutive
   iterations for which the file has not changed, then open/fstat
   the file to determine if that file name is still associated with the
   same device/inode-number pair as before.  This option is meaningful only
   when following by name.  --max-unchanged-stats=N  */
#define DEFAULT_MAX_N_UNCHANGED_STATS_BETWEEN_OPENS 5
static uintmax_t max_n_unchanged_stats_between_opens =
  DEFAULT_MAX_N_UNCHANGED_STATS_BETWEEN_OPENS;

/* The process ID of the process (presumably on the current host)
   that is writing to all followed files.  */
static pid_t pid;

/* True if we have ever read standard input.  */
static bool have_read_stdin;

/* If nonzero, skip the is-regular-file test used to determine whether
   to use the lseek optimization.  Instead, use the more general (and
   more expensive) code unconditionally. Intended solely for testing.  */
static bool presume_input_pipe;

/* If nonzero then don't use inotify even if available.  */
static bool disable_inotify;

/* For long options that have no equivalent short option, use a
   non-character as a pseudo short option, starting with CHAR_MAX + 1.  */
enum
{
  RETRY_OPTION = CHAR_MAX + 1,
  MAX_UNCHANGED_STATS_OPTION,
  PID_OPTION,
  PRESUME_INPUT_PIPE_OPTION,
  LONG_FOLLOW_OPTION,
  DISABLE_INOTIFY_OPTION
};

static struct option const long_options[] =
{
  {"bytes", required_argument, NULL, 'c'},
  {"follow", optional_argument, NULL, LONG_FOLLOW_OPTION},
  {"lines", required_argument, NULL, 'n'},
  {"max-unchanged-stats", required_argument, NULL, MAX_UNCHANGED_STATS_OPTION},
  {"-disable-inotify", no_argument, NULL,
   DISABLE_INOTIFY_OPTION}, /* do not document */
  {"pid", required_argument, NULL, PID_OPTION},
  {"-presume-input-pipe", no_argument, NULL,
   PRESUME_INPUT_PIPE_OPTION}, /* do not document */
  {"quiet", no_argument, NULL, 'q'},
  {"retry", no_argument, NULL, RETRY_OPTION},
  {"silent", no_argument, NULL, 'q'},
  {"sleep-interval", required_argument, NULL, 's'},
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
Print the last %d lines of each FILE to standard output.\n\
With more than one FILE, precede each with a header giving the file name.\n\
"), DEFAULT_N_LINES);

      emit_stdin_note ();
      emit_mandatory_arg_note ();

     fputs (_("\
  -c, --bytes=[+]NUM       output the last NUM bytes; or use -c +NUM to\n\
                             output starting with byte NUM of each file\n\
"), stdout);
     fputs (_("\
  -f, --follow[={name|descriptor}]\n\
                           output appended data as the file grows;\n\
                             an absent option argument means 'descriptor'\n\
  -F                       same as --follow=name --retry\n\
"), stdout);
     printf (_("\
  -n, --lines=[+]NUM       output the last NUM lines, instead of the last %d;\n\
                             or use -n +NUM to output starting with line NUM\n\
      --max-unchanged-stats=N\n\
                           with --follow=name, reopen a FILE which has not\n\
                             changed size after N (default %d) iterations\n\
                             to see if it has been unlinked or renamed\n\
                             (this is the usual case of rotated log files);\n\
                             with inotify, this option is rarely useful\n\
"),
             DEFAULT_N_LINES,
             DEFAULT_MAX_N_UNCHANGED_STATS_BETWEEN_OPENS
             );
     fputs (_("\
      --pid=PID            with -f, terminate after process ID, PID dies\n\
  -q, --quiet, --silent    never output headers giving file names\n\
      --retry              keep trying to open a file if it is inaccessible\n\
"), stdout);
     fputs (_("\
  -s, --sleep-interval=N   with -f, sleep for approximately N seconds\n\
                             (default 1.0) between iterations;\n\
                             with inotify and --pid=P, check process P at\n\
                             least once every N seconds\n\
  -v, --verbose            always output headers giving file names\n\
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
\n\
"), stdout);
     fputs (_("\
With --follow (-f), tail defaults to following the file descriptor, which\n\
means that even if a tail'ed file is renamed, tail will continue to track\n\
its end.  This default behavior is not desirable when you really want to\n\
track the actual name of the file, not the file descriptor (e.g., log\n\
rotation).  Use --follow=name in that case.  That causes tail to track the\n\
named file in a way that accommodates renaming, removal and creation.\n\
"), stdout);
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}

static bool
valid_file_spec (struct File_spec const *f)
{
  /* Exactly one of the following subexpressions must be true. */
  return ((f->fd == -1) ^ (f->errnum == 0));
}

static char const *
pretty_name (struct File_spec const *f)
{
  return (STREQ (f->name, "-") ? _("standard input") : f->name);
}

/* Record a file F with descriptor FD, size SIZE, status ST, and
   blocking status BLOCKING.  */

static void
record_open_fd (struct File_spec *f, int fd,
                off_t size, struct stat const *st,
                int blocking)
{
  f->fd = fd;
  f->size = size;
  f->mtime = get_stat_mtime (st);
  f->dev = st->st_dev;
  f->ino = st->st_ino;
  f->mode = st->st_mode;
  f->blocking = blocking;
  f->n_unchanged_stats = 0;
  f->ignore = false;
}

/* Close the file with descriptor FD and name FILENAME.  */

static void
close_fd (int fd, const char *filename)
{
  if (fd != -1 && fd != STDIN_FILENO && close (fd))
    {
      error (0, errno, _("closing %s (fd=%d)"), quoteaf (filename), fd);
    }
}

static void
write_header (const char *pretty_filename)
{
  static bool first_file = true;

  printf ("%s==> %s <==\n", (first_file ? "" : "\n"), pretty_filename);
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

/* Read and output N_BYTES of file PRETTY_FILENAME starting at the current
   position in FD.  If N_BYTES is COPY_TO_EOF, then copy until end of file.
   If N_BYTES is COPY_A_BUFFER, then copy at most one buffer's worth.
   Return the number of bytes read from the file.  */

static uintmax_t
dump_remainder (bool want_header, const char *pretty_filename, int fd,
                uintmax_t n_bytes)
{
  uintmax_t n_written;
  uintmax_t n_remaining = n_bytes;

  n_written = 0;
  while (1)
    {
      char buffer[BUFSIZ];
      size_t n = MIN (n_remaining, BUFSIZ);
      size_t bytes_read = safe_read (fd, buffer, n);
      if (bytes_read == SAFE_READ_ERROR)
        {
          if (errno != EAGAIN)
            die (EXIT_FAILURE, errno, _("error reading %s"),
                 quoteaf (pretty_filename));
          break;
        }
      if (bytes_read == 0)
        break;
      if (want_header)
        {
          write_header (pretty_filename);
          want_header = false;
        }
      xwrite_stdout (buffer, bytes_read);
      n_written += bytes_read;
      if (n_bytes != COPY_TO_EOF)
        {
          n_remaining -= bytes_read;
          if (n_remaining == 0 || n_bytes == COPY_A_BUFFER)
            break;
        }
    }

  return n_written;
}

/* Call lseek with the specified arguments, where file descriptor FD
   corresponds to the file, FILENAME.
   Give a diagnostic and exit nonzero if lseek fails.
   Otherwise, return the resulting offset.  */

static off_t
xlseek (int fd, off_t offset, int whence, char const *filename)
{
  off_t new_offset = lseek (fd, offset, whence);
  char buf[INT_BUFSIZE_BOUND (offset)];
  char *s;

  if (0 <= new_offset)
    return new_offset;

  s = offtostr (offset, buf);
  switch (whence)
    {
    case SEEK_SET:
      error (0, errno, _("%s: cannot seek to offset %s"),
             quotef (filename), s);
      break;
    case SEEK_CUR:
      error (0, errno, _("%s: cannot seek to relative offset %s"),
             quotef (filename), s);
      break;
    case SEEK_END:
      error (0, errno, _("%s: cannot seek to end-relative offset %s"),
             quotef (filename), s);
      break;
    default:
      abort ();
    }

  exit (EXIT_FAILURE);
}

/* Print the last N_LINES lines from the end of file FD.
   Go backward through the file, reading 'BUFSIZ' bytes at a time (except
   probably the first), until we hit the start of the file or have
   read NUMBER newlines.
   START_POS is the starting position of the read pointer for the file
   associated with FD (may be nonzero).
   END_POS is the file offset of EOF (one larger than offset of last byte).
   Return true if successful.  */

static bool
file_lines (const char *pretty_filename, int fd, uintmax_t n_lines,
            off_t start_pos, off_t end_pos, uintmax_t *read_pos)
{
  char buffer[BUFSIZ];
  size_t bytes_read;
  off_t pos = end_pos;

  if (n_lines == 0)
    return true;

  /* Set 'bytes_read' to the size of the last, probably partial, buffer;
     0 < 'bytes_read' <= 'BUFSIZ'.  */
  bytes_read = (pos - start_pos) % BUFSIZ;
  if (bytes_read == 0)
    bytes_read = BUFSIZ;
  /* Make 'pos' a multiple of 'BUFSIZ' (0 if the file is short), so that all
     reads will be on block boundaries, which might increase efficiency.  */
  pos -= bytes_read;
  xlseek (fd, pos, SEEK_SET, pretty_filename);
  bytes_read = safe_read (fd, buffer, bytes_read);
  if (bytes_read == SAFE_READ_ERROR)
    {
      error (0, errno, _("error reading %s"), quoteaf (pretty_filename));
      return false;
    }
  *read_pos = pos + bytes_read;

  /* Count the incomplete line on files that don't end with a newline.  */
  if (bytes_read && buffer[bytes_read - 1] != line_end)
    --n_lines;

  do
    {
      /* Scan backward, counting the newlines in this bufferfull.  */

      size_t n = bytes_read;
      while (n)
        {
          char const *nl;
          nl = memrchr (buffer, line_end, n);
          if (nl == NULL)
            break;
          n = nl - buffer;
          if (n_lines-- == 0)
            {
              /* If this newline isn't the last character in the buffer,
                 output the part that is after it.  */
              if (n != bytes_read - 1)
                xwrite_stdout (nl + 1, bytes_read - (n + 1));
              *read_pos += dump_remainder (false, pretty_filename, fd,
                                           end_pos - (pos + bytes_read));
              return true;
            }
        }

      /* Not enough newlines in that bufferfull.  */
      if (pos == start_pos)
        {
          /* Not enough lines in the file; print everything from
             start_pos to the end.  */
          xlseek (fd, start_pos, SEEK_SET, pretty_filename);
          *read_pos = start_pos + dump_remainder (false, pretty_filename, fd,
                                                  end_pos);
          return true;
        }
      pos -= BUFSIZ;
      xlseek (fd, pos, SEEK_SET, pretty_filename);

      bytes_read = safe_read (fd, buffer, BUFSIZ);
      if (bytes_read == SAFE_READ_ERROR)
        {
          error (0, errno, _("error reading %s"), quoteaf (pretty_filename));
          return false;
        }

      *read_pos = pos + bytes_read;
    }
  while (bytes_read > 0);

  return true;
}

/* Print the last N_LINES lines from the end of the standard input,
   open for reading as pipe FD.
   Buffer the text as a linked list of LBUFFERs, adding them as needed.
   Return true if successful.  */

static bool
pipe_lines (const char *pretty_filename, int fd, uintmax_t n_lines,
            uintmax_t *read_pos)
{
  struct linebuffer
  {
    char buffer[BUFSIZ];
    size_t nbytes;
    size_t nlines;
    struct linebuffer *next;
  };
  typedef struct linebuffer LBUFFER;
  LBUFFER *first, *last, *tmp;
  size_t total_lines = 0;	/* Total number of newlines in all buffers.  */
  bool ok = true;
  size_t n_read;		/* Size in bytes of most recent read */

  first = last = xmalloc (sizeof (LBUFFER));
  first->nbytes = first->nlines = 0;
  first->next = NULL;
  tmp = xmalloc (sizeof (LBUFFER));

  /* Input is always read into a fresh buffer.  */
  while (1)
    {
      n_read = safe_read (fd, tmp->buffer, BUFSIZ);
      if (n_read == 0 || n_read == SAFE_READ_ERROR)
        break;
      tmp->nbytes = n_read;
      *read_pos += n_read;
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
          if (total_lines - first->nlines > n_lines)
            {
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
      error (0, errno, _("error reading %s"), quoteaf (pretty_filename));
      ok = false;
      goto free_lbuffers;
    }

  /* If the file is empty, then bail out.  */
  if (last->nbytes == 0)
    goto free_lbuffers;

  /* This prevents a core dump when the pipe contains no newlines.  */
  if (n_lines == 0)
    goto free_lbuffers;

  /* Count the incomplete line on files that don't end with a newline.  */
  if (last->buffer[last->nbytes - 1] != line_end)
    {
      ++last->nlines;
      ++total_lines;
    }

  /* Run through the list, printing lines.  First, skip over unneeded
     buffers.  */
  for (tmp = first; total_lines - tmp->nlines > n_lines; tmp = tmp->next)
    total_lines -= tmp->nlines;

  /* Find the correct beginning, then print the rest of the file.  */
  {
    char const *beg = tmp->buffer;
    char const *buffer_end = tmp->buffer + tmp->nbytes;
    if (total_lines > n_lines)
      {
        /* Skip 'total_lines' - 'n_lines' newlines.  We made sure that
           'total_lines' - 'n_lines' <= 'tmp->nlines'.  */
        size_t j;
        for (j = total_lines - n_lines; j; --j)
          {
            beg = memchr (beg, line_end, buffer_end - beg);
            assert (beg);
            ++beg;
          }
      }

    xwrite_stdout (beg, buffer_end - beg);
  }

  for (tmp = tmp->next; tmp; tmp = tmp->next)
    xwrite_stdout (tmp->buffer, tmp->nbytes);

free_lbuffers:
  while (first)
    {
      tmp = first->next;
      free (first);
      first = tmp;
    }
  return ok;
}

/* Print the last N_BYTES characters from the end of pipe FD.
   This is a stripped down version of pipe_lines.
   Return true if successful.  */

static bool
pipe_bytes (const char *pretty_filename, int fd, uintmax_t n_bytes,
            uintmax_t *read_pos)
{
  struct charbuffer
  {
    char buffer[BUFSIZ];
    size_t nbytes;
    struct charbuffer *next;
  };
  typedef struct charbuffer CBUFFER;
  CBUFFER *first, *last, *tmp;
  size_t i;			/* Index into buffers.  */
  size_t total_bytes = 0;	/* Total characters in all buffers.  */
  bool ok = true;
  size_t n_read;

  first = last = xmalloc (sizeof (CBUFFER));
  first->nbytes = 0;
  first->next = NULL;
  tmp = xmalloc (sizeof (CBUFFER));

  /* Input is always read into a fresh buffer.  */
  while (1)
    {
      n_read = safe_read (fd, tmp->buffer, BUFSIZ);
      if (n_read == 0 || n_read == SAFE_READ_ERROR)
        break;
      *read_pos += n_read;
      tmp->nbytes = n_read;
      tmp->next = NULL;

      total_bytes += tmp->nbytes;
      /* If there is enough room in the last buffer read, just append the new
         one to it.  This is because when reading from a pipe, 'nbytes' can
         often be very small.  */
      if (tmp->nbytes + last->nbytes < BUFSIZ)
        {
          memcpy (&last->buffer[last->nbytes], tmp->buffer, tmp->nbytes);
          last->nbytes += tmp->nbytes;
        }
      else
        {
          /* If there's not enough room, link the new buffer onto the end of
             the list, then either free up the oldest buffer for the next
             read if that would leave enough characters, or else malloc a new
             one.  Some compaction mechanism is possible but probably not
             worthwhile.  */
          last = last->next = tmp;
          if (total_bytes - first->nbytes > n_bytes)
            {
              tmp = first;
              total_bytes -= first->nbytes;
              first = first->next;
            }
          else
            {
              tmp = xmalloc (sizeof (CBUFFER));
            }
        }
    }

  free (tmp);

  if (n_read == SAFE_READ_ERROR)
    {
      error (0, errno, _("error reading %s"), quoteaf (pretty_filename));
      ok = false;
      goto free_cbuffers;
    }

  /* Run through the list, printing characters.  First, skip over unneeded
     buffers.  */
  for (tmp = first; total_bytes - tmp->nbytes > n_bytes; tmp = tmp->next)
    total_bytes -= tmp->nbytes;

  /* Find the correct beginning, then print the rest of the file.
     We made sure that 'total_bytes' - 'n_bytes' <= 'tmp->nbytes'.  */
  if (total_bytes > n_bytes)
    i = total_bytes - n_bytes;
  else
    i = 0;
  xwrite_stdout (&tmp->buffer[i], tmp->nbytes - i);

  for (tmp = tmp->next; tmp; tmp = tmp->next)
    xwrite_stdout (tmp->buffer, tmp->nbytes);

free_cbuffers:
  while (first)
    {
      tmp = first->next;
      free (first);
      first = tmp;
    }
  return ok;
}

/* Skip N_BYTES characters from the start of pipe FD, and print
   any extra characters that were read beyond that.
   Return 1 on error, 0 if ok, -1 if EOF.  */

static int
start_bytes (const char *pretty_filename, int fd, uintmax_t n_bytes,
             uintmax_t *read_pos)
{
  char buffer[BUFSIZ];

  while (0 < n_bytes)
    {
      size_t bytes_read = safe_read (fd, buffer, BUFSIZ);
      if (bytes_read == 0)
        return -1;
      if (bytes_read == SAFE_READ_ERROR)
        {
          error (0, errno, _("error reading %s"), quoteaf (pretty_filename));
          return 1;
        }
      *read_pos += bytes_read;
      if (bytes_read <= n_bytes)
        n_bytes -= bytes_read;
      else
        {
          size_t n_remaining = bytes_read - n_bytes;
          if (n_remaining)
            xwrite_stdout (&buffer[n_bytes], n_remaining);
          break;
        }
    }

  return 0;
}

/* Skip N_LINES lines at the start of file or pipe FD, and print
   any extra characters that were read beyond that.
   Return 1 on error, 0 if ok, -1 if EOF.  */

static int
start_lines (const char *pretty_filename, int fd, uintmax_t n_lines,
             uintmax_t *read_pos)
{
  if (n_lines == 0)
    return 0;

  while (1)
    {
      char buffer[BUFSIZ];
      size_t bytes_read = safe_read (fd, buffer, BUFSIZ);
      if (bytes_read == 0) /* EOF */
        return -1;
      if (bytes_read == SAFE_READ_ERROR) /* error */
        {
          error (0, errno, _("error reading %s"), quoteaf (pretty_filename));
          return 1;
        }

      char *buffer_end = buffer + bytes_read;

      *read_pos += bytes_read;

      char *p = buffer;
      while ((p = memchr (p, line_end, buffer_end - p)))
        {
          ++p;
          if (--n_lines == 0)
            {
              if (p < buffer_end)
                xwrite_stdout (p, buffer_end - p);
              return 0;
            }
        }
    }
}

/* Return false when FD is open on a file residing on a local file system.
   If fstatfs fails, give a diagnostic and return true.
   If fstatfs cannot be called, return true.  */
static bool
fremote (int fd, const char *name)
{
  bool remote = true;           /* be conservative (poll by default).  */

#if HAVE_FSTATFS && HAVE_STRUCT_STATFS_F_TYPE && defined __linux__
  struct statfs buf;
  int err = fstatfs (fd, &buf);
  if (err != 0)
    {
      /* On at least linux-2.6.38, fstatfs fails with ENOSYS when FD
         is open on a pipe.  Treat that like a remote file.  */
      if (errno != ENOSYS)
        error (0, errno, _("cannot determine location of %s. "
                           "reverting to polling"), quoteaf (name));
    }
  else
    {
      switch (is_local_fs_type (buf.f_type))
        {
        case 0:
          break;
        case -1:
          /* Treat unrecognized file systems as "remote", so caller polls.
             Note README-release has instructions for syncing the internal
             list with the latest Linux kernel file system constants.  */
          break;
        case 1:
          remote = false;
          break;
        default:
          assert (!"unexpected return value from is_local_fs_type");
        }
    }
#endif

  return remote;
}

/* open/fstat F->name and handle changes.  */
static void
recheck (struct File_spec *f, bool blocking)
{
  struct stat new_stats;
  bool ok = true;
  bool is_stdin = (STREQ (f->name, "-"));
  bool was_tailable = f->tailable;
  int prev_errnum = f->errnum;
  bool new_file;
  int fd = (is_stdin
            ? STDIN_FILENO
            : open (f->name, O_RDONLY | (blocking ? 0 : O_NONBLOCK)));

  assert (valid_file_spec (f));

  /* If the open fails because the file doesn't exist,
     then mark the file as not tailable.  */
  f->tailable = !(reopen_inaccessible_files && fd == -1);

  if (! disable_inotify && ! lstat (f->name, &new_stats)
      && S_ISLNK (new_stats.st_mode))
    {
      /* Diagnose the edge case where a regular file is changed
         to a symlink.  We avoid inotify with symlinks since
         it's awkward to match between symlink name and target.  */
      ok = false;
      f->errnum = -1;
      f->ignore = true;

      error (0, 0, _("%s has been replaced with an untailable symbolic link"),
             quoteaf (pretty_name (f)));
    }
  else if (fd == -1 || fstat (fd, &new_stats) < 0)
    {
      ok = false;
      f->errnum = errno;
      if (!f->tailable)
        {
          if (was_tailable)
            {
              /* FIXME-maybe: detect the case in which the file first becomes
                 unreadable (perms), and later becomes readable again and can
                 be seen to be the same file (dev/ino).  Otherwise, tail prints
                 the entire contents of the file when it becomes readable.  */
              error (0, f->errnum, _("%s has become inaccessible"),
                     quoteaf (pretty_name (f)));
            }
          else
            {
              /* say nothing... it's still not tailable */
            }
        }
      else if (prev_errnum != errno)
        error (0, errno, "%s", quotef (pretty_name (f)));
    }
  else if (!IS_TAILABLE_FILE_TYPE (new_stats.st_mode))
    {
      ok = false;
      f->errnum = -1;
      f->tailable = false;
      f->ignore = ! (reopen_inaccessible_files && follow_mode == Follow_name);
      if (was_tailable || prev_errnum != f->errnum)
        error (0, 0, _("%s has been replaced with an untailable file%s"),
               quoteaf (pretty_name (f)),
               f->ignore ? _("; giving up on this name") : "");
    }
  else if ((f->remote = fremote (fd, pretty_name (f))) && ! disable_inotify)
    {
      ok = false;
      f->errnum = -1;
      error (0, 0, _("%s has been replaced with an untailable remote file"),
             quoteaf (pretty_name (f)));
      f->ignore = true;
      f->remote = true;
    }
  else
    {
      f->errnum = 0;
    }

  new_file = false;
  if (!ok)
    {
      close_fd (fd, pretty_name (f));
      close_fd (f->fd, pretty_name (f));
      f->fd = -1;
    }
  else if (prev_errnum && prev_errnum != ENOENT)
    {
      new_file = true;
      assert (f->fd == -1);
      error (0, 0, _("%s has become accessible"), quoteaf (pretty_name (f)));
    }
  else if (f->fd == -1)
    {
      /* A new file even when inodes haven't changed as <dev,inode>
         pairs can be reused, and we know the file was missing
         on the previous iteration.  Note this also means the file
         is redisplayed in --follow=name mode if renamed away from
         and back to a monitored name.  */
      new_file = true;

      error (0, 0,
             _("%s has appeared;  following new file"),
             quoteaf (pretty_name (f)));
    }
  else if (f->ino != new_stats.st_ino || f->dev != new_stats.st_dev)
    {
      /* File has been replaced (e.g., via log rotation) --
        tail the new one.  */
      new_file = true;

      error (0, 0,
             _("%s has been replaced;  following new file"),
             quoteaf (pretty_name (f)));

      /* Close the old one.  */
      close_fd (f->fd, pretty_name (f));

    }
  else
    {
      /* No changes detected, so close new fd.  */
      close_fd (fd, pretty_name (f));
    }

  /* FIXME: When a log is rotated, daemons tend to log to the
     old file descriptor until the new file is present and
     the daemon is sent a signal.  Therefore tail may miss entries
     being written to the old file.  Perhaps we should keep
     the older file open and continue to monitor it until
     data is written to a new file.  */
  if (new_file)
    {
      /* Start at the beginning of the file.  */
      record_open_fd (f, fd, 0, &new_stats, (is_stdin ? -1 : blocking));
      xlseek (fd, 0, SEEK_SET, pretty_name (f));
    }
}

/* Return true if any of the N_FILES files in F are live, i.e., have
   open file descriptors, or should be checked again (see --retry).
   When following descriptors, checking should only continue when any
   of the files is not yet ignored.  */

static bool
any_live_files (const struct File_spec *f, size_t n_files)
{
  size_t i;

  /* In inotify mode, ignore may be set for files
     which may later be replaced with new files.
     So always consider files live in -F mode.  */
  if (reopen_inaccessible_files && follow_mode == Follow_name)
    return true;

  for (i = 0; i < n_files; i++)
    {
      if (0 <= f[i].fd)
        return true;
      else
        {
          if (! f[i].ignore && reopen_inaccessible_files)
            return true;
        }
    }

  return false;
}

/* Tail N_FILES files forever, or until killed.
   The pertinent information for each file is stored in an entry of F.
   Loop over each of them, doing an fstat to see if they have changed size,
   and an occasional open/fstat to see if any dev/ino pair has changed.
   If none of them have changed size in one iteration, sleep for a
   while and try again.  Continue until the user interrupts us.  */

static void
tail_forever (struct File_spec *f, size_t n_files, double sleep_interval)
{
  /* Use blocking I/O as an optimization, when it's easy.  */
  bool blocking = (pid == 0 && follow_mode == Follow_descriptor
                   && n_files == 1 && f[0].fd != -1 && ! S_ISREG (f[0].mode));
  size_t last;
  bool writer_is_dead = false;

  last = n_files - 1;

  while (1)
    {
      size_t i;
      bool any_input = false;

      for (i = 0; i < n_files; i++)
        {
          int fd;
          char const *name;
          mode_t mode;
          struct stat stats;
          uintmax_t bytes_read;

          if (f[i].ignore)
            continue;

          if (f[i].fd < 0)
            {
              recheck (&f[i], blocking);
              continue;
            }

          fd = f[i].fd;
          name = pretty_name (&f[i]);
          mode = f[i].mode;

          if (f[i].blocking != blocking)
            {
              int old_flags = fcntl (fd, F_GETFL);
              int new_flags = old_flags | (blocking ? 0 : O_NONBLOCK);
              if (old_flags < 0
                  || (new_flags != old_flags
                      && fcntl (fd, F_SETFL, new_flags) == -1))
                {
                  /* Don't update f[i].blocking if fcntl fails.  */
                  if (S_ISREG (f[i].mode) && errno == EPERM)
                    {
                      /* This happens when using tail -f on a file with
                         the append-only attribute.  */
                    }
                  else
                    die (EXIT_FAILURE, errno,
                         _("%s: cannot change nonblocking mode"),
                         quotef (name));
                }
              else
                f[i].blocking = blocking;
            }

          if (!f[i].blocking)
            {
              if (fstat (fd, &stats) != 0)
                {
                  f[i].fd = -1;
                  f[i].errnum = errno;
                  error (0, errno, "%s", quotef (name));
                  close (fd); /* ignore failure */
                  continue;
                }

              if (f[i].mode == stats.st_mode
                  && (! S_ISREG (stats.st_mode) || f[i].size == stats.st_size)
                  && timespec_cmp (f[i].mtime, get_stat_mtime (&stats)) == 0)
                {
                  if ((max_n_unchanged_stats_between_opens
                       <= f[i].n_unchanged_stats++)
                      && follow_mode == Follow_name)
                    {
                      recheck (&f[i], f[i].blocking);
                      f[i].n_unchanged_stats = 0;
                    }
                  continue;
                }

              /* This file has changed.  Print out what we can, and
                 then keep looping.  */

              f[i].mtime = get_stat_mtime (&stats);
              f[i].mode = stats.st_mode;

              /* reset counter */
              f[i].n_unchanged_stats = 0;

              /* XXX: This is only a heuristic, as the file may have also
                 been truncated and written to if st_size >= size
                 (in which case we ignore new data <= size).  */
              if (S_ISREG (mode) && stats.st_size < f[i].size)
                {
                  error (0, 0, _("%s: file truncated"), quotef (name));
                  /* Assume the file was truncated to 0,
                     and therefore output all "new" data.  */
                  xlseek (fd, 0, SEEK_SET, name);
                  f[i].size = 0;
                }

              if (i != last)
                {
                  if (print_headers)
                    write_header (name);
                  last = i;
                }
            }

          /* Don't read more than st_size on networked file systems
             because it was seen on glusterfs at least, that st_size
             may be smaller than the data read on a _subsequent_ stat call.  */
          uintmax_t bytes_to_read;
          if (f[i].blocking)
            bytes_to_read = COPY_A_BUFFER;
          else if (S_ISREG (mode) && f[i].remote)
            bytes_to_read = stats.st_size - f[i].size;
          else
            bytes_to_read = COPY_TO_EOF;

          bytes_read = dump_remainder (false, name, fd, bytes_to_read);

          any_input |= (bytes_read != 0);
          f[i].size += bytes_read;
        }

      if (! any_live_files (f, n_files))
        {
          error (0, 0, _("no files remaining"));
          break;
        }

      if ((!any_input || blocking) && fflush (stdout) != 0)
        die (EXIT_FAILURE, errno, _("write error"));

      /* If nothing was read, sleep and/or check for dead writers.  */
      if (!any_input)
        {
          if (writer_is_dead)
            break;

          /* Once the writer is dead, read the files once more to
             avoid a race condition.  */
          writer_is_dead = (pid != 0
                            && kill (pid, 0) != 0
                            /* Handle the case in which you cannot send a
                               signal to the writer, so kill fails and sets
                               errno to EPERM.  */
                            && errno != EPERM);

          if (!writer_is_dead && xnanosleep (sleep_interval))
            die (EXIT_FAILURE, errno, _("cannot read realtime clock"));

        }
    }
}

#if HAVE_INOTIFY

/* Return true if any of the N_FILES files in F is remote, i.e., has
   an open file descriptor and is on a network file system.  */

static bool
any_remote_file (const struct File_spec *f, size_t n_files)
{
  size_t i;

  for (i = 0; i < n_files; i++)
    if (0 <= f[i].fd && f[i].remote)
      return true;
  return false;
}

/* Return true if any of the N_FILES files in F is non remote, i.e., has
   an open file descriptor and is not on a network file system.  */

static bool
any_non_remote_file (const struct File_spec *f, size_t n_files)
{
  size_t i;

  for (i = 0; i < n_files; i++)
    if (0 <= f[i].fd && ! f[i].remote)
      return true;
  return false;
}

/* Return true if any of the N_FILES files in F is a symlink.
   Note we don't worry about the edge case where "-" exists,
   since that will have the same consequences for inotify,
   which is the only context this function is currently used.  */

static bool
any_symlinks (const struct File_spec *f, size_t n_files)
{
  size_t i;

  struct stat st;
  for (i = 0; i < n_files; i++)
    if (lstat (f[i].name, &st) == 0 && S_ISLNK (st.st_mode))
      return true;
  return false;
}

/* Return true if any of the N_FILES files in F represents
   stdin and is tailable.  */

static bool
tailable_stdin (const struct File_spec *f, size_t n_files)
{
  size_t i;

  for (i = 0; i < n_files; i++)
    if (!f[i].ignore && STREQ (f[i].name, "-"))
      return true;
  return false;
}

static size_t
wd_hasher (const void *entry, size_t tabsize)
{
  const struct File_spec *spec = entry;
  return spec->wd % tabsize;
}

static bool
wd_comparator (const void *e1, const void *e2)
{
  const struct File_spec *spec1 = e1;
  const struct File_spec *spec2 = e2;
  return spec1->wd == spec2->wd;
}

/* Output (new) data for FSPEC->fd.
   PREV_FSPEC records the last File_spec for which we output.  */
static void
check_fspec (struct File_spec *fspec, struct File_spec **prev_fspec)
{
  struct stat stats;
  char const *name;

  if (fspec->fd == -1)
    return;

  name = pretty_name (fspec);

  if (fstat (fspec->fd, &stats) != 0)
    {
      fspec->errnum = errno;
      close_fd (fspec->fd, name);
      fspec->fd = -1;
      return;
    }

  /* XXX: This is only a heuristic, as the file may have also
     been truncated and written to if st_size >= size
     (in which case we ignore new data <= size).
     Though in the inotify case it's more likely we'll get
     separate events for truncate() and write().  */
  if (S_ISREG (fspec->mode) && stats.st_size < fspec->size)
    {
      error (0, 0, _("%s: file truncated"), quotef (name));
      xlseek (fspec->fd, 0, SEEK_SET, name);
      fspec->size = 0;
    }
  else if (S_ISREG (fspec->mode) && stats.st_size == fspec->size
           && timespec_cmp (fspec->mtime, get_stat_mtime (&stats)) == 0)
    return;

  bool want_header = print_headers && (fspec != *prev_fspec);

  uintmax_t bytes_read = dump_remainder (want_header, name, fspec->fd,
                                         COPY_TO_EOF);
  fspec->size += bytes_read;

  if (bytes_read)
    {
      *prev_fspec = fspec;
      if (fflush (stdout) != 0)
        die (EXIT_FAILURE, errno, _("write error"));
    }
}

/* Attempt to tail N_FILES files forever, or until killed.
   Check modifications using the inotify events system.
   Return false on error, or true to revert to polling.  */
static bool
tail_forever_inotify (int wd, struct File_spec *f, size_t n_files,
                      double sleep_interval)
{
# if TAIL_TEST_SLEEP
  /* Delay between open() and inotify_add_watch()
     to help trigger different cases.  */
  xnanosleep (1000000);
# endif
  unsigned int max_realloc = 3;

  /* Map an inotify watch descriptor to the name of the file it's watching.  */
  Hash_table *wd_to_name;

  bool found_watchable_file = false;
  bool tailed_but_unwatchable = false;
  bool found_unwatchable_dir = false;
  bool no_inotify_resources = false;
  bool writer_is_dead = false;
  struct File_spec *prev_fspec;
  size_t evlen = 0;
  char *evbuf;
  size_t evbuf_off = 0;
  size_t len = 0;

  wd_to_name = hash_initialize (n_files, NULL, wd_hasher, wd_comparator, NULL);
  if (! wd_to_name)
    xalloc_die ();

  /* The events mask used with inotify on files (not directories).  */
  uint32_t inotify_wd_mask = IN_MODIFY;
  /* TODO: Perhaps monitor these events in Follow_descriptor mode also,
     to tag reported file names with "deleted", "moved" etc.  */
  if (follow_mode == Follow_name)
    inotify_wd_mask |= (IN_ATTRIB | IN_DELETE_SELF | IN_MOVE_SELF);

  /* Add an inotify watch for each watched file.  If -F is specified then watch
     its parent directory too, in this way when they re-appear we can add them
     again to the watch list.  */
  size_t i;
  for (i = 0; i < n_files; i++)
    {
      if (!f[i].ignore)
        {
          size_t fnlen = strlen (f[i].name);
          if (evlen < fnlen)
            evlen = fnlen;

          f[i].wd = -1;

          if (follow_mode == Follow_name)
            {
              size_t dirlen = dir_len (f[i].name);
              char prev = f[i].name[dirlen];
              f[i].basename_start = last_component (f[i].name) - f[i].name;

              f[i].name[dirlen] = '\0';

               /* It's fine to add the same directory more than once.
                  In that case the same watch descriptor is returned.  */
              f[i].parent_wd = inotify_add_watch (wd, dirlen ? f[i].name : ".",
                                                  (IN_CREATE | IN_DELETE
                                                   | IN_MOVED_TO | IN_ATTRIB));

              f[i].name[dirlen] = prev;

              if (f[i].parent_wd < 0)
                {
                  if (errno != ENOSPC) /* suppress confusing error.  */
                    error (0, errno, _("cannot watch parent directory of %s"),
                           quoteaf (f[i].name));
                  else
                    error (0, 0, _("inotify resources exhausted"));
                  found_unwatchable_dir = true;
                  /* We revert to polling below.  Note invalid uses
                     of the inotify API will still be diagnosed.  */
                  break;
                }
            }

          f[i].wd = inotify_add_watch (wd, f[i].name, inotify_wd_mask);

          if (f[i].wd < 0)
            {
              if (f[i].fd != -1)  /* already tailed.  */
                tailed_but_unwatchable = true;
              if (errno == ENOSPC || errno == ENOMEM)
                {
                  no_inotify_resources = true;
                  error (0, 0, _("inotify resources exhausted"));
                  break;
                }
              else if (errno != f[i].errnum)
                error (0, errno, _("cannot watch %s"), quoteaf (f[i].name));
              continue;
            }

          if (hash_insert (wd_to_name, &(f[i])) == NULL)
            xalloc_die ();

          found_watchable_file = true;
        }
    }

  /* Linux kernel 2.6.24 at least has a bug where eventually, ENOSPC is always
     returned by inotify_add_watch.  In any case we should revert to polling
     when there are no inotify resources.  Also a specified directory may not
     be currently present or accessible, so revert to polling.  Also an already
     tailed but unwatchable due rename/unlink race, should also revert.  */
  if (no_inotify_resources || found_unwatchable_dir
      || (follow_mode == Follow_descriptor && tailed_but_unwatchable))
    {
      hash_free (wd_to_name);

      errno = 0;
      return true;
    }
  if (follow_mode == Follow_descriptor && !found_watchable_file)
    return false;

  prev_fspec = &(f[n_files - 1]);

  /* Check files again.  New files or data can be available since last time we
     checked and before they are watched by inotify.  */
  for (i = 0; i < n_files; i++)
    {
      if (! f[i].ignore)
        {
          /* check for new files.  */
          if (follow_mode == Follow_name)
            recheck (&(f[i]), false);
          else if (f[i].fd != -1)
            {
              /* If the file was replaced in the small window since we tailed,
                 then assume the watch is on the wrong item (different to
                 that we've already produced output for), and so revert to
                 polling the original descriptor.  */
              struct stat stats;

              if (stat (f[i].name, &stats) == 0
                  && (f[i].dev != stats.st_dev || f[i].ino != stats.st_ino))
                {
                  error (0, errno, _("%s was replaced"),
                         quoteaf (pretty_name (&(f[i]))));
                  hash_free (wd_to_name);

                  errno = 0;
                  return true;
                }
            }

          /* check for new data.  */
          check_fspec (&f[i], &prev_fspec);
        }
    }

  evlen += sizeof (struct inotify_event) + 1;
  evbuf = xmalloc (evlen);

  /* Wait for inotify events and handle them.  Events on directories
     ensure that watched files can be re-added when following by name.
     This loop blocks on the 'safe_read' call until a new event is notified.
     But when --pid=P is specified, tail usually waits via the select.  */
  while (1)
    {
      struct File_spec *fspec;
      struct inotify_event *ev;
      void *void_ev;

      /* When following by name without --retry, and the last file has
         been unlinked or renamed-away, diagnose it and return.  */
      if (follow_mode == Follow_name
          && ! reopen_inaccessible_files
          && hash_get_n_entries (wd_to_name) == 0)
        {
          error (0, 0, _("no files remaining"));
          return false;
        }

      /* When watching a PID, ensure that a read from WD will not block
         indefinitely.  */
      if (pid)
        {
          if (writer_is_dead)
            exit (EXIT_SUCCESS);

          writer_is_dead = (kill (pid, 0) != 0 && errno != EPERM);

          struct timeval delay; /* how long to wait for file changes.  */
          if (writer_is_dead)
            delay.tv_sec = delay.tv_usec = 0;
          else
            {
              delay.tv_sec = (time_t) sleep_interval;
              delay.tv_usec = 1000000 * (sleep_interval - delay.tv_sec);
            }

           fd_set rfd;
           FD_ZERO (&rfd);
           FD_SET (wd, &rfd);

           int file_change = select (wd + 1, &rfd, NULL, NULL, &delay);

           if (file_change == 0)
             continue;
           else if (file_change == -1)
             die (EXIT_FAILURE, errno, _("error monitoring inotify event"));
        }

      if (len <= evbuf_off)
        {
          len = safe_read (wd, evbuf, evlen);
          evbuf_off = 0;

          /* For kernels prior to 2.6.21, read returns 0 when the buffer
             is too small.  */
          if ((len == 0 || (len == SAFE_READ_ERROR && errno == EINVAL))
              && max_realloc--)
            {
              len = 0;
              evlen *= 2;
              evbuf = xrealloc (evbuf, evlen);
              continue;
            }

          if (len == 0 || len == SAFE_READ_ERROR)
            die (EXIT_FAILURE, errno, _("error reading inotify event"));
        }

      void_ev = evbuf + evbuf_off;
      ev = void_ev;
      evbuf_off += sizeof (*ev) + ev->len;

      if (ev->len) /* event on ev->name in watched directory.  */
        {
          size_t j;
          for (j = 0; j < n_files; j++)
            {
              /* With N=hundreds of frequently-changing files, this O(N^2)
                 process might be a problem.  FIXME: use a hash table?  */
              if (f[j].parent_wd == ev->wd
                  && STREQ (ev->name, f[j].name + f[j].basename_start))
                break;
            }

          /* It is not a watched file.  */
          if (j == n_files)
            continue;

          fspec = &(f[j]);

          int new_wd = -1;
          bool deleting = !! (ev->mask & IN_DELETE);

          if (! deleting)
            {
              /* Adding the same inode again will look up any existing wd.  */
              new_wd = inotify_add_watch (wd, f[j].name, inotify_wd_mask);
            }

          if (! deleting && new_wd < 0)
            {
              if (errno == ENOSPC || errno == ENOMEM)
                {
                  error (0, 0, _("inotify resources exhausted"));
                  hash_free (wd_to_name);
                  errno = 0;
                  return true; /* revert to polling.  */
                }
              else
                {
                  /* Can get ENOENT for a dangling symlink for example.  */
                  error (0, errno, _("cannot watch %s"), quoteaf (f[j].name));
                }
              /* We'll continue below after removing the existing watch.  */
            }

          /* This will be false if only attributes of file change.  */
          bool new_watch;
          new_watch = (! deleting) && (fspec->wd < 0 || new_wd != fspec->wd);

          if (new_watch)
            {
              if (0 <= fspec->wd)
                {
                  inotify_rm_watch (wd, fspec->wd);
                  hash_delete (wd_to_name, fspec);
                }

              fspec->wd = new_wd;

              if (new_wd == -1)
                continue;

              /* If the file was moved then inotify will use the source file wd
                for the destination file.  Make sure the key is not present in
                the table.  */
              struct File_spec *prev = hash_delete (wd_to_name, fspec);
              if (prev && prev != fspec)
                {
                  if (follow_mode == Follow_name)
                    recheck (prev, false);
                  prev->wd = -1;
                  close_fd (prev->fd, pretty_name (prev));
                }

              if (hash_insert (wd_to_name, fspec) == NULL)
                xalloc_die ();
            }

          if (follow_mode == Follow_name)
            recheck (fspec, false);
        }
      else
        {
          struct File_spec key;
          key.wd = ev->wd;
          fspec = hash_lookup (wd_to_name, &key);
        }

      if (! fspec)
        continue;

      if (ev->mask & (IN_ATTRIB | IN_DELETE | IN_DELETE_SELF | IN_MOVE_SELF))
        {
          /* Note for IN_MOVE_SELF (the file we're watching has
             been clobbered via a rename) we leave the watch
             in place since it may still be part of the set
             of watched names.  */
          if (ev->mask & IN_DELETE_SELF)
            {
              inotify_rm_watch (wd, fspec->wd);
              hash_delete (wd_to_name, fspec);
            }

          /* Note we get IN_ATTRIB for unlink() as st_nlink decrements.
             The usual path is a close() done in recheck() triggers
             an IN_DELETE_SELF event as the inode is removed.
             However sometimes open() will succeed as even though
             st_nlink is decremented, the dentry (cache) is not updated.
             Thus we depend on the IN_DELETE event on the directory
             to trigger processing for the removed file.  */

          recheck (fspec, false);

          continue;
        }
      check_fspec (fspec, &prev_fspec);
    }
}
#endif

/* Output the last N_BYTES bytes of file FILENAME open for reading in FD.
   Return true if successful.  */

static bool
tail_bytes (const char *pretty_filename, int fd, uintmax_t n_bytes,
            uintmax_t *read_pos)
{
  struct stat stats;

  if (fstat (fd, &stats))
    {
      error (0, errno, _("cannot fstat %s"), quoteaf (pretty_filename));
      return false;
    }

  if (from_start)
    {
      if ( ! presume_input_pipe
           && S_ISREG (stats.st_mode) && n_bytes <= OFF_T_MAX)
        {
          xlseek (fd, n_bytes, SEEK_CUR, pretty_filename);
          *read_pos += n_bytes;
        }
      else
        {
          int t = start_bytes (pretty_filename, fd, n_bytes, read_pos);
          if (t)
            return t < 0;
        }
      n_bytes = COPY_TO_EOF;
    }
  else
    {
      off_t end_pos = ((! presume_input_pipe && usable_st_size (&stats)
                        && n_bytes <= OFF_T_MAX)
                       ? stats.st_size : -1);
      if (end_pos <= ST_BLKSIZE (stats))
        return pipe_bytes (pretty_filename, fd, n_bytes, read_pos);
      off_t current_pos = xlseek (fd, 0, SEEK_CUR, pretty_filename);
      if (current_pos < end_pos)
        {
          off_t bytes_remaining = end_pos - current_pos;

          if (n_bytes < bytes_remaining)
            {
              current_pos = end_pos - n_bytes;
              xlseek (fd, current_pos, SEEK_SET, pretty_filename);
            }
        }
      *read_pos = current_pos;
    }

  *read_pos += dump_remainder (false, pretty_filename, fd, n_bytes);
  return true;
}

/* Output the last N_LINES lines of file FILENAME open for reading in FD.
   Return true if successful.  */

static bool
tail_lines (const char *pretty_filename, int fd, uintmax_t n_lines,
            uintmax_t *read_pos)
{
  struct stat stats;

  if (fstat (fd, &stats))
    {
      error (0, errno, _("cannot fstat %s"), quoteaf (pretty_filename));
      return false;
    }

  if (from_start)
    {
      int t = start_lines (pretty_filename, fd, n_lines, read_pos);
      if (t)
        return t < 0;
      *read_pos += dump_remainder (false, pretty_filename, fd, COPY_TO_EOF);
    }
  else
    {
      off_t start_pos = -1;
      off_t end_pos;

      /* Use file_lines only if FD refers to a regular file for
         which lseek (... SEEK_END) works.  */
      if ( ! presume_input_pipe
           && S_ISREG (stats.st_mode)
           && (start_pos = lseek (fd, 0, SEEK_CUR)) != -1
           && start_pos < (end_pos = lseek (fd, 0, SEEK_END)))
        {
          *read_pos = end_pos;
          if (end_pos != 0
              && ! file_lines (pretty_filename, fd, n_lines,
                               start_pos, end_pos, read_pos))
            return false;
        }
      else
        {
          /* Under very unlikely circumstances, it is possible to reach
             this point after positioning the file pointer to end of file
             via the 'lseek (...SEEK_END)' above.  In that case, reposition
             the file pointer back to start_pos before calling pipe_lines.  */
          if (start_pos != -1)
            xlseek (fd, start_pos, SEEK_SET, pretty_filename);

          return pipe_lines (pretty_filename, fd, n_lines, read_pos);
        }
    }
  return true;
}

/* Display the last N_UNITS units of file FILENAME, open for reading
   via FD.  Set *READ_POS to the position of the input stream pointer.
   *READ_POS is usually the number of bytes read and corresponds to an
   offset from the beginning of a file.  However, it may be larger than
   OFF_T_MAX (as for an input pipe), and may also be larger than the
   number of bytes read (when an input pointer is initially not at
   beginning of file), and may be far greater than the number of bytes
   actually read for an input file that is seekable.
   Return true if successful.  */

static bool
tail (const char *filename, int fd, uintmax_t n_units,
      uintmax_t *read_pos)
{
  *read_pos = 0;
  if (count_lines)
    return tail_lines (filename, fd, n_units, read_pos);
  else
    return tail_bytes (filename, fd, n_units, read_pos);
}

/* Display the last N_UNITS units of the file described by F.
   Return true if successful.  */

static bool
tail_file (struct File_spec *f, uintmax_t n_units)
{
  int fd;
  bool ok;

  bool is_stdin = (STREQ (f->name, "-"));

  if (is_stdin)
    {
      have_read_stdin = true;
      fd = STDIN_FILENO;
      xset_binary_mode (STDIN_FILENO, O_BINARY);
    }
  else
    fd = open (f->name, O_RDONLY | O_BINARY);

  f->tailable = !(reopen_inaccessible_files && fd == -1);

  if (fd == -1)
    {
      if (forever)
        {
          f->fd = -1;
          f->errnum = errno;
          f->ignore = ! reopen_inaccessible_files;
          f->ino = 0;
          f->dev = 0;
        }
      error (0, errno, _("cannot open %s for reading"),
             quoteaf (pretty_name (f)));
      ok = false;
    }
  else
    {
      uintmax_t read_pos;

      if (print_headers)
        write_header (pretty_name (f));
      ok = tail (pretty_name (f), fd, n_units, &read_pos);
      if (forever)
        {
          struct stat stats;

#if TAIL_TEST_SLEEP
          /* Before the tail function provided 'read_pos', there was
             a race condition described in the URL below.  This sleep
             call made the window big enough to exercise the problem.  */
          xnanosleep (1);
#endif
          f->errnum = ok - 1;
          if (fstat (fd, &stats) < 0)
            {
              ok = false;
              f->errnum = errno;
              error (0, errno, _("error reading %s"),
                     quoteaf (pretty_name (f)));
            }
          else if (!IS_TAILABLE_FILE_TYPE (stats.st_mode))
            {
              ok = false;
              f->errnum = -1;
              f->tailable = false;
              f->ignore = ! reopen_inaccessible_files;
              error (0, 0, _("%s: cannot follow end of this type of file%s"),
                     quotef (pretty_name (f)),
                     f->ignore ? _("; giving up on this name") : "");
            }

          if (!ok)
            {
              f->ignore = ! reopen_inaccessible_files;
              close_fd (fd, pretty_name (f));
              f->fd = -1;
            }
          else
            {
              /* Note: we must use read_pos here, not stats.st_size,
                 to avoid a race condition described by Ken Raeburn:
        http://lists.gnu.org/archive/html/bug-textutils/2003-05/msg00007.html */
              record_open_fd (f, fd, read_pos, &stats, (is_stdin ? -1 : 1));
              f->remote = fremote (fd, pretty_name (f));
            }
        }
      else
        {
          if (!is_stdin && close (fd))
            {
              error (0, errno, _("error reading %s"),
                     quoteaf (pretty_name (f)));
              ok = false;
            }
        }
    }

  return ok;
}

/* If obsolete usage is allowed, and the command line arguments are of
   the obsolete form and the option string is well-formed, set
   *N_UNITS, the globals COUNT_LINES, FOREVER, and FROM_START, and
   return true.  If the command line arguments are obviously incorrect
   (e.g., because obsolete usage is not allowed and the arguments are
   incorrect for non-obsolete usage), report an error and exit.
   Otherwise, return false and don't modify any parameter or global
   variable.  */

static bool
parse_obsolete_option (int argc, char * const *argv, uintmax_t *n_units)
{
  const char *p;
  const char *n_string;
  const char *n_string_end;
  int default_count = DEFAULT_N_LINES;
  bool t_from_start;
  bool t_count_lines = true;
  bool t_forever = false;

  /* With the obsolete form, there is one option string and at most
     one file argument.  Watch out for "-" and "--", though.  */
  if (! (argc == 2
         || (argc == 3 && ! (argv[2][0] == '-' && argv[2][1]))
         || (3 <= argc && argc <= 4 && STREQ (argv[2], "--"))))
    return false;

  int posix_ver = posix2_version ();
  bool obsolete_usage = posix_ver < 200112;
  bool traditional_usage = obsolete_usage || 200809 <= posix_ver;
  p = argv[1];

  switch (*p++)
    {
    default:
      return false;

    case '+':
      /* Leading "+" is a file name in the standard form.  */
      if (!traditional_usage)
        return false;

      t_from_start = true;
      break;

    case '-':
      /* In the non-obsolete form, "-" is standard input and "-c"
         requires an option-argument.  The obsolete multidigit options
         are supported as a GNU extension even when conforming to
         POSIX 1003.1-2001 or later, so don't complain about them.  */
      if (!obsolete_usage && !p[p[0] == 'c'])
        return false;

      t_from_start = false;
      break;
    }

  n_string = p;
  while (ISDIGIT (*p))
    p++;
  n_string_end = p;

  switch (*p)
    {
    case 'b': default_count *= 512;	/* Fall through.  */
    case 'c': t_count_lines = false;	/* Fall through.  */
    case 'l': p++; break;
    }

  if (*p == 'f')
    {
      t_forever = true;
      ++p;
    }

  if (*p)
    return false;

  if (n_string == n_string_end)
    *n_units = default_count;
  else if ((xstrtoumax (n_string, NULL, 10, n_units, "b")
            & ~LONGINT_INVALID_SUFFIX_CHAR)
           != LONGINT_OK)
    {
      die (EXIT_FAILURE, errno, "%s: %s", _("invalid number"),
           quote (argv[1]));
    }

  /* Set globals.  */
  from_start = t_from_start;
  count_lines = t_count_lines;
  forever = t_forever;

  return true;
}

static void
parse_options (int argc, char **argv,
               uintmax_t *n_units, enum header_mode *header_mode,
               double *sleep_interval)
{
  int c;

  while ((c = getopt_long (argc, argv, "c:n:fFqs:vz0123456789",
                           long_options, NULL))
         != -1)
    {
      switch (c)
        {
        case 'F':
          forever = true;
          follow_mode = Follow_name;
          reopen_inaccessible_files = true;
          break;

        case 'c':
        case 'n':
          count_lines = (c == 'n');
          if (*optarg == '+')
            from_start = true;
          else if (*optarg == '-')
            ++optarg;

          *n_units = xdectoumax (optarg, 0, UINTMAX_MAX, "bkKmMGTPEZY0",
                                 count_lines
                                 ? _("invalid number of lines")
                                 : _("invalid number of bytes"), 0);
          break;

        case 'f':
        case LONG_FOLLOW_OPTION:
          forever = true;
          if (optarg == NULL)
            follow_mode = DEFAULT_FOLLOW_MODE;
          else
            follow_mode = XARGMATCH ("--follow", optarg,
                                     follow_mode_string, follow_mode_map);
          break;

        case RETRY_OPTION:
          reopen_inaccessible_files = true;
          break;

        case MAX_UNCHANGED_STATS_OPTION:
          /* --max-unchanged-stats=N */
          max_n_unchanged_stats_between_opens =
            xdectoumax (optarg, 0, UINTMAX_MAX, "",
              _("invalid maximum number of unchanged stats between opens"), 0);
          break;

        case DISABLE_INOTIFY_OPTION:
          disable_inotify = true;
          break;

        case PID_OPTION:
          pid = xdectoumax (optarg, 0, PID_T_MAX, "", _("invalid PID"), 0);
          break;

        case PRESUME_INPUT_PIPE_OPTION:
          presume_input_pipe = true;
          break;

        case 'q':
          *header_mode = never;
          break;

        case 's':
          {
            double s;
            if (! (xstrtod (optarg, NULL, &s, c_strtod) && 0 <= s))
              die (EXIT_FAILURE, 0,
                   _("invalid number of seconds: %s"), quote (optarg));
            *sleep_interval = s;
          }
          break;

        case 'v':
          *header_mode = always;
          break;

        case 'z':
          line_end = '\0';
          break;

        case_GETOPT_HELP_CHAR;

        case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);

        case '0': case '1': case '2': case '3': case '4':
        case '5': case '6': case '7': case '8': case '9':
          die (EXIT_FAILURE, 0, _("option used in invalid context -- %c"), c);

        default:
          usage (EXIT_FAILURE);
        }
    }

  if (reopen_inaccessible_files)
    {
      if (!forever)
        {
          reopen_inaccessible_files = false;
          error (0, 0, _("warning: --retry ignored; --retry is useful"
                         " only when following"));
        }
      else if (follow_mode == Follow_descriptor)
        error (0, 0, _("warning: --retry only effective for the initial open"));
    }

  if (pid && !forever)
    error (0, 0,
           _("warning: PID ignored; --pid=PID is useful only when following"));
  else if (pid && kill (pid, 0) != 0 && errno == ENOSYS)
    {
      error (0, 0, _("warning: --pid=PID is not supported on this system"));
      pid = 0;
    }
}

/* Mark as '.ignore'd each member of F that corresponds to a
   pipe or fifo, and return the number of non-ignored members.  */
static size_t
ignore_fifo_and_pipe (struct File_spec *f, size_t n_files)
{
  /* When there is no FILE operand and stdin is a pipe or FIFO
     POSIX requires that tail ignore the -f option.
     Since we allow multiple FILE operands, we extend that to say: with -f,
     ignore any "-" operand that corresponds to a pipe or FIFO.  */
  size_t n_viable = 0;

  size_t i;
  for (i = 0; i < n_files; i++)
    {
      bool is_a_fifo_or_pipe =
        (STREQ (f[i].name, "-")
         && !f[i].ignore
         && 0 <= f[i].fd
         && (S_ISFIFO (f[i].mode)
             || (HAVE_FIFO_PIPES != 1 && isapipe (f[i].fd))));
      if (is_a_fifo_or_pipe)
        {
          f[i].fd = -1;
          f[i].ignore = true;
        }
      else
        ++n_viable;
    }

  return n_viable;
}

int
main (int argc, char **argv)
{
  enum header_mode header_mode = multiple_files;
  bool ok = true;
  /* If from_start, the number of items to skip before printing; otherwise,
     the number of items at the end of the file to print.  Although the type
     is signed, the value is never negative.  */
  uintmax_t n_units = DEFAULT_N_LINES;
  size_t n_files;
  char **file;
  struct File_spec *F;
  size_t i;
  bool obsolete_option;

  /* The number of seconds to sleep between iterations.
     During one iteration, every file name or descriptor is checked to
     see if it has changed.  */
  double sleep_interval = 1.0;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdout);

  have_read_stdin = false;

  count_lines = true;
  forever = from_start = print_headers = false;
  line_end = '\n';
  obsolete_option = parse_obsolete_option (argc, argv, &n_units);
  argc -= obsolete_option;
  argv += obsolete_option;
  parse_options (argc, argv, &n_units, &header_mode, &sleep_interval);

  /* To start printing with item N_UNITS from the start of the file, skip
     N_UNITS - 1 items.  'tail -n +0' is actually meaningless, but for Unix
     compatibility it's treated the same as 'tail -n +1'.  */
  if (from_start)
    {
      if (n_units)
        --n_units;
    }

  IF_LINT (assert (0 <= argc));

  if (optind < argc)
    {
      n_files = argc - optind;
      file = argv + optind;
    }
  else
    {
      static char *dummy_stdin = (char *) "-";
      n_files = 1;
      file = &dummy_stdin;
    }

  {
    bool found_hyphen = false;

    for (i = 0; i < n_files; i++)
      if (STREQ (file[i], "-"))
        found_hyphen = true;

    /* When following by name, there must be a name.  */
    if (found_hyphen && follow_mode == Follow_name)
      die (EXIT_FAILURE, 0, _("cannot follow %s by name"), quoteaf ("-"));

    /* When following forever, warn if any file is '-'.
       This is only a warning, since tail's output (before a failing seek,
       and that from any non-stdin files) might still be useful.  */
    if (forever && found_hyphen && isatty (STDIN_FILENO))
      error (0, 0, _("warning: following standard input"
                     " indefinitely is ineffective"));
  }

  /* Don't read anything if we'll never output anything.  */
  if (! n_units && ! forever && ! from_start)
    return EXIT_SUCCESS;

  F = xnmalloc (n_files, sizeof *F);
  for (i = 0; i < n_files; i++)
    F[i].name = file[i];

  if (header_mode == always
      || (header_mode == multiple_files && n_files > 1))
    print_headers = true;

  xset_binary_mode (STDOUT_FILENO, O_BINARY);

  for (i = 0; i < n_files; i++)
    ok &= tail_file (&F[i], n_units);

  if (forever && ignore_fifo_and_pipe (F, n_files))
    {
#if HAVE_INOTIFY
      /* tailable_stdin() checks if the user specifies stdin via  "-",
         or implicitly by providing no arguments. If so, we won't use inotify.
         Technically, on systems with a working /dev/stdin, we *could*,
         but would it be worth it?  Verifying that it's a real device
         and hooked up to stdin is not trivial, while reverting to
         non-inotify-based tail_forever is easy and portable.

         any_remote_file() checks if the user has specified any
         files that reside on remote file systems.  inotify is not used
         in this case because it would miss any updates to the file
         that were not initiated from the local system.

         any_non_remote_file() checks if the user has specified any
         files that don't reside on remote file systems.  inotify is not used
         if there are no open files, as we can't determine if those file
         will be on a remote file system.

         any_symlinks() checks if the user has specified any symbolic links.
         inotify is not used in this case because it returns updated _targets_
         which would not match the specified names.  If we tried to always
         use the target names, then we would miss changes to the symlink itself.

         ok is false when one of the files specified could not be opened for
         reading.  In this case and when following by descriptor,
         tail_forever_inotify() cannot be used (in its current implementation).

         FIXME: inotify doesn't give any notification when a new
         (remote) file or directory is mounted on top a watched file.
         When follow_mode == Follow_name we would ideally like to detect that.
         Note if there is a change to the original file then we'll
         recheck it and follow the new file, or ignore it if the
         file has changed to being remote.

         FIXME: when using inotify, and a directory for a watched file
         is recreated, then we don't recheck any new file when
         follow_mode == Follow_name.

         FIXME-maybe: inotify has a watch descriptor per inode, and hence with
         our current hash implementation will only --follow data for one
         of the names when multiple hardlinked files are specified, or
         for one name when a name is specified multiple times.  */
      if (!disable_inotify && (tailable_stdin (F, n_files)
                               || any_remote_file (F, n_files)
                               || ! any_non_remote_file (F, n_files)
                               || any_symlinks (F, n_files)
                               || (!ok && follow_mode == Follow_descriptor)))
        disable_inotify = true;

      if (!disable_inotify)
        {
          int wd = inotify_init ();
          if (0 <= wd)
            {
              /* Flush any output from tail_file, now, since
                 tail_forever_inotify flushes only after writing,
                 not before reading.  */
              if (fflush (stdout) != 0)
                die (EXIT_FAILURE, errno, _("write error"));

              if (! tail_forever_inotify (wd, F, n_files, sleep_interval))
                return EXIT_FAILURE;
            }
          error (0, errno, _("inotify cannot be used, reverting to polling"));

          /* Free resources as this process can be long lived,
            and we may have exhausted system resources above.  */

          for (i = 0; i < n_files; i++)
            {
              /* It's OK to remove the same watch multiple times,
                ignoring the EINVAL from redundant calls.  */
              if (F[i].wd != -1)
                inotify_rm_watch (wd, F[i].wd);
              if (F[i].parent_wd != -1)
                inotify_rm_watch (wd, F[i].parent_wd);
            }
        }
#endif
      disable_inotify = true;
      tail_forever (F, n_files, sleep_interval);
    }

  IF_LINT (free (F));

  if (have_read_stdin && close (STDIN_FILENO) < 0)
    die (EXIT_FAILURE, errno, "-");
  return ok ? EXIT_SUCCESS : EXIT_FAILURE;
}
