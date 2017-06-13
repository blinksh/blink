/* truncate -- truncate or extend the length of files.
   Copyright (C) 2008-2017 Free Software Foundation, Inc.

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

/* Written by Pádraig Brady

   This is backwards compatible with the FreeBSD utility, but is more
   flexible wrt the size specifications and the use of long options,
   to better fit the "GNU" environment.  */

#include <config.h>             /* sets _FILE_OFFSET_BITS=64 etc. */
#include <stdio.h>
#include <getopt.h>
#include <sys/types.h>

#include "system.h"
#include "die.h"
#include "error.h"
#include "quote.h"
#include "stat-size.h"
#include "xdectoint.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "truncate"

#define AUTHORS proper_name ("Padraig Brady")

/* (-c) If true, don't create if not already there */
static bool no_create;

/* (-o) If true, --size refers to blocks not bytes */
static bool block_mode;

/* (-r) Reference file to use size from */
static char const *ref_file;

static struct option const longopts[] =
{
  {"no-create", no_argument, NULL, 'c'},
  {"io-blocks", no_argument, NULL, 'o'},
  {"reference", required_argument, NULL, 'r'},
  {"size", required_argument, NULL, 's'},
  {GETOPT_HELP_OPTION_DECL},
  {GETOPT_VERSION_OPTION_DECL},
  {NULL, 0, NULL, 0}
};

typedef enum
{ rm_abs = 0, rm_rel, rm_min, rm_max, rm_rdn, rm_rup } rel_mode_t;

