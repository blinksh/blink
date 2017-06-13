/* shred.c - overwrite files and devices to make it harder to recover data

   Copyright (C) 1999-2017 Free Software Foundation, Inc.
   Copyright (C) 1997, 1998, 1999 Colin Plumb.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.

   Written by Colin Plumb.  */

/*
 * Do a more secure overwrite of given files or devices, to make it harder
 * for even very expensive hardware probing to recover the data.
 *
 * Although this process is also known as "wiping", I prefer the longer
 * name both because I think it is more evocative of what is happening and
 * because a longer name conveys a more appropriate sense of deliberateness.
 *
 * For the theory behind this, see "Secure Deletion of Data from Magnetic
 * and Solid-State Memory", on line at
 * https://www.cs.auckland.ac.nz/~pgut001/pubs/secure_del.html
 *
 * Just for the record, reversing one or two passes of disk overwrite
 * is not terribly difficult with hardware help.  Hook up a good-quality
 * digitizing oscilloscope to the output of the head preamplifier and copy
 * the high-res digitized data to a computer for some off-line analysis.
 * Read the "current" data and average all the pulses together to get an
 * "average" pulse on the disk.  Subtract this average pulse from all of
 * the actual pulses and you can clearly see the "echo" of the previous
 * data on the disk.
 *
 * Real hard drives have to balance the cost of the media, the head,
 * and the read circuitry.  They use better-quality media than absolutely
 * necessary to limit the cost of the read circuitry.  By throwing that
 * assumption out, and the assumption that you want the data processed
 * as fast as the hard drive can spin, you can do better.
 *
 * If asked to wipe a file, this also unlinks it, renaming it to in a
 * clever way to try to leave no trace of the original filename.
 *
 * This was inspired by a desire to improve on some code titled:
 * Wipe V1.0-- Overwrite and delete files.  S. 2/3/96
 * but I've rewritten everything here so completely that no trace of
 * the original remains.
 *
 * Thanks to:
 * Bob Jenkins, for his good RNG work and patience with the FSF copyright
 * paperwork.
 * Jim Meyering, for his work merging this into the GNU fileutils while
 * still letting me feel a sense of ownership and pride.  Getting me to
 * tolerate the GNU brace style was quite a feat of diplomacy.
 * Paul Eggert, for lots of useful discussion and code.  I disagree with
 * an awful lot of his suggestions, but they're disagreements worth having.
 *
 * Things to think about:
 * - Security: Is there any risk to the race
 *   between overwriting and unlinking a file?  Will it do anything
 *   drastically bad if told to attack a named pipe or socket?
 */

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "shred"

#define AUTHORS proper_name ("Colin Plumb")

#include <config.h>

#include <getopt.h>
#include <stdio.h>
#include <assert.h>
#include <setjmp.h>
#include <sys/types.h>
#ifdef __linux__
# include <sys/mtio.h>
#endif

#include "system.h"
#include "argmatch.h"
#include "xdectoint.h"
#include "die.h"
#include "error.h"
#include "fcntl--.h"
#include "human.h"
#include "randint.h"
#include "randread.h"
#include "stat-size.h"

/* Default number of times to overwrite.  */
enum { DEFAULT_PASSES = 3 };

/* How many seconds to wait before checking whether to output another
   verbose output line.  */
enum { VERBOSE_UPDATE = 5 };

/* Sector size and corresponding mask, for recovering after write failures.
   The size must be a power of 2.  */
enum { SECTOR_SIZE = 512 };
enum { SECTOR_MASK = SECTOR_SIZE - 1 };
verify (0 < SECTOR_SIZE && (SECTOR_SIZE & SECTOR_MASK) == 0);

enum remove_method
{
  remove_none = 0,      /* the default: only wipe data.  */
  remove_unlink,        /* don't obfuscate name, just unlink.  */
  remove_wipe,          /* obfuscate name before unlink.  */
  remove_wipesync       /* obfuscate name, syncing each byte, before unlink.  */
};

static char const *const remove_args[] =
{
  "unlink", "wipe", "wipesync", NULL
};

static enum remove_method const remove_methods[] =
{
  remove_unlink, remove_wipe, remove_wipesync
};

struct Options
{
  bool force;		/* -f flag: chmod files if necessary */
  size_t n_iterations;	/* -n flag: Number of iterations */
  off_t size;		/* -s flag: size of file */
  enum remove_method remove_file; /* -u flag: remove file after shredding */
  bool verbose;		/* -v flag: Print progress */
  bool exact;		/* -x flag: Do not round up file size */
  bool zero_fill;	/* -z flag: Add a final zero pass */
};

/* For long options that have no equivalent short option, use a
   non-character as a pseudo short option, starting with CHAR_MAX + 1.  */
enum
{
  RANDOM_SOURCE_OPTION = CHAR_MAX + 1
};

static struct option const long_opts[] =
{
  {"exact", no_argument, NULL, 'x'},
  {"force", no_argument, NULL, 'f'},
  {"iterations", required_argument, NULL, 'n'},
  {"size", required_argument, NULL, 's'},
  {"random-source", required_argument, NULL, RANDOM_SOURCE_OPTION},
  {"remove", optional_argument, NULL, 'u'},
  {"verbose", no_argument, NULL, 'v'},
  {"zero", no_argument, NULL, 'z'},
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
      printf (_("Usage: %s [OPTION]... FILE...\n"), program_name);
      fputs (_("\
Overwrite the specified FILE(s) repeatedly, in order to make it harder\n\
for even very expensive hardware probing to recover the data.\n\
"), stdout);
      fputs (_("\
\n\
If FILE is -, shred standard output.\n\
"), stdout);

      emit_mandatory_arg_note ();

      printf (_("\
  -f, --force    change permissions to allow writing if necessary\n\
  -n, --iterations=N  overwrite N times instead of the default (%d)\n\
      --random-source=FILE  get random bytes from FILE\n\
  -s, --size=N   shred this many bytes (suffixes like K, M, G accepted)\n\
"), DEFAULT_PASSES);
      fputs (_("\
  -u             truncate and remove file after overwriting\n\
      --remove[=HOW]  like -u but give control on HOW to delete;  See below\n\
  -v, --verbose  show progress\n\
  -x, --exact    do not round file sizes up to the next full block;\n\
                   this is the default for non-regular files\n\
  -z, --zero     add a final overwrite with zeros to hide shredding\n\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      fputs (_("\
\n\
Delete FILE(s) if --remove (-u) is specified.  The default is not to remove\n\
the files because it is common to operate on device files like /dev/hda,\n\
and those files usually should not be removed.\n\
The optional HOW parameter indicates how to remove a directory entry:\n\
'unlink' => use a standard unlink call.\n\
'wipe' => also first obfuscate bytes in the name.\n\
'wipesync' => also sync each obfuscated byte to disk.\n\
The default mode is 'wipesync', but note it can be expensive.\n\
\n\
"), stdout);
      fputs (_("\
CAUTION: Note that shred relies on a very important assumption:\n\
that the file system overwrites data in place.  This is the traditional\n\
way to do things, but many modern file system designs do not satisfy this\n\
assumption.  The following are examples of file systems on which shred is\n\
not effective, or is not guaranteed to be effective in all file system modes:\n\
\n\
"), stdout);
      fputs (_("\
* log-structured or journaled file systems, such as those supplied with\n\
AIX and Solaris (and JFS, ReiserFS, XFS, Ext3, etc.)\n\
\n\
* file systems that write redundant data and carry on even if some writes\n\
fail, such as RAID-based file systems\n\
\n\
* file systems that make snapshots, such as Network Appliance's NFS server\n\
\n\
"), stdout);
      fputs (_("\
* file systems that cache in temporary locations, such as NFS\n\
version 3 clients\n\
\n\
* compressed file systems\n\
\n\
"), stdout);
      fputs (_("\
In the case of ext3 file systems, the above disclaimer applies\n\
(and shred is thus of limited effectiveness) only in data=journal mode,\n\
which journals file data in addition to just metadata.  In both the\n\
data=ordered (default) and data=writeback modes, shred works as usual.\n\
Ext3 journaling modes can be changed by adding the data=something option\n\
to the mount options for a particular file system in the /etc/fstab file,\n\
as documented in the mount man page (man mount).\n\
\n\
"), stdout);
      fputs (_("\
In addition, file system backups and remote mirrors may contain copies\n\
of the file that cannot be removed, and that will allow a shredded file\n\
to be recovered later.\n\
"), stdout);
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}

/*
 * Determine if pattern type is periodic or not.
 */
static bool
periodic_pattern (int type)
{
  if (type <= 0)
    return false;

  unsigned char r[3];
  unsigned int bits = type & 0xfff;

  bits |= bits << 12;
  r[0] = (bits >> 4) & 255;
  r[1] = (bits >> 8) & 255;
  r[2] = bits & 255;

  return (r[0] != r[1]) || (r[0] != r[2]);
}

/*
 * Fill a buffer with a fixed pattern.
 *
 * The buffer must be at least 3 bytes long, even if
 * size is less.  Larger sizes are filled exactly.
 */
static void
fillpattern (int type, unsigned char *r, size_t size)
{
  size_t i;
  unsigned int bits = type & 0xfff;

  bits |= bits << 12;
  r[0] = (bits >> 4) & 255;
  r[1] = (bits >> 8) & 255;
  r[2] = bits & 255;
  for (i = 3; i < size / 2; i *= 2)
    memcpy (r + i, r, i);
  if (i < size)
    memcpy (r + i, r, size - i);

  /* Invert the first bit of every sector. */
  if (type & 0x1000)
    for (i = 0; i < size; i += SECTOR_SIZE)
      r[i] ^= 0x80;
}

/*
 * Generate a 6-character (+ nul) pass name string
 * FIXME: allow translation of "random".
 */
#define PASS_NAME_SIZE 7
static void
passname (unsigned char const *data, char name[PASS_NAME_SIZE])
{
  if (data)
    sprintf (name, "%02x%02x%02x", data[0], data[1], data[2]);
  else
    memcpy (name, "random", PASS_NAME_SIZE);
}

/* Return true when it's ok to ignore an fsync or fdatasync
   failure that set errno to ERRNO_VAL.  */
static bool
ignorable_sync_errno (int errno_val)
{
  return (errno_val == EINVAL
          || errno_val == EBADF
          /* HP-UX does this */
          || errno_val == EISDIR);
}

/* Request that all data for FD be transferred to the corresponding
   storage device.  QNAME is the file name (quoted for colons).
   Report any errors found.  Return 0 on success, -1
   (setting errno) on failure.  It is not an error if fdatasync and/or
   fsync is not supported for this file, or if the file is not a
   writable file descriptor.  */
static int
dosync (int fd, char const *qname)
{
  int err;

#if HAVE_FDATASYNC
  if (fdatasync (fd) == 0)
    return 0;
  err = errno;
  if ( ! ignorable_sync_errno (err))
    {
      error (0, err, _("%s: fdatasync failed"), qname);
      errno = err;
      return -1;
    }
#endif

  if (fsync (fd) == 0)
    return 0;
  err = errno;
  if ( ! ignorable_sync_errno (err))
    {
      error (0, err, _("%s: fsync failed"), qname);
      errno = err;
      return -1;
    }

  sync ();
  return 0;
}

/* Turn on or off direct I/O mode for file descriptor FD, if possible.
   Try to turn it on if ENABLE is true.  Otherwise, try to turn it off.  */
static void
direct_mode (int fd, bool enable)
{
  if (O_DIRECT)
    {
      int fd_flags = fcntl (fd, F_GETFL);
      if (0 < fd_flags)
        {
          int new_flags = (enable
                           ? (fd_flags | O_DIRECT)
                           : (fd_flags & ~O_DIRECT));
          if (new_flags != fd_flags)
            fcntl (fd, F_SETFL, new_flags);
        }
    }

#if HAVE_DIRECTIO && defined DIRECTIO_ON && defined DIRECTIO_OFF
  /* This is Solaris-specific.  */
  directio (fd, enable ? DIRECTIO_ON : DIRECTIO_OFF);
#endif
}

/* Rewind FD; its status is ST.  */
static bool
dorewind (int fd, struct stat const *st)
{
  if (S_ISCHR (st->st_mode))
    {
#ifdef __linux__
      /* In the Linux kernel, lseek does not work on tape devices; it
         returns a randomish value instead.  Try the low-level tape
         rewind operation first.  */
      struct mtop op;
      op.mt_op = MTREW;
      op.mt_count = 1;
      if (ioctl (fd, MTIOCTOP, &op) == 0)
        return true;
#endif
    }
  off_t offset = lseek (fd, 0, SEEK_SET);
  if (0 < offset)
    errno = EINVAL;
  return offset == 0;
}

/* By convention, negative sizes represent unknown values.  */

static bool
known (off_t size)
{
  return 0 <= size;
}

/*
 * Do pass number K of N, writing *SIZEP bytes of the given pattern TYPE
 * to the file descriptor FD.  K and N are passed in only for verbose
 * progress message purposes.  If N == 0, no progress messages are printed.
 *
 * If *SIZEP == -1, the size is unknown, and it will be filled in as soon
 * as writing fails with ENOSPC.
 *
 * Return 1 on write error, -1 on other error, 0 on success.
 */
static int
dopass (int fd, struct stat const *st, char const *qname, off_t *sizep,
        int type, struct randread_source *s,
        unsigned long int k, unsigned long int n)
{
  off_t size = *sizep;
  off_t offset;			/* Current file position */
  time_t thresh IF_LINT ( = 0);	/* Time to maybe print next status update */
  time_t now = 0;		/* Current time */
  size_t lim;			/* Amount of data to try writing */
  size_t soff;			/* Offset into buffer for next write */
  ssize_t ssize;		/* Return value from write */

  /* Fill pattern buffer.  Aligning it to a page so we can do direct I/O.  */
  size_t page_size = getpagesize ();
#define PERIODIC_OUTPUT_SIZE (60 * 1024)
#define NONPERIODIC_OUTPUT_SIZE (64 * 1024)
  verify (PERIODIC_OUTPUT_SIZE % 3 == 0);
  size_t output_size = periodic_pattern (type)
                       ? PERIODIC_OUTPUT_SIZE : NONPERIODIC_OUTPUT_SIZE;
#define PAGE_ALIGN_SLOP (page_size - 1)                /* So directio works */
#define FILLPATTERN_SIZE (((output_size + 2) / 3) * 3) /* Multiple of 3 */
#define PATTERNBUF_SIZE (PAGE_ALIGN_SLOP + FILLPATTERN_SIZE)
  void *fill_pattern_mem = xmalloc (PATTERNBUF_SIZE);
  unsigned char *pbuf = ptr_align (fill_pattern_mem, page_size);

  char pass_string[PASS_NAME_SIZE];	/* Name of current pass */
  bool write_error = false;
  bool other_error = false;

  /* Printable previous offset into the file */
  char previous_offset_buf[LONGEST_HUMAN_READABLE + 1];
  char const *previous_human_offset IF_LINT ( = 0);

  /* As a performance tweak, avoid direct I/O for small sizes,
     as it's just a performance rather then security consideration,
     and direct I/O can often be unsupported for small non aligned sizes.  */
  bool try_without_directio = 0 < size && size < output_size;
  if (! try_without_directio)
    direct_mode (fd, true);

  if (! dorewind (fd, st))
    {
      error (0, errno, _("%s: cannot rewind"), qname);
      other_error = true;
      goto free_pattern_mem;
    }

  /* Constant fill patterns need only be set up once. */
  if (type >= 0)
    {
      lim = known (size) && size < FILLPATTERN_SIZE ? size : FILLPATTERN_SIZE;
      fillpattern (type, pbuf, lim);
      passname (pbuf, pass_string);
    }
  else
    {
      passname (0, pass_string);
    }

  /* Set position if first status update */
  if (n)
    {
      error (0, 0, _("%s: pass %lu/%lu (%s)..."), qname, k, n, pass_string);
      thresh = time (NULL) + VERBOSE_UPDATE;
      previous_human_offset = "";
    }

  offset = 0;
  while (true)
    {
      /* How much to write this time? */
      lim = output_size;
      if (known (size) && size - offset < output_size)
        {
          if (size < offset)
            break;
          lim = size - offset;
          if (!lim)
            break;
        }
      if (type < 0)
        randread (s, pbuf, lim);
      /* Loop to retry partial writes. */
      for (soff = 0; soff < lim; soff += ssize)
        {
          ssize = write (fd, pbuf + soff, lim - soff);
          if (0 < ssize)
            assume (ssize <= lim - soff);
          else
            {
              if (! known (size) && (ssize == 0 || errno == ENOSPC))
                {
                  /* We have found the end of the file.  */
                  if (soff <= OFF_T_MAX - offset)
                    *sizep = size = offset + soff;
                  break;
                }
              else
                {
                  int errnum = errno;
                  char buf[INT_BUFSIZE_BOUND (uintmax_t)];

                  /* Retry without direct I/O since this may not be supported
                     at all on some (file) systems, or with the current size.
                     I.e., a specified --size that is not aligned, or when
                     dealing with slop at the end of a file with --exact.  */
                  if (! try_without_directio && errno == EINVAL)
                    {
                      direct_mode (fd, false);
                      ssize = 0;
                      try_without_directio = true;
                      continue;
                    }
                  error (0, errnum, _("%s: error writing at offset %s"),
                         qname, umaxtostr (offset + soff, buf));

                  /* 'shred' is often used on bad media, before throwing it
                     out.  Thus, it shouldn't give up on bad blocks.  This
                     code works because lim is always a multiple of
                     SECTOR_SIZE, except at the end.  This size constraint
                     also enables direct I/O on some (file) systems.  */
                  verify (PERIODIC_OUTPUT_SIZE % SECTOR_SIZE == 0);
                  verify (NONPERIODIC_OUTPUT_SIZE % SECTOR_SIZE == 0);
                  if (errnum == EIO && known (size)
                      && (soff | SECTOR_MASK) < lim)
                    {
                      size_t soff1 = (soff | SECTOR_MASK) + 1;
                      if (lseek (fd, offset + soff1, SEEK_SET) != -1)
                        {
                          /* Arrange to skip this block. */
                          ssize = soff1 - soff;
                          write_error = true;
                          continue;
                        }
                      error (0, errno, _("%s: lseek failed"), qname);
                    }
                  other_error = true;
                  goto free_pattern_mem;
                }
            }
        }

      /* Okay, we have written "soff" bytes. */

      if (OFF_T_MAX - offset < soff)
        {
          error (0, 0, _("%s: file too large"), qname);
          other_error = true;
          goto free_pattern_mem;
        }

      offset += soff;

      bool done = offset == size;

      /* Time to print progress? */
      if (n && ((done && *previous_human_offset)
                || thresh <= (now = time (NULL))))
        {
          char offset_buf[LONGEST_HUMAN_READABLE + 1];
          char size_buf[LONGEST_HUMAN_READABLE + 1];
          int human_progress_opts = (human_autoscale | human_SI
                                     | human_base_1024 | human_B);
          char const *human_offset
            = human_readable (offset, offset_buf,
                              human_floor | human_progress_opts, 1, 1);

          if (done || !STREQ (previous_human_offset, human_offset))
            {
              if (! known (size))
                error (0, 0, _("%s: pass %lu/%lu (%s)...%s"),
                       qname, k, n, pass_string, human_offset);
              else
                {
                  uintmax_t off = offset;
                  int percent = (size == 0
                                 ? 100
                                 : (off <= TYPE_MAXIMUM (uintmax_t) / 100
                                    ? off * 100 / size
                                    : off / (size / 100)));
                  char const *human_size
                    = human_readable (size, size_buf,
                                      human_ceiling | human_progress_opts,
                                      1, 1);
                  if (done)
                    human_offset = human_size;
                  error (0, 0, _("%s: pass %lu/%lu (%s)...%s/%s %d%%"),
                         qname, k, n, pass_string, human_offset, human_size,
                         percent);
                }

              strcpy (previous_offset_buf, human_offset);
              previous_human_offset = previous_offset_buf;
              thresh = now + VERBOSE_UPDATE;

              /*
               * Force periodic syncs to keep displayed progress accurate
               * FIXME: Should these be present even if -v is not enabled,
               * to keep the buffer cache from filling with dirty pages?
               * It's a common problem with programs that do lots of writes,
               * like mkfs.
               */
              if (dosync (fd, qname) != 0)
                {
                  if (errno != EIO)
                    {
                      other_error = true;
                      goto free_pattern_mem;
                    }
                  write_error = true;
                }
            }
        }
    }

  /* Force what we just wrote to hit the media. */
  if (dosync (fd, qname) != 0)
    {
      if (errno != EIO)
        {
          other_error = true;
          goto free_pattern_mem;
        }
      write_error = true;
    }

free_pattern_mem:
  memset (pbuf, 0, FILLPATTERN_SIZE);
  free (fill_pattern_mem);

  return other_error ? -1 : write_error;
}

/*
 * The passes start and end with a random pass, and the passes in between
 * are done in random order.  The idea is to deprive someone trying to
 * reverse the process of knowledge of the overwrite patterns, so they
 * have the additional step of figuring out what was done to the disk
 * before they can try to reverse or cancel it.
 *
 * First, all possible 1-bit patterns.  There are two of them.
 * Then, all possible 2-bit patterns.  There are four, but the two
 * which are also 1-bit patterns can be omitted.
 * Then, all possible 3-bit patterns.  Likewise, 8-2 = 6.
 * Then, all possible 4-bit patterns.  16-4 = 12.
 *
 * The basic passes are:
 * 1-bit: 0x000, 0xFFF
 * 2-bit: 0x555, 0xAAA
 * 3-bit: 0x249, 0x492, 0x924, 0x6DB, 0xB6D, 0xDB6 (+ 1-bit)
 *        100100100100         110110110110
 *           9   2   4            D   B   6
 * 4-bit: 0x111, 0x222, 0x333, 0x444, 0x666, 0x777,
 *        0x888, 0x999, 0xBBB, 0xCCC, 0xDDD, 0xEEE (+ 1-bit, 2-bit)
 * Adding three random passes at the beginning, middle and end
 * produces the default 25-pass structure.
 *
 * The next extension would be to 5-bit and 6-bit patterns.
 * There are 30 uncovered 5-bit patterns and 64-8-2 = 46 uncovered
 * 6-bit patterns, so they would increase the time required
 * significantly.  4-bit patterns are enough for most purposes.
 *
 * The main gotcha is that this would require a trickier encoding,
 * since lcm(2,3,4) = 12 bits is easy to fit into an int, but
 * lcm(2,3,4,5) = 60 bits is not.
 *
 * One extension that is included is to complement the first bit in each
 * 512-byte block, to alter the phase of the encoded data in the more
 * complex encodings.  This doesn't apply to MFM, so the 1-bit patterns
 * are considered part of the 3-bit ones and the 2-bit patterns are
 * considered part of the 4-bit patterns.
 *
 *
 * How does the generalization to variable numbers of passes work?
 *
 * Here's how...
 * Have an ordered list of groups of passes.  Each group is a set.
 * Take as many groups as will fit, plus a random subset of the
 * last partial group, and place them into the passes list.
 * Then shuffle the passes list into random order and use that.
 *
 * One extra detail: if we can't include a large enough fraction of the
 * last group to be interesting, then just substitute random passes.
 *
 * If you want more passes than the entire list of groups can
 * provide, just start repeating from the beginning of the list.
 */
static int const
  patterns[] =
{
  -2,				/* 2 random passes */
  2, 0x000, 0xFFF,		/* 1-bit */
  2, 0x555, 0xAAA,		/* 2-bit */
  -1,				/* 1 random pass */
  6, 0x249, 0x492, 0x6DB, 0x924, 0xB6D, 0xDB6,	/* 3-bit */
  12, 0x111, 0x222, 0x333, 0x444, 0x666, 0x777,
  0x888, 0x999, 0xBBB, 0xCCC, 0xDDD, 0xEEE,	/* 4-bit */
  -1,				/* 1 random pass */
        /* The following patterns have the first bit per block flipped */
  8, 0x1000, 0x1249, 0x1492, 0x16DB, 0x1924, 0x1B6D, 0x1DB6, 0x1FFF,
  14, 0x1111, 0x1222, 0x1333, 0x1444, 0x1555, 0x1666, 0x1777,
  0x1888, 0x1999, 0x1AAA, 0x1BBB, 0x1CCC, 0x1DDD, 0x1EEE,
  -1,				/* 1 random pass */
  0				/* End */
};

/*
 * Generate a random wiping pass pattern with num passes.
 * This is a two-stage process.  First, the passes to include
 * are chosen, and then they are shuffled into the desired
 * order.
 */
static void
genpattern (int *dest, size_t num, struct randint_source *s)
{
  size_t randpasses;
  int const *p;
  int *d;
  size_t n;
  size_t accum, top, swap;
  int k;

  if (!num)
    return;

  /* Stage 1: choose the passes to use */
  p = patterns;
  randpasses = 0;
  d = dest;			/* Destination for generated pass list */
  n = num;			/* Passes remaining to fill */

  while (true)
    {
      k = *p++;			/* Block descriptor word */
      if (!k)
        {			/* Loop back to the beginning */
          p = patterns;
        }
      else if (k < 0)
        {			/* -k random passes */
          k = -k;
          if ((size_t) k >= n)
            {
              randpasses += n;
              break;
            }
          randpasses += k;
          n -= k;
        }
      else if ((size_t) k <= n)
        {			/* Full block of patterns */
          memcpy (d, p, k * sizeof (int));
          p += k;
          d += k;
          n -= k;
        }
      else if (n < 2 || 3 * n < (size_t) k)
        {			/* Finish with random */
          randpasses += n;
          break;
        }
      else
        {			/* Pad out with n of the k available */
          do
            {
              if (n == (size_t) k || randint_choose (s, k) < n)
                {
                  *d++ = *p;
                  n--;
                }
              p++;
              k--;
            }
          while (n);
          break;
        }
    }
  top = num - randpasses;	/* Top of initialized data */
  /* assert (d == dest+top); */

  /*
   * We now have fixed patterns in the dest buffer up to
   * "top", and we need to scramble them, with "randpasses"
   * random passes evenly spaced among them.
   *
   * We want one at the beginning, one at the end, and
   * evenly spaced in between.  To do this, we basically
   * use Bresenham's line draw (a.k.a DDA) algorithm
   * to draw a line with slope (randpasses-1)/(num-1).
   * (We use a positive accumulator and count down to
   * do this.)
   *
   * So for each desired output value, we do the following:
   * - If it should be a random pass, copy the pass type
   *   to top++, out of the way of the other passes, and
   *   set the current pass to -1 (random).
   * - If it should be a normal pattern pass, choose an
   *   entry at random between here and top-1 (inclusive)
   *   and swap the current entry with that one.
   */
  randpasses--;			/* To speed up later math */
  accum = randpasses;		/* Bresenham DDA accumulator */
  for (n = 0; n < num; n++)
    {
      if (accum <= randpasses)
        {
          accum += num - 1;
          dest[top++] = dest[n];
          dest[n] = -1;
        }
      else
        {
          swap = n + randint_choose (s, top - n);
          k = dest[n];
          dest[n] = dest[swap];
          dest[swap] = k;
        }
      accum -= randpasses;
    }
  /* assert (top == num); */
}

/*
 * The core routine to actually do the work.  This overwrites the first
 * size bytes of the given fd.  Return true if successful.
 */
static bool
do_wipefd (int fd, char const *qname, struct randint_source *s,
           struct Options const *flags)
{
  size_t i;
  struct stat st;
  off_t size;		/* Size to write, size to read */
  off_t i_size = 0;	/* For small files, initial size to overwrite inode */
  unsigned long int n;	/* Number of passes for printing purposes */
  int *passarray;
  bool ok = true;
  struct randread_source *rs;

  n = 0;		/* dopass takes n == 0 to mean "don't print progress" */
  if (flags->verbose)
    n = flags->n_iterations + flags->zero_fill;

  if (fstat (fd, &st))
    {
      error (0, errno, _("%s: fstat failed"), qname);
      return false;
    }

  /* If we know that we can't possibly shred the file, give up now.
     Otherwise, we may go into an infinite loop writing data before we
     find that we can't rewind the device.  */
  if ((S_ISCHR (st.st_mode) && isatty (fd))
      || S_ISFIFO (st.st_mode)
      || S_ISSOCK (st.st_mode))
    {
      error (0, 0, _("%s: invalid file type"), qname);
      return false;
    }
  else if (S_ISREG (st.st_mode) && st.st_size < 0)
    {
      error (0, 0, _("%s: file has negative size"), qname);
      return false;
    }

  /* Allocate pass array */
  passarray = xnmalloc (flags->n_iterations, sizeof *passarray);

  size = flags->size;
  if (size == -1)
    {
      if (S_ISREG (st.st_mode))
        {
          size = st.st_size;

          if (! flags->exact)
            {
              /* Round up to the nearest block size to clear slack space.  */
              off_t remainder = size % ST_BLKSIZE (st);
              if (size && size < ST_BLKSIZE (st))
                i_size = size;
              if (remainder != 0)
                {
                  off_t size_incr = ST_BLKSIZE (st) - remainder;
                  size += MIN (size_incr, OFF_T_MAX - size);
                }
            }
        }
      else
        {
          /* The behavior of lseek is unspecified, but in practice if
             it returns a positive number that's the size of this
             device.  */
          size = lseek (fd, 0, SEEK_END);
          if (size <= 0)
            {
              /* We are unable to determine the length, up front.
                 Let dopass do that as part of its first iteration.  */
              size = -1;
            }
        }
    }
  else if (S_ISREG (st.st_mode)
           && st.st_size < MIN (ST_BLKSIZE (st), size))
    i_size = st.st_size;

  /* Schedule the passes in random order. */
  genpattern (passarray, flags->n_iterations, s);

  rs = randint_get_source (s);

  while (true)
    {
      off_t pass_size;
      unsigned long int pn = n;

      if (i_size)
        {
          pass_size = i_size;
          i_size = 0;
          pn = 0;
        }
      else if (size)
        {
          pass_size = size;
          size = 0;
        }
      /* TODO: consider handling tail packing by
         writing the tail padding as a separate pass,
         (that would not rewind).  */
      else
        break;

      for (i = 0; i < flags->n_iterations + flags->zero_fill; i++)
        {
          int err = 0;
          int type = i < flags->n_iterations ? passarray[i] : 0;

          err = dopass (fd, &st, qname, &pass_size, type, rs, i + 1, pn);

          if (err)
            {
              ok = false;
              if (err < 0)
                goto wipefd_out;
            }
        }
    }

  /* Now deallocate the data.  The effect of ftruncate on
     non-regular files is unspecified, so don't worry about any
     errors reported for them.  */
  if (flags->remove_file && ftruncate (fd, 0) != 0
      && S_ISREG (st.st_mode))
    {
      error (0, errno, _("%s: error truncating"), qname);
      ok = false;
      goto wipefd_out;
    }

wipefd_out:
  memset (passarray, 0, flags->n_iterations * sizeof (int));
  free (passarray);
  return ok;
}

/* A wrapper with a little more checking for fds on the command line */
static bool
wipefd (int fd, char const *qname, struct randint_source *s,
        struct Options const *flags)
{
  int fd_flags = fcntl (fd, F_GETFL);

  if (fd_flags < 0)
    {
      error (0, errno, _("%s: fcntl failed"), qname);
      return false;
    }
  if (fd_flags & O_APPEND)
    {
      error (0, 0, _("%s: cannot shred append-only file descriptor"), qname);
      return false;
    }
  return do_wipefd (fd, qname, s, flags);
}

/* --- Name-wiping code --- */

/* Characters allowed in a file name - a safe universal set.  */
static char const nameset[] =
"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_.";

/* Increment NAME (with LEN bytes).  NAME must be a big-endian base N
   number with the digits taken from nameset.  Return true if successful.
   Otherwise, (because NAME already has the greatest possible value)
   return false.  */

static bool
incname (char *name, size_t len)
{
  while (len--)
    {
      char const *p = strchr (nameset, name[len]);

      /* Given that NAME is composed of bytes from NAMESET,
         P will never be NULL here.  */
      assert (p);

      /* If this character has a successor, use it.  */
      if (p[1])
        {
          name[len] = p[1];
          return true;
        }

      /* Otherwise, set this digit to 0 and increment the prefix.  */
      name[len] = nameset[0];
    }

  return false;
}

/*
 * Repeatedly rename a file with shorter and shorter names,
 * to obliterate all traces of the file name (and length) on any system
 * that adds a trailing delimiter to on-disk file names and reuses
 * the same directory slot.  Finally, unlink it.
 * The passed-in filename is modified in place to the new filename.
 * (Which is unlinked if this function succeeds, but is still present if
 * it fails for some reason.)
 *
 * The main loop is written carefully to not get stuck if all possible
 * names of a given length are occupied.  It counts down the length from
 * the original to 0.  While the length is non-zero, it tries to find an
 * unused file name of the given length.  It continues until either the
 * name is available and the rename succeeds, or it runs out of names
 * to try (incname wraps and returns 1).  Finally, it unlinks the file.
 *
 * The unlink is Unix-specific, as ANSI-standard remove has more
 * portability problems with C libraries making it "safe".  rename
 * is ANSI-standard.
 *
 * To force the directory data out, we try to open the directory and
 * invoke fdatasync and/or fsync on it.  This is non-standard, so don't
 * insist that it works: just fall back to a global sync in that case.
 * This is fairly significantly Unix-specific.  Of course, on any
 * file system with synchronous metadata updates, this is unnecessary.
 */
static bool
wipename (char *oldname, char const *qoldname, struct Options const *flags)
{
  char *newname = xstrdup (oldname);
  char *base = last_component (newname);
  size_t len = base_len (base);
  char *dir = dir_name (newname);
  char *qdir = xstrdup (quotef (dir));
  bool first = true;
  bool ok = true;
  int dir_fd = -1;

  if (flags->remove_file == remove_wipesync)
    dir_fd = open (dir, O_RDONLY | O_DIRECTORY | O_NOCTTY | O_NONBLOCK);

  if (flags->verbose)
    error (0, 0, _("%s: removing"), qoldname);

  while ((flags->remove_file != remove_unlink) && len)
    {
      memset (base, nameset[0], len);
      base[len] = 0;
      do
        {
          struct stat st;
          if (lstat (newname, &st) < 0)
            {
              if (rename (oldname, newname) == 0)
                {
                  if (0 <= dir_fd && dosync (dir_fd, qdir) != 0)
                    ok = false;
                  if (flags->verbose)
                    {
                      /*
                       * People seem to understand this better than talking
                       * about renaming oldname.  newname doesn't need
                       * quoting because we picked it.  oldname needs to
                       * be quoted only the first time.
                       */
                      char const *old = (first ? qoldname : oldname);
                      error (0, 0, _("%s: renamed to %s"),
                             old, newname);
                      first = false;
                    }
                  memcpy (oldname + (base - newname), base, len + 1);
                  break;
                }
              else
                {
                  /* The rename failed: give up on this length.  */
                  break;
                }
            }
          else
            {
              /* newname exists, so increment BASE so we use another */
            }
        }
      while (incname (base, len));
      len--;
    }
  if (unlink (oldname) != 0)
    {
      error (0, errno, _("%s: failed to remove"), qoldname);
      ok = false;
    }
  else if (flags->verbose)
    error (0, 0, _("%s: removed"), qoldname);
  if (0 <= dir_fd)
    {
      if (dosync (dir_fd, qdir) != 0)
        ok = false;
      if (close (dir_fd) != 0)
        {
          error (0, errno, _("%s: failed to close"), qdir);
          ok = false;
        }
    }
  free (newname);
  free (dir);
  free (qdir);
  return ok;
}

/*
 * Finally, the function that actually takes a filename and grinds
 * it into hamburger.
 *
 * FIXME
 * Detail to note: since we do not restore errno to EACCES after
 * a failed chmod, we end up printing the error code from the chmod.
 * This is actually the error that stopped us from proceeding, so
 * it's arguably the right one, and in practice it'll be either EACCES
 * again or EPERM, which both give similar error messages.
 * Does anyone disagree?
 */
static bool
wipefile (char *name, char const *qname,
          struct randint_source *s, struct Options const *flags)
{
  bool ok;
  int fd;

  fd = open (name, O_WRONLY | O_NOCTTY | O_BINARY);
  if (fd < 0
      && (errno == EACCES && flags->force)
      && chmod (name, S_IWUSR) == 0)
    fd = open (name, O_WRONLY | O_NOCTTY | O_BINARY);
  if (fd < 0)
    {
      error (0, errno, _("%s: failed to open for writing"), qname);
      return false;
    }

  ok = do_wipefd (fd, qname, s, flags);
  if (close (fd) != 0)
    {
      error (0, errno, _("%s: failed to close"), qname);
      ok = false;
    }
  if (ok && flags->remove_file)
    ok = wipename (name, qname, flags);
  return ok;
}


/* Buffers for random data.  */
static struct randint_source *randint_source;

/* Just on general principles, wipe buffers containing information
   that may be related to the possibly-pseudorandom values used during
   shredding.  */
static void
clear_random_data (void)
{
  randint_all_free (randint_source);
}


int
main (int argc, char **argv)
{
  bool ok = true;
  struct Options flags = { 0, };
  char **file;
  int n_files;
  int c;
  int i;
  char const *random_source = NULL;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdout);

  flags.n_iterations = DEFAULT_PASSES;
  flags.size = -1;

  while ((c = getopt_long (argc, argv, "fn:s:uvxz", long_opts, NULL)) != -1)
    {
      switch (c)
        {
        case 'f':
          flags.force = true;
          break;

        case 'n':
          flags.n_iterations = xdectoumax (optarg, 0,
                                           MIN (ULONG_MAX,
                                                SIZE_MAX / sizeof (int)), "",
                                           _("invalid number of passes"), 0);
          break;

        case RANDOM_SOURCE_OPTION:
          if (random_source && !STREQ (random_source, optarg))
            die (EXIT_FAILURE, 0, _("multiple random sources specified"));
          random_source = optarg;
          break;

        case 'u':
          if (optarg == NULL)
            flags.remove_file = remove_wipesync;
          else
            flags.remove_file = XARGMATCH ("--remove", optarg,
                                           remove_args, remove_methods);
          break;

        case 's':
          flags.size = xnumtoumax (optarg, 0, 0, OFF_T_MAX, "cbBkKMGTPEZY0",
                                   _("invalid file size"), 0);
          break;

        case 'v':
          flags.verbose = true;
          break;

        case 'x':
          flags.exact = true;
          break;

        case 'z':
          flags.zero_fill = true;
          break;

        case_GETOPT_HELP_CHAR;

        case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);

        default:
          usage (EXIT_FAILURE);
        }
    }

  file = argv + optind;
  n_files = argc - optind;

  if (n_files == 0)
    {
      error (0, 0, _("missing file operand"));
      usage (EXIT_FAILURE);
    }

  randint_source = randint_all_new (random_source, SIZE_MAX);
  if (! randint_source)
    die (EXIT_FAILURE, errno, "%s", quotef (random_source));
  atexit (clear_random_data);

  for (i = 0; i < n_files; i++)
    {
      char *qname = xstrdup (quotef (file[i]));
      if (STREQ (file[i], "-"))
        {
          ok &= wipefd (STDOUT_FILENO, qname, randint_source, &flags);
        }
      else
        {
          /* Plain filename - Note that this overwrites *argv! */
          ok &= wipefile (file[i], qname, randint_source, &flags);
        }
      free (qname);
    }

  return ok ? EXIT_SUCCESS : EXIT_FAILURE;
}
/*
 * vim:sw=2:sts=2:
 */