void
usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("Usage: %s OPTION... FILE...\n"), program_name);
      fputs (_("\
Shrink or extend the size of each FILE to the specified size\n\
\n\
A FILE argument that does not exist is created.\n\
\n\
If a FILE is larger than the specified size, the extra data is lost.\n\
If a FILE is shorter, it is extended and the extended part (hole)\n\
reads as zero bytes.\n\
"), stdout);

      emit_mandatory_arg_note ();

      fputs (_("\
  -c, --no-create        do not create any files\n\
"), stdout);
      fputs (_("\
  -o, --io-blocks        treat SIZE as number of IO blocks instead of bytes\n\
"), stdout);
      fputs (_("\
  -r, --reference=RFILE  base size on RFILE\n\
  -s, --size=SIZE        set or adjust the file size by SIZE bytes\n"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      emit_size_note ();
      fputs (_("\n\
SIZE may also be prefixed by one of the following modifying characters:\n\
'+' extend by, '-' reduce by, '<' at most, '>' at least,\n\
'/' round down to multiple of, '%' round up to multiple of.\n"), stdout);
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}

/* return true on success, false on error.  */
static bool
do_ftruncate (int fd, char const *fname, off_t ssize, off_t rsize,
              rel_mode_t rel_mode)
{
  struct stat sb;
  off_t nsize;

  if ((block_mode || (rel_mode && rsize < 0)) && fstat (fd, &sb) != 0)
    {
      error (0, errno, _("cannot fstat %s"), quoteaf (fname));
      return false;
    }
  if (block_mode)
    {
      off_t const blksize = ST_BLKSIZE (sb);
      if (ssize < OFF_T_MIN / blksize || ssize > OFF_T_MAX / blksize)
        {
          error (0, 0,
                 _("overflow in %" PRIdMAX
                   " * %" PRIdMAX " byte blocks for file %s"),
                 (intmax_t) ssize, (intmax_t) blksize,
                 quoteaf (fname));
          return false;
        }
      ssize *= blksize;
    }
  if (rel_mode)
    {
      uintmax_t fsize;

      if (0 <= rsize)
        fsize = rsize;
      else
        {
          off_t file_size;
          if (usable_st_size (&sb))
            {
              file_size = sb.st_size;
              if (file_size < 0)
                {
                  /* Sanity check.  Overflow is the only reason I can think
                     this would ever go negative. */
                  error (0, 0, _("%s has unusable, apparently negative size"),
                         quoteaf (fname));
                  return false;
                }
            }
          else
            {
              file_size = lseek (fd, 0, SEEK_END);
              if (file_size < 0)
                {
                  error (0, errno, _("cannot get the size of %s"),
                         quoteaf (fname));
                  return false;
                }
            }
          fsize = file_size;
        }

      if (rel_mode == rm_min)
        nsize = MAX (fsize, (uintmax_t) ssize);
      else if (rel_mode == rm_max)
        nsize = MIN (fsize, (uintmax_t) ssize);
      else if (rel_mode == rm_rdn)
        /* 0..ssize-1 -> 0 */
        nsize = (fsize / ssize) * ssize;
      else if (rel_mode == rm_rup)
        /* 1..ssize -> ssize */
        {
          /* Here ssize>=1 && fsize>=0 */
          uintmax_t const overflow = ((fsize + ssize - 1) / ssize) * ssize;
          if (overflow > OFF_T_MAX)
            {
              error (0, 0, _("overflow rounding up size of file %s"),
                     quoteaf (fname));
              return false;
            }
          nsize = overflow;
        }
      else
        {
          if (ssize > OFF_T_MAX - (off_t)fsize)
            {
              error (0, 0, _("overflow extending size of file %s"),
                     quoteaf (fname));
              return false;
            }
          nsize = fsize + ssize;
        }
    }
  else
    nsize = ssize;
  if (nsize < 0)
    nsize = 0;

  if (ftruncate (fd, nsize) == -1)      /* note updates mtime & ctime */
    {
      error (0, errno,
             _("failed to truncate %s at %" PRIdMAX " bytes"), quoteaf (fname),
             (intmax_t) nsize);
      return false;
    }

  return true;
}

int
main (int argc, char **argv)
{
  bool got_size = false;
  bool errors = false;
  off_t size IF_LINT ( = 0);
  off_t rsize = -1;
  rel_mode_t rel_mode = rm_abs;
  int c, fd = -1, oflags;
  char const *fname;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdout);

  while ((c = getopt_long (argc, argv, "cor:s:", longopts, NULL)) != -1)
    {
      switch (c)
        {
        case 'c':
          no_create = true;
          break;

        case 'o':
          block_mode = true;
          break;

        case 'r':
          ref_file = optarg;
          break;

        case 's':
          /* skip any whitespace */
          while (isspace (to_uchar (*optarg)))
            optarg++;
          switch (*optarg)
            {
            case '<':
              rel_mode = rm_max;
              optarg++;
              break;
            case '>':
              rel_mode = rm_min;
              optarg++;
              break;
            case '/':
              rel_mode = rm_rdn;
              optarg++;
              break;
            case '%':
              rel_mode = rm_rup;
              optarg++;
              break;
            }
          /* skip any whitespace */
          while (isspace (to_uchar (*optarg)))
            optarg++;
          if (*optarg == '+' || *optarg == '-')
            {
              if (rel_mode)
                {
                  error (0, 0, _("multiple relative modifiers specified"));
                  /* Note other combinations are flagged as invalid numbers */
                  usage (EXIT_FAILURE);
                }
              rel_mode = rm_rel;
            }
          /* Support dd BLOCK size suffixes + lowercase g,t,m for bsd compat.
             Note we don't support dd's b=512, c=1, w=2 or 21x512MiB formats. */
          size = xdectoimax (optarg, OFF_T_MIN, OFF_T_MAX, "EgGkKmMPtTYZ0",
                             _("Invalid number"), 0);
          /* Rounding to multiple of 0 is nonsensical */
          if ((rel_mode == rm_rup || rel_mode == rm_rdn) && size == 0)
            die (EXIT_FAILURE, 0, _("division by zero"));
          got_size = true;
          break;

        case_GETOPT_HELP_CHAR;

        case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);

        default:
          usage (EXIT_FAILURE);
        }
    }

  argv += optind;
  argc -= optind;

  /* must specify either size or reference file */
  if (!ref_file && !got_size)
    {
      error (0, 0, _("you must specify either %s or %s"),
             quote_n (0, "--size"), quote_n (1, "--reference"));
      usage (EXIT_FAILURE);
    }
  /* must specify a relative size with a reference file */
  if (ref_file && got_size && !rel_mode)
    {
      error (0, 0, _("you must specify a relative %s with %s"),
             quote_n (0, "--size"), quote_n (1, "--reference"));
      usage (EXIT_FAILURE);
    }
  /* block_mode without size is not valid */
  if (block_mode && !got_size)
    {
      error (0, 0, _("%s was specified but %s was not"),
             quote_n (0, "--io-blocks"), quote_n (1, "--size"));
      usage (EXIT_FAILURE);
    }
  /* must specify at least 1 file */
  if (argc < 1)
    {
      error (0, 0, _("missing file operand"));
      usage (EXIT_FAILURE);
    }

  if (ref_file)
    {
      struct stat sb;
      off_t file_size = -1;
      if (stat (ref_file, &sb) != 0)
        die (EXIT_FAILURE, errno, _("cannot stat %s"), quoteaf (ref_file));
      if (usable_st_size (&sb))
        file_size = sb.st_size;
      else
        {
          int ref_fd = open (ref_file, O_RDONLY);
          if (0 <= ref_fd)
            {
              off_t file_end = lseek (ref_fd, 0, SEEK_END);
              int saved_errno = errno;
              close (ref_fd); /* ignore failure */
              if (0 <= file_end)
                file_size = file_end;
              else
                {
                  /* restore, in case close clobbered it. */
                  errno = saved_errno;
                }
            }
        }
      if (file_size < 0)
        die (EXIT_FAILURE, errno, _("cannot get the size of %s"),
             quoteaf (ref_file));
      if (!got_size)
        size = file_size;
      else
        rsize = file_size;
    }

  oflags = O_WRONLY | (no_create ? 0 : O_CREAT) | O_NONBLOCK;

  while ((fname = *argv++) != NULL)
    {
      if ((fd = open (fname, oflags, MODE_RW_UGO)) == -1)
        {
          /* 'truncate -s0 -c no-such-file'  shouldn't gen error
             'truncate -s0 no-such-dir/file' should gen ENOENT error
             'truncate -s0 no-such-dir/' should gen EISDIR error
             'truncate -s0 .' should gen EISDIR error */
          if (!(no_create && errno == ENOENT))
            {
              error (0, errno, _("cannot open %s for writing"),
                     quoteaf (fname));
              errors = true;
            }
          continue;
        }


      if (fd != -1)
        {
          errors |= !do_ftruncate (fd, fname, size, rsize, rel_mode);
          if (close (fd) != 0)
            {
              error (0, errno, _("failed to close %s"), quoteaf (fname));
              errors = true;
            }
        }
    }

  return errors ? EXIT_FAILURE : EXIT_SUCCESS;
}
