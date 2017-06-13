/* dd -- convert a file while copying it.
   Copyright (C) 1985-2017 Free Software Foundation, Inc.

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

/* Written by Paul Rubin, David MacKenzie, and Stuart Kemp. */

#include <config.h>

#define SWAB_ALIGN_OFFSET 2

#include <sys/types.h>
#include <signal.h>
#include <getopt.h>

#include "system.h"
#include "close-stream.h"
#include "die.h"
#include "error.h"
#include "fd-reopen.h"
#include "gethrxtime.h"
#include "human.h"
#include "long-options.h"
#include "quote.h"
#include "verror.h"
#include "xstrtol.h"
#include "xtime.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "dd"

#define AUTHORS \
  proper_name ("Paul Rubin"), \
  proper_name ("David MacKenzie"), \
  proper_name ("Stuart Kemp")

/* Use SA_NOCLDSTOP as a proxy for whether the sigaction machinery is
   present.  */
#ifndef SA_NOCLDSTOP
# define SA_NOCLDSTOP 0
# define sigprocmask(How, Set, Oset) /* empty */
# define sigset_t int
# if ! HAVE_SIGINTERRUPT
#  define siginterrupt(sig, flag) /* empty */
# endif
#endif

/* NonStop circa 2011 lacks SA_RESETHAND; see Bug#9076.  */
#ifndef SA_RESETHAND
# define SA_RESETHAND 0
#endif

#ifndef SIGINFO
# define SIGINFO SIGUSR1
#endif

/* This may belong in GNULIB's fcntl module instead.
   Define O_CIO to 0 if it is not supported by this OS. */
#ifndef O_CIO
# define O_CIO 0
#endif

/* On AIX 5.1 and AIX 5.2, O_NOCACHE is defined via <fcntl.h>
   and would interfere with our use of that name, below.  */
#undef O_NOCACHE

#if ! HAVE_FDATASYNC
# define fdatasync(fd) (errno = ENOSYS, -1)
#endif

#define output_char(c)				\
  do						\
    {						\
      obuf[oc++] = (c);				\
      if (oc >= output_blocksize)		\
        write_output ();			\
    }						\
  while (0)

/* Default input and output blocksize. */
#define DEFAULT_BLOCKSIZE 512

/* How many bytes to add to the input and output block sizes before invoking
   malloc.  See dd_copy for details.  INPUT_BLOCK_SLOP must be no less than
   OUTPUT_BLOCK_SLOP.  */
#define INPUT_BLOCK_SLOP (2 * SWAB_ALIGN_OFFSET + 2 * page_size - 1)
#define OUTPUT_BLOCK_SLOP (page_size - 1)

/* Maximum blocksize for the given SLOP.
   Keep it smaller than SIZE_MAX - SLOP, so that we can
   allocate buffers that size.  Keep it smaller than SSIZE_MAX, for
   the benefit of system calls like "read".  And keep it smaller than
   OFF_T_MAX, for the benefit of the large-offset seek code.  */
#define MAX_BLOCKSIZE(slop) MIN (SIZE_MAX - (slop), MIN (SSIZE_MAX, OFF_T_MAX))

/* Conversions bit masks. */
enum
  {
    C_ASCII = 01,

    C_EBCDIC = 02,
    C_IBM = 04,
    C_BLOCK = 010,
    C_UNBLOCK = 020,
    C_LCASE = 040,
    C_UCASE = 0100,
    C_SWAB = 0200,
    C_NOERROR = 0400,
    C_NOTRUNC = 01000,
    C_SYNC = 02000,

    /* Use separate input and output buffers, and combine partial
       input blocks. */
    C_TWOBUFS = 04000,

    C_NOCREAT = 010000,
    C_EXCL = 020000,
    C_FDATASYNC = 040000,
    C_FSYNC = 0100000,

    C_SPARSE = 0200000
  };

/* Status levels.  */
enum
  {
    STATUS_NONE = 1,
    STATUS_NOXFER = 2,
    STATUS_DEFAULT = 3,
    STATUS_PROGRESS = 4
  };

/* The name of the input file, or NULL for the standard input. */
static char const *input_file = NULL;

/* The name of the output file, or NULL for the standard output. */
static char const *output_file = NULL;

/* The page size on this host.  */
static size_t page_size;

/* The number of bytes in which atomic reads are done. */
static size_t input_blocksize = 0;

/* The number of bytes in which atomic writes are done. */
static size_t output_blocksize = 0;

/* Conversion buffer size, in bytes.  0 prevents conversions. */
static size_t conversion_blocksize = 0;

/* Skip this many records of 'input_blocksize' bytes before input. */
static uintmax_t skip_records = 0;

/* Skip this many bytes before input in addition of 'skip_records'
   records.  */
static size_t skip_bytes = 0;

/* Skip this many records of 'output_blocksize' bytes before output. */
static uintmax_t seek_records = 0;

/* Skip this many bytes in addition to 'seek_records' records before
   output.  */
static uintmax_t seek_bytes = 0;

/* Whether the final output was done with a seek (rather than a write).  */
static bool final_op_was_seek;

/* Copy only this many records.  The default is effectively infinity.  */
static uintmax_t max_records = (uintmax_t) -1;

/* Copy this many bytes in addition to 'max_records' records.  */
static size_t max_bytes = 0;

/* Bit vector of conversions to apply. */
static int conversions_mask = 0;

/* Open flags for the input and output files.  */
static int input_flags = 0;
static int output_flags = 0;

/* Status flags for what is printed to stderr.  */
static int status_level = STATUS_DEFAULT;

/* If nonzero, filter characters through the translation table.  */
static bool translation_needed = false;

/* Number of partial blocks written. */
static uintmax_t w_partial = 0;

/* Number of full blocks written. */
static uintmax_t w_full = 0;

/* Number of partial blocks read. */
static uintmax_t r_partial = 0;

/* Number of full blocks read. */
static uintmax_t r_full = 0;

/* Number of bytes written.  */
static uintmax_t w_bytes = 0;

/* Time that dd started.  */
static xtime_t start_time;

/* Next time to report periodic progress.  */
static xtime_t next_time;

/* If positive, the number of bytes output in the current progress line.  */
static int progress_len;

/* True if input is seekable.  */
static bool input_seekable;

/* Error number corresponding to initial attempt to lseek input.
   If ESPIPE, do not issue any more diagnostics about it.  */
static int input_seek_errno;

/* File offset of the input, in bytes, along with a flag recording
   whether it overflowed.  */
static uintmax_t input_offset;
static bool input_offset_overflow;

/* True if a partial read should be diagnosed.  */
static bool warn_partial_read;

/* Records truncated by conv=block. */
static uintmax_t r_truncate = 0;

/* Output representation of newline and space characters.
   They change if we're converting to EBCDIC.  */
static char newline_character = '\n';
static char space_character = ' ';

/* Input buffer. */
static char *ibuf;

/* Output buffer. */
static char *obuf;

/* Current index into 'obuf'. */
static size_t oc = 0;

/* Index into current line, for 'conv=block' and 'conv=unblock'.  */
static size_t col = 0;

/* The set of signals that are caught.  */
static sigset_t caught_signals;

/* If nonzero, the value of the pending fatal signal.  */
static sig_atomic_t volatile interrupt_signal;

/* A count of the number of pending info signals that have been received.  */
static sig_atomic_t volatile info_signal_count;

/* Whether to discard cache for input or output.  */
static bool i_nocache, o_nocache;

/* Function used for read (to handle iflag=fullblock parameter).  */
static ssize_t (*iread_fnc) (int fd, char *buf, size_t size);

/* A longest symbol in the struct symbol_values tables below.  */
#define LONGEST_SYMBOL "count_bytes"

/* A symbol and the corresponding integer value.  */
struct symbol_value
{
  char symbol[sizeof LONGEST_SYMBOL];
  int value;
};

/* Conversion symbols, for conv="...".  */
static struct symbol_value const conversions[] =
{
  {"ascii", C_ASCII | C_UNBLOCK | C_TWOBUFS},	/* EBCDIC to ASCII. */
  {"ebcdic", C_EBCDIC | C_BLOCK | C_TWOBUFS},	/* ASCII to EBCDIC. */
  {"ibm", C_IBM | C_BLOCK | C_TWOBUFS},	/* Different ASCII to EBCDIC. */
  {"block", C_BLOCK | C_TWOBUFS},	/* Variable to fixed length records. */
  {"unblock", C_UNBLOCK | C_TWOBUFS},	/* Fixed to variable length records. */
  {"lcase", C_LCASE | C_TWOBUFS},	/* Translate upper to lower case. */
  {"ucase", C_UCASE | C_TWOBUFS},	/* Translate lower to upper case. */
  {"sparse", C_SPARSE},		/* Try to sparsely write output. */
  {"swab", C_SWAB | C_TWOBUFS},	/* Swap bytes of input. */
  {"noerror", C_NOERROR},	/* Ignore i/o errors. */
  {"nocreat", C_NOCREAT},	/* Do not create output file.  */
  {"excl", C_EXCL},		/* Fail if the output file already exists.  */
  {"notrunc", C_NOTRUNC},	/* Do not truncate output file. */
  {"sync", C_SYNC},		/* Pad input records to ibs with NULs. */
  {"fdatasync", C_FDATASYNC},	/* Synchronize output data before finishing.  */
  {"fsync", C_FSYNC},		/* Also synchronize output metadata.  */
  {"", 0}
};

#define FFS_MASK(x) ((x) ^ ((x) & ((x) - 1)))
enum
  {
    /* Compute a value that's bitwise disjoint from the union
       of all O_ values.  */
    v = ~(0
          | O_APPEND
          | O_BINARY
          | O_CIO
          | O_DIRECT
          | O_DIRECTORY
          | O_DSYNC
          | O_NOATIME
          | O_NOCTTY
          | O_NOFOLLOW
          | O_NOLINKS
          | O_NONBLOCK
          | O_SYNC
          | O_TEXT
          ),

    /* Use its lowest bits for private flags.  */
    O_FULLBLOCK = FFS_MASK (v),
    v2 = v ^ O_FULLBLOCK,

    O_NOCACHE = FFS_MASK (v2),
    v3 = v2 ^ O_NOCACHE,

    O_COUNT_BYTES = FFS_MASK (v3),
    v4 = v3 ^ O_COUNT_BYTES,

    O_SKIP_BYTES = FFS_MASK (v4),
    v5 = v4 ^ O_SKIP_BYTES,

    O_SEEK_BYTES = FFS_MASK (v5)
  };

/* Ensure that we got something.  */
verify (O_FULLBLOCK != 0);
verify (O_NOCACHE != 0);
verify (O_COUNT_BYTES != 0);
verify (O_SKIP_BYTES != 0);
verify (O_SEEK_BYTES != 0);

#define MULTIPLE_BITS_SET(i) (((i) & ((i) - 1)) != 0)

/* Ensure that this is a single-bit value.  */
verify ( ! MULTIPLE_BITS_SET (O_FULLBLOCK));
verify ( ! MULTIPLE_BITS_SET (O_NOCACHE));
verify ( ! MULTIPLE_BITS_SET (O_COUNT_BYTES));
verify ( ! MULTIPLE_BITS_SET (O_SKIP_BYTES));
verify ( ! MULTIPLE_BITS_SET (O_SEEK_BYTES));

/* Flags, for iflag="..." and oflag="...".  */
static struct symbol_value const flags[] =
{
  {"append",	  O_APPEND},
  {"binary",	  O_BINARY},
  {"cio",	  O_CIO},
  {"direct",	  O_DIRECT},
  {"directory",   O_DIRECTORY},
  {"dsync",	  O_DSYNC},
  {"noatime",	  O_NOATIME},
  {"nocache",	  O_NOCACHE},   /* Discard cache.  */
  {"noctty",	  O_NOCTTY},
  {"nofollow",	  HAVE_WORKING_O_NOFOLLOW ? O_NOFOLLOW : 0},
  {"nolinks",	  O_NOLINKS},
  {"nonblock",	  O_NONBLOCK},
  {"sync",	  O_SYNC},
  {"text",	  O_TEXT},
  {"fullblock",   O_FULLBLOCK}, /* Accumulate full blocks from input.  */
  {"count_bytes", O_COUNT_BYTES},
  {"skip_bytes",  O_SKIP_BYTES},
  {"seek_bytes",  O_SEEK_BYTES},
  {"",		0}
};

/* Status, for status="...".  */
static struct symbol_value const statuses[] =
{
  {"none",	STATUS_NONE},
  {"noxfer",	STATUS_NOXFER},
  {"progress",	STATUS_PROGRESS},
  {"",		0}
};

/* Translation table formed by applying successive transformations. */
static unsigned char trans_table[256];

/* Standard translation tables, taken from POSIX 1003.1-2013.
   Beware of imitations; there are lots of ASCII<->EBCDIC tables
   floating around the net, perhaps valid for some applications but
   not correct here.  */

static char const ascii_to_ebcdic[] =
{
  '\000', '\001', '\002', '\003', '\067', '\055', '\056', '\057',
  '\026', '\005', '\045', '\013', '\014', '\015', '\016', '\017',
  '\020', '\021', '\022', '\023', '\074', '\075', '\062', '\046',
  '\030', '\031', '\077', '\047', '\034', '\035', '\036', '\037',
  '\100', '\132', '\177', '\173', '\133', '\154', '\120', '\175',
  '\115', '\135', '\134', '\116', '\153', '\140', '\113', '\141',
  '\360', '\361', '\362', '\363', '\364', '\365', '\366', '\367',
  '\370', '\371', '\172', '\136', '\114', '\176', '\156', '\157',
  '\174', '\301', '\302', '\303', '\304', '\305', '\306', '\307',
  '\310', '\311', '\321', '\322', '\323', '\324', '\325', '\326',
  '\327', '\330', '\331', '\342', '\343', '\344', '\345', '\346',
  '\347', '\350', '\351', '\255', '\340', '\275', '\232', '\155',
  '\171', '\201', '\202', '\203', '\204', '\205', '\206', '\207',
  '\210', '\211', '\221', '\222', '\223', '\224', '\225', '\226',
  '\227', '\230', '\231', '\242', '\243', '\244', '\245', '\246',
  '\247', '\250', '\251', '\300', '\117', '\320', '\137', '\007',
  '\040', '\041', '\042', '\043', '\044', '\025', '\006', '\027',
  '\050', '\051', '\052', '\053', '\054', '\011', '\012', '\033',
  '\060', '\061', '\032', '\063', '\064', '\065', '\066', '\010',
  '\070', '\071', '\072', '\073', '\004', '\024', '\076', '\341',
  '\101', '\102', '\103', '\104', '\105', '\106', '\107', '\110',
  '\111', '\121', '\122', '\123', '\124', '\125', '\126', '\127',
  '\130', '\131', '\142', '\143', '\144', '\145', '\146', '\147',
  '\150', '\151', '\160', '\161', '\162', '\163', '\164', '\165',
  '\166', '\167', '\170', '\200', '\212', '\213', '\214', '\215',
  '\216', '\217', '\220', '\152', '\233', '\234', '\235', '\236',
  '\237', '\240', '\252', '\253', '\254', '\112', '\256', '\257',
  '\260', '\261', '\262', '\263', '\264', '\265', '\266', '\267',
  '\270', '\271', '\272', '\273', '\274', '\241', '\276', '\277',
  '\312', '\313', '\314', '\315', '\316', '\317', '\332', '\333',
  '\334', '\335', '\336', '\337', '\352', '\353', '\354', '\355',
  '\356', '\357', '\372', '\373', '\374', '\375', '\376', '\377'
};

static char const ascii_to_ibm[] =
{
  '\000', '\001', '\002', '\003', '\067', '\055', '\056', '\057',
  '\026', '\005', '\045', '\013', '\014', '\015', '\016', '\017',
  '\020', '\021', '\022', '\023', '\074', '\075', '\062', '\046',
  '\030', '\031', '\077', '\047', '\034', '\035', '\036', '\037',
  '\100', '\132', '\177', '\173', '\133', '\154', '\120', '\175',
  '\115', '\135', '\134', '\116', '\153', '\140', '\113', '\141',
  '\360', '\361', '\362', '\363', '\364', '\365', '\366', '\367',
  '\370', '\371', '\172', '\136', '\114', '\176', '\156', '\157',
  '\174', '\301', '\302', '\303', '\304', '\305', '\306', '\307',
  '\310', '\311', '\321', '\322', '\323', '\324', '\325', '\326',
  '\327', '\330', '\331', '\342', '\343', '\344', '\345', '\346',
  '\347', '\350', '\351', '\255', '\340', '\275', '\137', '\155',
  '\171', '\201', '\202', '\203', '\204', '\205', '\206', '\207',
  '\210', '\211', '\221', '\222', '\223', '\224', '\225', '\226',
  '\227', '\230', '\231', '\242', '\243', '\244', '\245', '\246',
  '\247', '\250', '\251', '\300', '\117', '\320', '\241', '\007',
  '\040', '\041', '\042', '\043', '\044', '\025', '\006', '\027',
  '\050', '\051', '\052', '\053', '\054', '\011', '\012', '\033',
  '\060', '\061', '\032', '\063', '\064', '\065', '\066', '\010',
  '\070', '\071', '\072', '\073', '\004', '\024', '\076', '\341',
  '\101', '\102', '\103', '\104', '\105', '\106', '\107', '\110',
  '\111', '\121', '\122', '\123', '\124', '\125', '\126', '\127',
  '\130', '\131', '\142', '\143', '\144', '\145', '\146', '\147',
  '\150', '\151', '\160', '\161', '\162', '\163', '\164', '\165',
  '\166', '\167', '\170', '\200', '\212', '\213', '\214', '\215',
  '\216', '\217', '\220', '\232', '\233', '\234', '\235', '\236',
  '\237', '\240', '\252', '\253', '\254', '\255', '\256', '\257',
  '\260', '\261', '\262', '\263', '\264', '\265', '\266', '\267',
  '\270', '\271', '\272', '\273', '\274', '\275', '\276', '\277',
  '\312', '\313', '\314', '\315', '\316', '\317', '\332', '\333',
  '\334', '\335', '\336', '\337', '\352', '\353', '\354', '\355',
  '\356', '\357', '\372', '\373', '\374', '\375', '\376', '\377'
};

static char const ebcdic_to_ascii[] =
{
  '\000', '\001', '\002', '\003', '\234', '\011', '\206', '\177',
  '\227', '\215', '\216', '\013', '\014', '\015', '\016', '\017',
  '\020', '\021', '\022', '\023', '\235', '\205', '\010', '\207',
  '\030', '\031', '\222', '\217', '\034', '\035', '\036', '\037',
  '\200', '\201', '\202', '\203', '\204', '\012', '\027', '\033',
  '\210', '\211', '\212', '\213', '\214', '\005', '\006', '\007',
  '\220', '\221', '\026', '\223', '\224', '\225', '\226', '\004',
  '\230', '\231', '\232', '\233', '\024', '\025', '\236', '\032',
  '\040', '\240', '\241', '\242', '\243', '\244', '\245', '\246',
  '\247', '\250', '\325', '\056', '\074', '\050', '\053', '\174',
  '\046', '\251', '\252', '\253', '\254', '\255', '\256', '\257',
  '\260', '\261', '\041', '\044', '\052', '\051', '\073', '\176',
  '\055', '\057', '\262', '\263', '\264', '\265', '\266', '\267',
  '\270', '\271', '\313', '\054', '\045', '\137', '\076', '\077',
  '\272', '\273', '\274', '\275', '\276', '\277', '\300', '\301',
  '\302', '\140', '\072', '\043', '\100', '\047', '\075', '\042',
  '\303', '\141', '\142', '\143', '\144', '\145', '\146', '\147',
  '\150', '\151', '\304', '\305', '\306', '\307', '\310', '\311',
  '\312', '\152', '\153', '\154', '\155', '\156', '\157', '\160',
  '\161', '\162', '\136', '\314', '\315', '\316', '\317', '\320',
  '\321', '\345', '\163', '\164', '\165', '\166', '\167', '\170',
  '\171', '\172', '\322', '\323', '\324', '\133', '\326', '\327',
  '\330', '\331', '\332', '\333', '\334', '\335', '\336', '\337',
  '\340', '\341', '\342', '\343', '\344', '\135', '\346', '\347',
  '\173', '\101', '\102', '\103', '\104', '\105', '\106', '\107',
  '\110', '\111', '\350', '\351', '\352', '\353', '\354', '\355',
  '\175', '\112', '\113', '\114', '\115', '\116', '\117', '\120',
  '\121', '\122', '\356', '\357', '\360', '\361', '\362', '\363',
  '\134', '\237', '\123', '\124', '\125', '\126', '\127', '\130',
  '\131', '\132', '\364', '\365', '\366', '\367', '\370', '\371',
  '\060', '\061', '\062', '\063', '\064', '\065', '\066', '\067',
  '\070', '\071', '\372', '\373', '\374', '\375', '\376', '\377'
};

/* True if we need to close the standard output *stream*.  */
static bool close_stdout_required = true;

/* The only reason to close the standard output *stream* is if
   parse_long_options fails (as it does for --help or --version).
   In any other case, dd uses only the STDOUT_FILENO file descriptor,
   and the "cleanup" function calls "close (STDOUT_FILENO)".
   Closing the file descriptor and then letting the usual atexit-run
   close_stdout function call "fclose (stdout)" would result in a
   harmless failure of the close syscall (with errno EBADF).
   This function serves solely to avoid the unnecessary close_stdout
   call, once parse_long_options has succeeded.
   Meanwhile, we guarantee that the standard error stream is flushed,
   by inlining the last half of close_stdout as needed.  */
static void
maybe_close_stdout (void)
{
  if (close_stdout_required)
    close_stdout ();
  else if (close_stream (stderr) != 0)
    _exit (EXIT_FAILURE);
}

/* Like error() but handle any pending newline.  */

static void _GL_ATTRIBUTE_FORMAT ((__printf__, 3, 4))
nl_error (int status, int errnum, const char *fmt, ...)
{
  if (0 < progress_len)
    {
      fputc ('\n', stderr);
      progress_len = 0;
    }

  va_list ap;
  va_start (ap, fmt);
  verror (status, errnum, fmt, ap);
  va_end (ap);
}

#define error nl_error

void
usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("\
Usage: %s [OPERAND]...\n\
  or:  %s OPTION\n\
"),
              program_name, program_name);
      fputs (_("\
Copy a file, converting and formatting according to the operands.\n\
\n\
  bs=BYTES        read and write up to BYTES bytes at a time\n\
  cbs=BYTES       convert BYTES bytes at a time\n\
  conv=CONVS      convert the file as per the comma separated symbol list\n\
  count=N         copy only N input blocks\n\
  ibs=BYTES       read up to BYTES bytes at a time (default: 512)\n\
"), stdout);
      fputs (_("\
  if=FILE         read from FILE instead of stdin\n\
  iflag=FLAGS     read as per the comma separated symbol list\n\
  obs=BYTES       write BYTES bytes at a time (default: 512)\n\
  of=FILE         write to FILE instead of stdout\n\
  oflag=FLAGS     write as per the comma separated symbol list\n\
  seek=N          skip N obs-sized blocks at start of output\n\
  skip=N          skip N ibs-sized blocks at start of input\n\
  status=LEVEL    The LEVEL of information to print to stderr;\n\
                  'none' suppresses everything but error messages,\n\
                  'noxfer' suppresses the final transfer statistics,\n\
                  'progress' shows periodic transfer statistics\n\
"), stdout);
      fputs (_("\
\n\
N and BYTES may be followed by the following multiplicative suffixes:\n\
c =1, w =2, b =512, kB =1000, K =1024, MB =1000*1000, M =1024*1024, xM =M,\n\
GB =1000*1000*1000, G =1024*1024*1024, and so on for T, P, E, Z, Y.\n\
\n\
Each CONV symbol may be:\n\
\n\
"), stdout);
      fputs (_("\
  ascii     from EBCDIC to ASCII\n\
  ebcdic    from ASCII to EBCDIC\n\
  ibm       from ASCII to alternate EBCDIC\n\
  block     pad newline-terminated records with spaces to cbs-size\n\
  unblock   replace trailing spaces in cbs-size records with newline\n\
  lcase     change upper case to lower case\n\
  ucase     change lower case to upper case\n\
  sparse    try to seek rather than write the output for NUL input blocks\n\
  swab      swap every pair of input bytes\n\
  sync      pad every input block with NULs to ibs-size; when used\n\
            with block or unblock, pad with spaces rather than NULs\n\
"), stdout);
      fputs (_("\
  excl      fail if the output file already exists\n\
  nocreat   do not create the output file\n\
  notrunc   do not truncate the output file\n\
  noerror   continue after read errors\n\
  fdatasync  physically write output file data before finishing\n\
  fsync     likewise, but also write metadata\n\
"), stdout);
      fputs (_("\
\n\
Each FLAG symbol may be:\n\
\n\
  append    append mode (makes sense only for output; conv=notrunc suggested)\n\
"), stdout);
      if (O_CIO)
        fputs (_("  cio       use concurrent I/O for data\n"), stdout);
      if (O_DIRECT)
        fputs (_("  direct    use direct I/O for data\n"), stdout);
      if (O_DIRECTORY)
        fputs (_("  directory  fail unless a directory\n"), stdout);
      if (O_DSYNC)
        fputs (_("  dsync     use synchronized I/O for data\n"), stdout);
      if (O_SYNC)
        fputs (_("  sync      likewise, but also for metadata\n"), stdout);
      fputs (_("  fullblock  accumulate full blocks of input (iflag only)\n"),
             stdout);
      if (O_NONBLOCK)
        fputs (_("  nonblock  use non-blocking I/O\n"), stdout);
      if (O_NOATIME)
        fputs (_("  noatime   do not update access time\n"), stdout);
#if HAVE_POSIX_FADVISE
      if (O_NOCACHE)
        fputs (_("  nocache   Request to drop cache.  See also oflag=sync\n"),
               stdout);
#endif
      if (O_NOCTTY)
        fputs (_("  noctty    do not assign controlling terminal from file\n"),
               stdout);
      if (HAVE_WORKING_O_NOFOLLOW)
        fputs (_("  nofollow  do not follow symlinks\n"), stdout);
      if (O_NOLINKS)
        fputs (_("  nolinks   fail if multiply-linked\n"), stdout);
      if (O_BINARY)
        fputs (_("  binary    use binary I/O for data\n"), stdout);
      if (O_TEXT)
        fputs (_("  text      use text I/O for data\n"), stdout);
      if (O_COUNT_BYTES)
        fputs (_("  count_bytes  treat 'count=N' as a byte count (iflag only)\n\
"), stdout);
      if (O_SKIP_BYTES)
        fputs (_("  skip_bytes  treat 'skip=N' as a byte count (iflag only)\n\
"), stdout);
      if (O_SEEK_BYTES)
        fputs (_("  seek_bytes  treat 'seek=N' as a byte count (oflag only)\n\
"), stdout);

      {
        printf (_("\
\n\
Sending a %s signal to a running 'dd' process makes it\n\
print I/O statistics to standard error and then resume copying.\n\
\n\
Options are:\n\
\n\
"), SIGINFO == SIGUSR1 ? "USR1" : "INFO");
      }

      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}

/* Common options to use when displaying sizes and rates.  */

enum { human_opts = (human_autoscale | human_round_to_nearest
                     | human_space_before_unit | human_SI | human_B) };

/* Ensure input buffer IBUF is allocated.  */

static void
alloc_ibuf (void)
{
  if (ibuf)
    return;

  char *real_buf = malloc (input_blocksize + INPUT_BLOCK_SLOP);
  if (!real_buf)
    {
      uintmax_t ibs = input_blocksize;
      char hbuf[LONGEST_HUMAN_READABLE + 1];
      die (EXIT_FAILURE, 0,
           _("memory exhausted by input buffer of size %"PRIuMAX" bytes (%s)"),
           ibs,
           human_readable (input_blocksize, hbuf,
                           human_opts | human_base_1024, 1, 1));
    }

  real_buf += SWAB_ALIGN_OFFSET;	/* allow space for swab */

  ibuf = ptr_align (real_buf, page_size);
}

/* Ensure output buffer OBUF is allocated/initialized.  */

static void
alloc_obuf (void)
{
  if (obuf)
    return;

  if (conversions_mask & C_TWOBUFS)
    {
      /* Page-align the output buffer, too.  */
      char *real_obuf = malloc (output_blocksize + OUTPUT_BLOCK_SLOP);
      if (!real_obuf)
        {
          uintmax_t obs = output_blocksize;
          char hbuf[LONGEST_HUMAN_READABLE + 1];
          die (EXIT_FAILURE, 0,
               _("memory exhausted by output buffer of size %"PRIuMAX
                 " bytes (%s)"),
               obs,
               human_readable (output_blocksize, hbuf,
                               human_opts | human_base_1024, 1, 1));
        }
      obuf = ptr_align (real_obuf, page_size);
    }
  else
    {
      alloc_ibuf ();
      obuf = ibuf;
    }
}

static void
translate_charset (char const *new_trans)
{
  int i;

  for (i = 0; i < 256; i++)
    trans_table[i] = new_trans[trans_table[i]];
  translation_needed = true;
}

/* Return true if I has more than one bit set.  I must be nonnegative.  */

static inline bool
multiple_bits_set (int i)
{
  return MULTIPLE_BITS_SET (i);
}

static bool
abbreviation_lacks_prefix (char const *message)
{
  return message[strlen (message) - 2] == ' ';
}

/* Print transfer statistics.  */

static void
print_xfer_stats (xtime_t progress_time)
{
  xtime_t now = progress_time ? progress_time : gethrxtime ();
  char hbuf[3][LONGEST_HUMAN_READABLE + 1];
  double delta_s;
  char const *bytes_per_second;
  char const *si = human_readable (w_bytes, hbuf[0], human_opts, 1, 1);
  char const *iec = human_readable (w_bytes, hbuf[1],
                                    human_opts | human_base_1024, 1, 1);

  /* Use integer arithmetic to compute the transfer rate,
     since that makes it easy to use SI abbreviations.  */
  if (start_time < now)
    {
      double XTIME_PRECISIONe0 = XTIME_PRECISION;
      uintmax_t delta_xtime = now;
      delta_xtime -= start_time;
      delta_s = delta_xtime / XTIME_PRECISIONe0;
      bytes_per_second = human_readable (w_bytes, hbuf[2], human_opts,
                                         XTIME_PRECISION, delta_xtime);
    }
  else
    {
      delta_s = 0;
      bytes_per_second = _("Infinity B");
    }

  if (progress_time)
    fputc ('\r', stderr);

  /* TRANSLATORS: The instances of "s" in the following formats are
     the SI symbol "s" (meaning second), and should not be translated.
     The strings use SI symbols for better internationalization even
     though they may be a bit more confusing in English.  If one of
     these formats A looks shorter on the screen than another format
     B, then A's string length should be less than B's, and appending
     strlen (B) - strlen (A) spaces to A should make it appear to be
     at least as long as B.  */

  int stats_len
    = (abbreviation_lacks_prefix (si)
       ? fprintf (stderr,
                  ngettext ("%"PRIuMAX" byte copied, %g s, %s/s",
                            "%"PRIuMAX" bytes copied, %g s, %s/s",
                            select_plural (w_bytes)),
                  w_bytes, delta_s, bytes_per_second)
       : abbreviation_lacks_prefix (iec)
       ? fprintf (stderr,
                  _("%"PRIuMAX" bytes (%s) copied, %g s, %s/s"),
                  w_bytes, si, delta_s, bytes_per_second)
       : fprintf (stderr,
                  _("%"PRIuMAX" bytes (%s, %s) copied, %g s, %s/s"),
                  w_bytes, si, iec, delta_s, bytes_per_second));

  if (progress_time)
    {
      if (0 <= stats_len && stats_len < progress_len)
        fprintf (stderr, "%*s", progress_len - stats_len, "");
      progress_len = stats_len;
    }
  else
    fputc ('\n', stderr);
}

static void
print_stats (void)
{
  if (status_level == STATUS_NONE)
    return;

  if (0 < progress_len)
    {
      fputc ('\n', stderr);
      progress_len = 0;
    }

  fprintf (stderr,
           _("%"PRIuMAX"+%"PRIuMAX" records in\n"
             "%"PRIuMAX"+%"PRIuMAX" records out\n"),
           r_full, r_partial, w_full, w_partial);

  if (r_truncate != 0)
    fprintf (stderr,
             ngettext ("%"PRIuMAX" truncated record\n",
                       "%"PRIuMAX" truncated records\n",
                       select_plural (r_truncate)),
             r_truncate);

  if (status_level == STATUS_NOXFER)
    return;

  print_xfer_stats (0);
}

/* An ordinary signal was received; arrange for the program to exit.  */

static void
interrupt_handler (int sig)
{
  if (! SA_RESETHAND)
    signal (sig, SIG_DFL);
  interrupt_signal = sig;
}

/* An info signal was received; arrange for the program to print status.  */

static void
siginfo_handler (int sig)
{
  if (! SA_NOCLDSTOP)
    signal (sig, siginfo_handler);
  info_signal_count++;
}

/* Install the signal handlers.  */

static void
install_signal_handlers (void)
{
  bool catch_siginfo = ! (SIGINFO == SIGUSR1 && getenv ("POSIXLY_CORRECT"));

#if SA_NOCLDSTOP

  struct sigaction act;
  sigemptyset (&caught_signals);
  if (catch_siginfo)
    sigaddset (&caught_signals, SIGINFO);
  sigaction (SIGINT, NULL, &act);
  if (act.sa_handler != SIG_IGN)
    sigaddset (&caught_signals, SIGINT);
  act.sa_mask = caught_signals;

  if (sigismember (&caught_signals, SIGINFO))
    {
      act.sa_handler = siginfo_handler;
      /* Note we don't use SA_RESTART here and instead
         handle EINTR explicitly in iftruncate() etc.
         to avoid blocking on noncommitted read()/write() calls.  */
      act.sa_flags = 0;
      sigaction (SIGINFO, &act, NULL);
    }

  if (sigismember (&caught_signals, SIGINT))
    {
      act.sa_handler = interrupt_handler;
      act.sa_flags = SA_NODEFER | SA_RESETHAND;
      sigaction (SIGINT, &act, NULL);
    }

#else

  if (catch_siginfo)
    {
      signal (SIGINFO, siginfo_handler);
      siginterrupt (SIGINFO, 1);
    }
  if (signal (SIGINT, SIG_IGN) != SIG_IGN)
    {
      signal (SIGINT, interrupt_handler);
      siginterrupt (SIGINT, 1);
    }
#endif
}

static void
cleanup (void)
{
  if (close (STDIN_FILENO) < 0)
    die (EXIT_FAILURE, errno, _("closing input file %s"), quoteaf (input_file));

  /* Don't remove this call to close, even though close_stdout
     closes standard output.  This close is necessary when cleanup
     is called as part of a signal handler.  */
  if (close (STDOUT_FILENO) < 0)
    die (EXIT_FAILURE, errno,
         _("closing output file %s"), quoteaf (output_file));
}

/* Process any pending signals.  If signals are caught, this function
   should be called periodically.  Ideally there should never be an
   unbounded amount of time when signals are not being processed.  */

static void
process_signals (void)
{
  while (interrupt_signal || info_signal_count)
    {
      int interrupt;
      int infos;
      sigset_t oldset;

      sigprocmask (SIG_BLOCK, &caught_signals, &oldset);

      /* Reload interrupt_signal and info_signal_count, in case a new
         signal was handled before sigprocmask took effect.  */
      interrupt = interrupt_signal;
      infos = info_signal_count;

      if (infos)
        info_signal_count = infos - 1;

      sigprocmask (SIG_SETMASK, &oldset, NULL);

      if (interrupt)
        cleanup ();
      print_stats ();
      if (interrupt)
        raise (interrupt);
    }
}

static void
finish_up (void)
{
  cleanup ();
  print_stats ();
  process_signals ();
}

static void ATTRIBUTE_NORETURN
quit (int code)
{
  finish_up ();
  exit (code);
}

/* Return LEN rounded down to a multiple of PAGE_SIZE
   while storing the remainder internally per FD.
   Pass LEN == 0 to get the current remainder.  */

static off_t
cache_round (int fd, off_t len)
{
  static off_t i_pending, o_pending;
  off_t *pending = (fd == STDIN_FILENO ? &i_pending : &o_pending);

  if (len)
    {
      uintmax_t c_pending = *pending + len;
      *pending = c_pending % page_size;
      if (c_pending > *pending)
        len = c_pending - *pending;
      else
        len = 0;
    }
  else
    len = *pending;

  return len;
}

/* Discard the cache from the current offset of either
   STDIN_FILENO or STDOUT_FILENO.
   Return true on success.  */

static bool
invalidate_cache (int fd, off_t len)
{
  int adv_ret = -1;

  /* Minimize syscalls.  */
  off_t clen = cache_round (fd, len);
  if (len && !clen)
    return true; /* Don't advise this time.  */
  if (!len && !clen && max_records)
    return true; /* Nothing pending.  */
  off_t pending = len ? cache_round (fd, 0) : 0;

  if (fd == STDIN_FILENO)
    {
      if (input_seekable)
        {
          /* Note we're being careful here to only invalidate what
             we've read, so as not to dump any read ahead cache.  */
#if HAVE_POSIX_FADVISE
            adv_ret = posix_fadvise (fd, input_offset - clen - pending, clen,
                                     POSIX_FADV_DONTNEED);
#else
            errno = ENOTSUP;
#endif
        }
      else
        errno = ESPIPE;
    }
  else if (fd == STDOUT_FILENO)
    {
      static off_t output_offset = -2;

      if (output_offset != -1)
        {
          if (0 > output_offset)
            {
              output_offset = lseek (fd, 0, SEEK_CUR);
              output_offset -= clen + pending;
            }
          if (0 <= output_offset)
            {
#if HAVE_POSIX_FADVISE
              adv_ret = posix_fadvise (fd, output_offset, clen,
                                       POSIX_FADV_DONTNEED);
#else
              errno = ENOTSUP;
#endif
              output_offset += clen + pending;
            }
        }
    }

  return adv_ret != -1 ? true : false;
}

/* Read from FD into the buffer BUF of size SIZE, processing any
   signals that arrive before bytes are read.  Return the number of
   bytes read if successful, -1 (setting errno) on failure.  */

static ssize_t
iread (int fd, char *buf, size_t size)
{
  ssize_t nread;

  do
    {
      process_signals ();
      nread = read (fd, buf, size);
    }
  while (nread < 0 && errno == EINTR);

  /* Short read may be due to received signal.  */
  if (0 < nread && nread < size)
    process_signals ();

  if (0 < nread && warn_partial_read)
    {
      static ssize_t prev_nread;

      if (0 < prev_nread && prev_nread < size)
        {
          uintmax_t prev = prev_nread;
          if (status_level != STATUS_NONE)
            error (0, 0, ngettext (("warning: partial read (%"PRIuMAX" byte); "
                                    "suggest iflag=fullblock"),
                                   ("warning: partial read (%"PRIuMAX" bytes); "
                                    "suggest iflag=fullblock"),
                                   select_plural (prev)),
                   prev);
          warn_partial_read = false;
        }

      prev_nread = nread;
    }

  return nread;
}

/* Wrapper around iread function to accumulate full blocks.  */
static ssize_t
iread_fullblock (int fd, char *buf, size_t size)
{
  ssize_t nread = 0;

  while (0 < size)
    {
      ssize_t ncurr = iread (fd, buf, size);
      if (ncurr < 0)
        return ncurr;
      if (ncurr == 0)
        break;
      nread += ncurr;
      buf   += ncurr;
      size  -= ncurr;
    }

  return nread;
}

/* Write to FD the buffer BUF of size SIZE, processing any signals
   that arrive.  Return the number of bytes written, setting errno if
   this is less than SIZE.  Keep trying if there are partial
   writes.  */

static size_t
iwrite (int fd, char const *buf, size_t size)
{
  size_t total_written = 0;

  if ((output_flags & O_DIRECT) && size < output_blocksize)
    {
      int old_flags = fcntl (STDOUT_FILENO, F_GETFL);
      if (fcntl (STDOUT_FILENO, F_SETFL, old_flags & ~O_DIRECT) != 0
          && status_level != STATUS_NONE)
        error (0, errno, _("failed to turn off O_DIRECT: %s"),
               quotef (output_file));

      /* Since we have just turned off O_DIRECT for the final write,
         here we try to preserve some of its semantics.  First, use
         posix_fadvise to tell the system not to pollute the buffer
         cache with this data.  Don't bother to diagnose lseek or
         posix_fadvise failure. */
      invalidate_cache (STDOUT_FILENO, 0);

      /* Attempt to ensure that that final block is committed
         to disk as quickly as possible.  */
      conversions_mask |= C_FSYNC;
    }

  while (total_written < size)
    {
      ssize_t nwritten = 0;
      process_signals ();

      /* Perform a seek for a NUL block if sparse output is enabled.  */
      final_op_was_seek = false;
      if ((conversions_mask & C_SPARSE) && is_nul (buf, size))
        {
          if (lseek (fd, size, SEEK_CUR) < 0)
            {
              conversions_mask &= ~C_SPARSE;
              /* Don't warn about the advisory sparse request.  */
            }
          else
            {
              final_op_was_seek = true;
              nwritten = size;
            }
        }

      if (!nwritten)
        nwritten = write (fd, buf + total_written, size - total_written);

      if (nwritten < 0)
        {
          if (errno != EINTR)
            break;
        }
      else if (nwritten == 0)
        {
          /* Some buggy drivers return 0 when one tries to write beyond
             a device's end.  (Example: Linux kernel 1.2.13 on /dev/fd0.)
             Set errno to ENOSPC so they get a sensible diagnostic.  */
          errno = ENOSPC;
          break;
        }
      else
        total_written += nwritten;
    }

  if (o_nocache && total_written)
    invalidate_cache (fd, total_written);

  return total_written;
}

/* Write, then empty, the output buffer 'obuf'. */

static void
write_output (void)
{
  size_t nwritten = iwrite (STDOUT_FILENO, obuf, output_blocksize);
  w_bytes += nwritten;
  if (nwritten != output_blocksize)
    {
      error (0, errno, _("writing to %s"), quoteaf (output_file));
      if (nwritten != 0)
        w_partial++;
      quit (EXIT_FAILURE);
    }
  else
    w_full++;
  oc = 0;
}

/* Restart on EINTR from fd_reopen().  */

static int
ifd_reopen (int desired_fd, char const *file, int flag, mode_t mode)
{
  int ret;

  do
    {
      process_signals ();
      ret = fd_reopen (desired_fd, file, flag, mode);
    }
  while (ret < 0 && errno == EINTR);

  return ret;
}

/* Restart on EINTR from ftruncate().  */

static int
iftruncate (int fd, off_t length)
{
  int ret;

  do
    {
      process_signals ();
      ret = ftruncate (fd, length);
    }
  while (ret < 0 && errno == EINTR);

  return ret;
}

/* Return true if STR is of the form "PATTERN" or "PATTERNDELIM...".  */

static bool _GL_ATTRIBUTE_PURE
operand_matches (char const *str, char const *pattern, char delim)
{
  while (*pattern)
    if (*str++ != *pattern++)
      return false;
  return !*str || *str == delim;
}

/* Interpret one "conv=..." or similar operand STR according to the
   symbols in TABLE, returning the flags specified.  If the operand
   cannot be parsed, use ERROR_MSGID to generate a diagnostic.  */

static int
parse_symbols (char const *str, struct symbol_value const *table,
               bool exclusive, char const *error_msgid)
{
  int value = 0;

  while (true)
    {
      char const *strcomma = strchr (str, ',');
      struct symbol_value const *entry;

      for (entry = table;
           ! (operand_matches (str, entry->symbol, ',') && entry->value);
           entry++)
        {
          if (! entry->symbol[0])
            {
              size_t slen = strcomma ? strcomma - str : strlen (str);
              error (0, 0, "%s: %s", _(error_msgid),
                     quotearg_n_style_mem (0, locale_quoting_style, str, slen));
              usage (EXIT_FAILURE);
            }
        }

      if (exclusive)
        value = entry->value;
      else
        value |= entry->value;
      if (!strcomma)
        break;
      str = strcomma + 1;
    }

  return value;
}

/* Return the value of STR, interpreted as a non-negative decimal integer,
   optionally multiplied by various values.
   Set *INVALID to a nonzero error value if STR does not represent a
   number in this format.  */

static uintmax_t
parse_integer (const char *str, strtol_error *invalid)
{
  uintmax_t n;
  char *suffix;
  strtol_error e = xstrtoumax (str, &suffix, 10, &n, "bcEGkKMPTwYZ0");

  if (e == LONGINT_INVALID_SUFFIX_CHAR && *suffix == 'x')
    {
      uintmax_t multiplier = parse_integer (suffix + 1, invalid);

      if (multiplier != 0 && n * multiplier / multiplier != n)
        {
          *invalid = LONGINT_OVERFLOW;
          return 0;
        }

      if (n == 0 && STRPREFIX (str, "0x"))
        error (0, 0,
               _("warning: %s is a zero multiplier; "
                 "use %s if that is intended"),
               quote_n (0, "0x"), quote_n (1, "00x"));

      n *= multiplier;
    }
  else if (e != LONGINT_OK)
    {
      *invalid = e;
      return 0;
    }

  return n;
}

/* OPERAND is of the form "X=...".  Return true if X is NAME.  */

static bool _GL_ATTRIBUTE_PURE
operand_is (char const *operand, char const *name)
{
  return operand_matches (operand, name, '=');
}

static void
scanargs (int argc, char *const *argv)
{
  int i;
  size_t blocksize = 0;
  uintmax_t count = (uintmax_t) -1;
  uintmax_t skip = 0;
  uintmax_t seek = 0;

  for (i = optind; i < argc; i++)
    {
      char const *name = argv[i];
      char const *val = strchr (name, '=');

      if (val == NULL)
        {
          error (0, 0, _("unrecognized operand %s"),
                 quote (name));
          usage (EXIT_FAILURE);
        }
      val++;

      if (operand_is (name, "if"))
        input_file = val;
      else if (operand_is (name, "of"))
        output_file = val;
      else if (operand_is (name, "conv"))
        conversions_mask |= parse_symbols (val, conversions, false,
                                           N_("invalid conversion"));
      else if (operand_is (name, "iflag"))
        input_flags |= parse_symbols (val, flags, false,
                                      N_("invalid input flag"));
      else if (operand_is (name, "oflag"))
        output_flags |= parse_symbols (val, flags, false,
                                       N_("invalid output flag"));
      else if (operand_is (name, "status"))
        status_level = parse_symbols (val, statuses, true,
                                      N_("invalid status level"));
      else
        {
          strtol_error invalid = LONGINT_OK;
          uintmax_t n = parse_integer (val, &invalid);
          uintmax_t n_min = 0;
          uintmax_t n_max = UINTMAX_MAX;

          if (operand_is (name, "ibs"))
            {
              n_min = 1;
              n_max = MAX_BLOCKSIZE (INPUT_BLOCK_SLOP);
              input_blocksize = n;
            }
          else if (operand_is (name, "obs"))
            {
              n_min = 1;
              n_max = MAX_BLOCKSIZE (OUTPUT_BLOCK_SLOP);
              output_blocksize = n;
            }
          else if (operand_is (name, "bs"))
            {
              n_min = 1;
              n_max = MAX_BLOCKSIZE (INPUT_BLOCK_SLOP);
              blocksize = n;
            }
          else if (operand_is (name, "cbs"))
            {
              n_min = 1;
              n_max = SIZE_MAX;
              conversion_blocksize = n;
            }
          else if (operand_is (name, "skip"))
            skip = n;
          else if (operand_is (name, "seek"))
            seek = n;
          else if (operand_is (name, "count"))
            count = n;
          else
            {
              error (0, 0, _("unrecognized operand %s"),
                     quote (name));
              usage (EXIT_FAILURE);
            }

          if (n < n_min)
            invalid = LONGINT_INVALID;
          else if (n_max < n)
            invalid = LONGINT_OVERFLOW;

          if (invalid != LONGINT_OK)
            die (EXIT_FAILURE, invalid == LONGINT_OVERFLOW ? EOVERFLOW : 0,
                 "%s: %s", _("invalid number"), quote (val));
        }
    }

  if (blocksize)
    input_blocksize = output_blocksize = blocksize;
  else
    {
      /* POSIX says dd aggregates partial reads into
         output_blocksize if bs= is not specified.  */
      conversions_mask |= C_TWOBUFS;
    }

  if (input_blocksize == 0)
    input_blocksize = DEFAULT_BLOCKSIZE;
  if (output_blocksize == 0)
    output_blocksize = DEFAULT_BLOCKSIZE;
  if (conversion_blocksize == 0)
    conversions_mask &= ~(C_BLOCK | C_UNBLOCK);

  if (input_flags & (O_DSYNC | O_SYNC))
    input_flags |= O_RSYNC;

  if (output_flags & O_FULLBLOCK)
    {
      error (0, 0, "%s: %s", _("invalid output flag"), quote ("fullblock"));
      usage (EXIT_FAILURE);
    }

  if (input_flags & O_SEEK_BYTES)
    {
      error (0, 0, "%s: %s", _("invalid input flag"), quote ("seek_bytes"));
      usage (EXIT_FAILURE);
    }

  if (output_flags & (O_COUNT_BYTES | O_SKIP_BYTES))
    {
      error (0, 0, "%s: %s", _("invalid output flag"),
             quote (output_flags & O_COUNT_BYTES
                    ? "count_bytes" : "skip_bytes"));
      usage (EXIT_FAILURE);
    }

  if (input_flags & O_SKIP_BYTES && skip != 0)
    {
      skip_records = skip / input_blocksize;
      skip_bytes = skip % input_blocksize;
    }
  else if (skip != 0)
    skip_records = skip;

  if (input_flags & O_COUNT_BYTES && count != (uintmax_t) -1)
    {
      max_records = count / input_blocksize;
      max_bytes = count % input_blocksize;
    }
  else if (count != (uintmax_t) -1)
    max_records = count;

  if (output_flags & O_SEEK_BYTES && seek != 0)
    {
      seek_records = seek / output_blocksize;
      seek_bytes = seek % output_blocksize;
    }
  else if (seek != 0)
    seek_records = seek;

  /* Warn about partial reads if bs=SIZE is given and iflag=fullblock
     is not, and if counting or skipping bytes or using direct I/O.
     This helps to avoid confusion with miscounts, and to avoid issues
     with direct I/O on GNU/Linux.  */
  warn_partial_read =
    (! (conversions_mask & C_TWOBUFS) && ! (input_flags & O_FULLBLOCK)
     && (skip_records
         || (0 < max_records && max_records < (uintmax_t) -1)
         || (input_flags | output_flags) & O_DIRECT));

  iread_fnc = ((input_flags & O_FULLBLOCK)
               ? iread_fullblock
               : iread);
  input_flags &= ~O_FULLBLOCK;

  if (multiple_bits_set (conversions_mask & (C_ASCII | C_EBCDIC | C_IBM)))
    die (EXIT_FAILURE, 0, _("cannot combine any two of {ascii,ebcdic,ibm}"));
  if (multiple_bits_set (conversions_mask & (C_BLOCK | C_UNBLOCK)))
    die (EXIT_FAILURE, 0, _("cannot combine block and unblock"));
  if (multiple_bits_set (conversions_mask & (C_LCASE | C_UCASE)))
    die (EXIT_FAILURE, 0, _("cannot combine lcase and ucase"));
  if (multiple_bits_set (conversions_mask & (C_EXCL | C_NOCREAT)))
    die (EXIT_FAILURE, 0, _("cannot combine excl and nocreat"));
  if (multiple_bits_set (input_flags & (O_DIRECT | O_NOCACHE))
      || multiple_bits_set (output_flags & (O_DIRECT | O_NOCACHE)))
    die (EXIT_FAILURE, 0, _("cannot combine direct and nocache"));

  if (input_flags & O_NOCACHE)
    {
      i_nocache = true;
      input_flags &= ~O_NOCACHE;
    }
  if (output_flags & O_NOCACHE)
    {
      o_nocache = true;
      output_flags &= ~O_NOCACHE;
    }
}

/* Fix up translation table. */

static void
apply_translations (void)
{
  int i;

  if (conversions_mask & C_ASCII)
    translate_charset (ebcdic_to_ascii);

  if (conversions_mask & C_UCASE)
    {
      for (i = 0; i < 256; i++)
        trans_table[i] = toupper (trans_table[i]);
      translation_needed = true;
    }
  else if (conversions_mask & C_LCASE)
    {
      for (i = 0; i < 256; i++)
        trans_table[i] = tolower (trans_table[i]);
      translation_needed = true;
    }

  if (conversions_mask & C_EBCDIC)
    {
      translate_charset (ascii_to_ebcdic);
      newline_character = ascii_to_ebcdic['\n'];
      space_character = ascii_to_ebcdic[' '];
    }
  else if (conversions_mask & C_IBM)
    {
      translate_charset (ascii_to_ibm);
      newline_character = ascii_to_ibm['\n'];
      space_character = ascii_to_ibm[' '];
    }
}

/* Apply the character-set translations specified by the user
   to the NREAD bytes in BUF.  */

static void
translate_buffer (char *buf, size_t nread)
{
  char *cp;
  size_t i;

  for (i = nread, cp = buf; i; i--, cp++)
    *cp = trans_table[to_uchar (*cp)];
}

/* If true, the last char from the previous call to 'swab_buffer'
   is saved in 'saved_char'.  */
static bool char_is_saved = false;

/* Odd char from previous call.  */
static char saved_char;

/* Swap NREAD bytes in BUF, plus possibly an initial char from the
   previous call.  If NREAD is odd, save the last char for the
   next call.   Return the new start of the BUF buffer.  */

static char *
swab_buffer (char *buf, size_t *nread)
{
  char *bufstart = buf;
  char *cp;
  size_t i;

  /* Is a char left from last time?  */
  if (char_is_saved)
    {
      *--bufstart = saved_char;
      (*nread)++;
      char_is_saved = false;
    }

  if (*nread & 1)
    {
      /* An odd number of chars are in the buffer.  */
      saved_char = bufstart[--*nread];
      char_is_saved = true;
    }

  /* Do the byte-swapping by moving every second character two
     positions toward the end, working from the end of the buffer
     toward the beginning.  This way we only move half of the data.  */

  cp = bufstart + *nread;	/* Start one char past the last.  */
  for (i = *nread / 2; i; i--, cp -= 2)
    *cp = *(cp - 2);

  return ++bufstart;
}

/* Add OFFSET to the input offset, setting the overflow flag if
   necessary.  */

static void
advance_input_offset (uintmax_t offset)
{
  input_offset += offset;
  if (input_offset < offset)
    input_offset_overflow = true;
}

/* This is a wrapper for lseek.  It detects and warns about a kernel
   bug that makes lseek a no-op for tape devices, even though the kernel
   lseek return value suggests that the function succeeded.

   The parameters are the same as those of the lseek function, but
   with the addition of FILENAME, the name of the file associated with
   descriptor FDESC.  The file name is used solely in the warning that's
   printed when the bug is detected.  Return the same value that lseek
   would have returned, but when the lseek bug is detected, return -1
   to indicate that lseek failed.

   The offending behavior has been confirmed with an Exabyte SCSI tape
   drive accessed via /dev/nst0 on both Linux 2.2.17 and 2.4.16 kernels.  */

#ifdef __linux__

# include <sys/mtio.h>

# define MT_SAME_POSITION(P, Q) \
   ((P).mt_resid == (Q).mt_resid \
    && (P).mt_fileno == (Q).mt_fileno \
    && (P).mt_blkno == (Q).mt_blkno)

static off_t
skip_via_lseek (char const *filename, int fdesc, off_t offset, int whence)
{
  struct mtget s1;
  struct mtget s2;
  bool got_original_tape_position = (ioctl (fdesc, MTIOCGET, &s1) == 0);
  /* known bad device type */
  /* && s.mt_type == MT_ISSCSI2 */

  off_t new_position = lseek (fdesc, offset, whence);
  if (0 <= new_position
      && got_original_tape_position
      && ioctl (fdesc, MTIOCGET, &s2) == 0
      && MT_SAME_POSITION (s1, s2))
    {
      if (status_level != STATUS_NONE)
        error (0, 0, _("warning: working around lseek kernel bug for file "
                       "(%s)\n  of mt_type=0x%0lx -- "
                       "see <sys/mtio.h> for the list of types"),
               filename, s2.mt_type + 0Lu);
      errno = 0;
      new_position = -1;
    }

  return new_position;
}
#else
# define skip_via_lseek(Filename, Fd, Offset, Whence) lseek (Fd, Offset, Whence)
#endif

/* Throw away RECORDS blocks of BLOCKSIZE bytes plus BYTES bytes on
   file descriptor FDESC, which is open with read permission for FILE.
   Store up to BLOCKSIZE bytes of the data at a time in IBUF or OBUF, if
   necessary. RECORDS or BYTES must be nonzero. If FDESC is
   STDIN_FILENO, advance the input offset. Return the number of
   records remaining, i.e., that were not skipped because EOF was
   reached.  If FDESC is STDOUT_FILENO, on return, BYTES is the
   remaining bytes in addition to the remaining records.  */

static uintmax_t
skip (int fdesc, char const *file, uintmax_t records, size_t blocksize,
      size_t *bytes)
{
  uintmax_t offset = records * blocksize + *bytes;

  /* Try lseek and if an error indicates it was an inappropriate operation --
     or if the file offset is not representable as an off_t --
     fall back on using read.  */

  errno = 0;
  if (records <= OFF_T_MAX / blocksize
      && 0 <= skip_via_lseek (file, fdesc, offset, SEEK_CUR))
    {
      if (fdesc == STDIN_FILENO)
        {
           struct stat st;
           if (fstat (STDIN_FILENO, &st) != 0)
             die (EXIT_FAILURE, errno, _("cannot fstat %s"), quoteaf (file));
           if (usable_st_size (&st) && st.st_size < input_offset + offset)
             {
               /* When skipping past EOF, return the number of _full_ blocks
                * that are not skipped, and set offset to EOF, so the caller
                * can determine the requested skip was not satisfied.  */
               records = ( offset - st.st_size ) / blocksize;
               offset = st.st_size - input_offset;
             }
           else
             records = 0;
           advance_input_offset (offset);
        }
      else
        {
          records = 0;
          *bytes = 0;
        }
      return records;
    }
  else
    {
      int lseek_errno = errno;

      /* The seek request may have failed above if it was too big
         (> device size, > max file size, etc.)
         Or it may not have been done at all (> OFF_T_MAX).
         Therefore try to seek to the end of the file,
         to avoid redundant reading.  */
      if ((skip_via_lseek (file, fdesc, 0, SEEK_END)) >= 0)
        {
          /* File is seekable, and we're at the end of it, and
             size <= OFF_T_MAX. So there's no point using read to advance.  */

          if (!lseek_errno)
            {
              /* The original seek was not attempted as offset > OFF_T_MAX.
                 We should error for write as can't get to the desired
                 location, even if OFF_T_MAX < max file size.
                 For read we're not going to read any data anyway,
                 so we should error for consistency.
                 It would be nice to not error for /dev/{zero,null}
                 for any offset, but that's not a significant issue.  */
              lseek_errno = EOVERFLOW;
            }

          if (fdesc == STDIN_FILENO)
            error (0, lseek_errno, _("%s: cannot skip"), quotef (file));
          else
            error (0, lseek_errno, _("%s: cannot seek"), quotef (file));
          /* If the file has a specific size and we've asked
             to skip/seek beyond the max allowable, then quit.  */
          quit (EXIT_FAILURE);
        }
      /* else file_size && offset > OFF_T_MAX or file ! seekable */

      char *buf;
      if (fdesc == STDIN_FILENO)
        {
          alloc_ibuf ();
          buf = ibuf;
        }
      else
        {
          alloc_obuf ();
          buf = obuf;
        }

      do
        {
          ssize_t nread = iread_fnc (fdesc, buf, records ? blocksize : *bytes);
          if (nread < 0)
            {
              if (fdesc == STDIN_FILENO)
                {
                  error (0, errno, _("error reading %s"), quoteaf (file));
                  if (conversions_mask & C_NOERROR)
                    print_stats ();
                }
              else
                error (0, lseek_errno, _("%s: cannot seek"), quotef (file));
              quit (EXIT_FAILURE);
            }
          else if (nread == 0)
            break;
          else if (fdesc == STDIN_FILENO)
            advance_input_offset (nread);

          if (records != 0)
            records--;
          else
            *bytes = 0;
        }
      while (records || *bytes);

      return records;
    }
}

/* Advance the input by NBYTES if possible, after a read error.
   The input file offset may or may not have advanced after the failed
   read; adjust it to point just after the bad record regardless.
   Return true if successful, or if the input is already known to not
   be seekable.  */

static bool
advance_input_after_read_error (size_t nbytes)
{
  if (! input_seekable)
    {
      if (input_seek_errno == ESPIPE)
        return true;
      errno = input_seek_errno;
    }
  else
    {
      off_t offset;
      advance_input_offset (nbytes);
      input_offset_overflow |= (OFF_T_MAX < input_offset);
      if (input_offset_overflow)
        {
          error (0, 0, _("offset overflow while reading file %s"),
                 quoteaf (input_file));
          return false;
        }
      offset = lseek (STDIN_FILENO, 0, SEEK_CUR);
      if (0 <= offset)
        {
          off_t diff;
          if (offset == input_offset)
            return true;
          diff = input_offset - offset;
          if (! (0 <= diff && diff <= nbytes) && status_level != STATUS_NONE)
            error (0, 0, _("warning: invalid file offset after failed read"));
          if (0 <= skip_via_lseek (input_file, STDIN_FILENO, diff, SEEK_CUR))
            return true;
          if (errno == 0)
            error (0, 0, _("cannot work around kernel bug after all"));
        }
    }

  error (0, errno, _("%s: cannot seek"), quotef (input_file));
  return false;
}

/* Copy NREAD bytes of BUF, with no conversions.  */

static void
copy_simple (char const *buf, size_t nread)
{
  const char *start = buf;	/* First uncopied char in BUF.  */

  do
    {
      size_t nfree = MIN (nread, output_blocksize - oc);

      memcpy (obuf + oc, start, nfree);

      nread -= nfree;		/* Update the number of bytes left to copy. */
      start += nfree;
      oc += nfree;
      if (oc >= output_blocksize)
        write_output ();
    }
  while (nread != 0);
}

/* Copy NREAD bytes of BUF, doing conv=block
   (pad newline-terminated records to 'conversion_blocksize',
   replacing the newline with trailing spaces).  */

static void
copy_with_block (char const *buf, size_t nread)
{
  size_t i;

  for (i = nread; i; i--, buf++)
    {
      if (*buf == newline_character)
        {
          if (col < conversion_blocksize)
            {
              size_t j;
              for (j = col; j < conversion_blocksize; j++)
                output_char (space_character);
            }
          col = 0;
        }
      else
        {
          if (col == conversion_blocksize)
            r_truncate++;
          else if (col < conversion_blocksize)
            output_char (*buf);
          col++;
        }
    }
}

/* Copy NREAD bytes of BUF, doing conv=unblock
   (replace trailing spaces in 'conversion_blocksize'-sized records
   with a newline).  */

static void
copy_with_unblock (char const *buf, size_t nread)
{
  size_t i;
  char c;
  static size_t pending_spaces = 0;

  for (i = 0; i < nread; i++)
    {
      c = buf[i];

      if (col++ >= conversion_blocksize)
        {
          col = pending_spaces = 0; /* Wipe out any pending spaces.  */
          i--;			/* Push the char back; get it later. */
          output_char (newline_character);
        }
      else if (c == space_character)
        pending_spaces++;
      else
        {
          /* 'c' is the character after a run of spaces that were not
             at the end of the conversion buffer.  Output them.  */
          while (pending_spaces)
            {
              output_char (space_character);
              --pending_spaces;
            }
          output_char (c);
        }
    }
}

/* Set the file descriptor flags for FD that correspond to the nonzero bits
   in ADD_FLAGS.  The file's name is NAME.  */

static void
set_fd_flags (int fd, int add_flags, char const *name)
{
  /* Ignore file creation flags that are no-ops on file descriptors.  */
  add_flags &= ~ (O_NOCTTY | O_NOFOLLOW);

  if (add_flags)
    {
      int old_flags = fcntl (fd, F_GETFL);
      int new_flags = old_flags | add_flags;
      bool ok = true;
      if (old_flags < 0)
        ok = false;
      else if (old_flags != new_flags)
        {
          if (new_flags & (O_DIRECTORY | O_NOLINKS))
            {
              /* NEW_FLAGS contains at least one file creation flag that
                 requires some checking of the open file descriptor.  */
              struct stat st;
              if (fstat (fd, &st) != 0)
                ok = false;
              else if ((new_flags & O_DIRECTORY) && ! S_ISDIR (st.st_mode))
                {
                  errno = ENOTDIR;
                  ok = false;
                }
              else if ((new_flags & O_NOLINKS) && 1 < st.st_nlink)
                {
                  errno = EMLINK;
                  ok = false;
                }
              new_flags &= ~ (O_DIRECTORY | O_NOLINKS);
            }

          if (ok && old_flags != new_flags
              && fcntl (fd, F_SETFL, new_flags) == -1)
            ok = false;
        }

      if (!ok)
        die (EXIT_FAILURE, errno, _("setting flags for %s"), quoteaf (name));
    }
}

/* The main loop.  */

static int
dd_copy (void)
{
  char *bufstart;		/* Input buffer. */
  ssize_t nread;		/* Bytes read in the current block.  */

  /* If nonzero, then the previously read block was partial and
     PARTREAD was its size.  */
  size_t partread = 0;

  int exit_status = EXIT_SUCCESS;
  size_t n_bytes_read;

  /* Leave at least one extra byte at the beginning and end of 'ibuf'
     for conv=swab, but keep the buffer address even.  But some peculiar
     device drivers work only with word-aligned buffers, so leave an
     extra two bytes.  */

  /* Some devices require alignment on a sector or page boundary
     (e.g. character disk devices).  Align the input buffer to a
     page boundary to cover all bases.  Note that due to the swab
     algorithm, we must have at least one byte in the page before
     the input buffer;  thus we allocate 2 pages of slop in the
     real buffer.  8k above the blocksize shouldn't bother anyone.

     The page alignment is necessary on any Linux kernel that supports
     either the SGI raw I/O patch or Steven Tweedies raw I/O patch.
     It is necessary when accessing raw (i.e., character special) disk
     devices on Unixware or other SVR4-derived system.  */

  if (skip_records != 0 || skip_bytes != 0)
    {
      uintmax_t us_bytes = input_offset + (skip_records * input_blocksize)
                           + skip_bytes;
      uintmax_t us_blocks = skip (STDIN_FILENO, input_file,
                                  skip_records, input_blocksize, &skip_bytes);
      us_bytes -= input_offset;

      /* POSIX doesn't say what to do when dd detects it has been
         asked to skip past EOF, so I assume it's non-fatal.
         There are 3 reasons why there might be unskipped blocks/bytes:
             1. file is too small
             2. pipe has not enough data
             3. partial reads  */
      if ((us_blocks || (!input_offset_overflow && us_bytes))
          && status_level != STATUS_NONE)
        {
          error (0, 0,
                 _("%s: cannot skip to specified offset"), quotef (input_file));
        }
    }

  if (seek_records != 0 || seek_bytes != 0)
    {
      size_t bytes = seek_bytes;
      uintmax_t write_records = skip (STDOUT_FILENO, output_file,
                                      seek_records, output_blocksize, &bytes);

      if (write_records != 0 || bytes != 0)
        {
          memset (obuf, 0, write_records ? output_blocksize : bytes);

          do
            {
              size_t size = write_records ? output_blocksize : bytes;
              if (iwrite (STDOUT_FILENO, obuf, size) != size)
                {
                  error (0, errno, _("writing to %s"), quoteaf (output_file));
                  quit (EXIT_FAILURE);
                }

              if (write_records != 0)
                write_records--;
              else
                bytes = 0;
            }
          while (write_records || bytes);
        }
    }

  if (max_records == 0 && max_bytes == 0)
    return exit_status;

  alloc_ibuf ();
  alloc_obuf ();

  while (1)
    {
      if (status_level == STATUS_PROGRESS)
        {
          xtime_t progress_time = gethrxtime ();
          if (next_time <= progress_time)
            {
              print_xfer_stats (progress_time);
              next_time += XTIME_PRECISION;
            }
        }

      if (r_partial + r_full >= max_records + !!max_bytes)
        break;

      /* Zero the buffer before reading, so that if we get a read error,
         whatever data we are able to read is followed by zeros.
         This minimizes data loss. */
      if ((conversions_mask & C_SYNC) && (conversions_mask & C_NOERROR))
        memset (ibuf,
                (conversions_mask & (C_BLOCK | C_UNBLOCK)) ? ' ' : '\0',
                input_blocksize);

      if (r_partial + r_full >= max_records)
        nread = iread_fnc (STDIN_FILENO, ibuf, max_bytes);
      else
        nread = iread_fnc (STDIN_FILENO, ibuf, input_blocksize);

      if (nread >= 0 && i_nocache)
        invalidate_cache (STDIN_FILENO, nread);

      if (nread == 0)
        break;			/* EOF.  */

      if (nread < 0)
        {
          if (!(conversions_mask & C_NOERROR) || status_level != STATUS_NONE)
            error (0, errno, _("error reading %s"), quoteaf (input_file));

          if (conversions_mask & C_NOERROR)
            {
              print_stats ();
              size_t bad_portion = input_blocksize - partread;

              /* We already know this data is not cached,
                 but call this so that correct offsets are maintained.  */
              invalidate_cache (STDIN_FILENO, bad_portion);

              /* Seek past the bad block if possible. */
              if (!advance_input_after_read_error (bad_portion))
                {
                  exit_status = EXIT_FAILURE;

                  /* Suppress duplicate diagnostics.  */
                  input_seekable = false;
                  input_seek_errno = ESPIPE;
                }
              if ((conversions_mask & C_SYNC) && !partread)
                /* Replace the missing input with null bytes and
                   proceed normally.  */
                nread = 0;
              else
                continue;
            }
          else
            {
              /* Write any partial block. */
              exit_status = EXIT_FAILURE;
              break;
            }
        }

      n_bytes_read = nread;
      advance_input_offset (nread);

      if (n_bytes_read < input_blocksize)
        {
          r_partial++;
          partread = n_bytes_read;
          if (conversions_mask & C_SYNC)
            {
              if (!(conversions_mask & C_NOERROR))
                /* If C_NOERROR, we zeroed the block before reading. */
                memset (ibuf + n_bytes_read,
                        (conversions_mask & (C_BLOCK | C_UNBLOCK)) ? ' ' : '\0',
                        input_blocksize - n_bytes_read);
              n_bytes_read = input_blocksize;
            }
        }
      else
        {
          r_full++;
          partread = 0;
        }

      if (ibuf == obuf)		/* If not C_TWOBUFS. */
        {
          size_t nwritten = iwrite (STDOUT_FILENO, obuf, n_bytes_read);
          w_bytes += nwritten;
          if (nwritten != n_bytes_read)
            {
              error (0, errno, _("error writing %s"), quoteaf (output_file));
              return EXIT_FAILURE;
            }
          else if (n_bytes_read == input_blocksize)
            w_full++;
          else
            w_partial++;
          continue;
        }

      /* Do any translations on the whole buffer at once.  */

      if (translation_needed)
        translate_buffer (ibuf, n_bytes_read);

      if (conversions_mask & C_SWAB)
        bufstart = swab_buffer (ibuf, &n_bytes_read);
      else
        bufstart = ibuf;

      if (conversions_mask & C_BLOCK)
        copy_with_block (bufstart, n_bytes_read);
      else if (conversions_mask & C_UNBLOCK)
        copy_with_unblock (bufstart, n_bytes_read);
      else
        copy_simple (bufstart, n_bytes_read);
    }

  /* If we have a char left as a result of conv=swab, output it.  */
  if (char_is_saved)
    {
      if (conversions_mask & C_BLOCK)
        copy_with_block (&saved_char, 1);
      else if (conversions_mask & C_UNBLOCK)
        copy_with_unblock (&saved_char, 1);
      else
        output_char (saved_char);
    }

  if ((conversions_mask & C_BLOCK) && col > 0)
    {
      /* If the final input line didn't end with a '\n', pad
         the output block to 'conversion_blocksize' chars.  */
      size_t i;
      for (i = col; i < conversion_blocksize; i++)
        output_char (space_character);
    }

  if (col && (conversions_mask & C_UNBLOCK))
    {
      /* If there was any output, add a final '\n'.  */
      output_char (newline_character);
    }

  /* Write out the last block. */
  if (oc != 0)
    {
      size_t nwritten = iwrite (STDOUT_FILENO, obuf, oc);
      w_bytes += nwritten;
      if (nwritten != 0)
        w_partial++;
      if (nwritten != oc)
        {
          error (0, errno, _("error writing %s"), quoteaf (output_file));
          return EXIT_FAILURE;
        }
    }

  /* If the last write was converted to a seek, then for a regular file
     or shared memory object, ftruncate to extend the size.  */
  if (final_op_was_seek)
    {
      struct stat stdout_stat;
      if (fstat (STDOUT_FILENO, &stdout_stat) != 0)
        {
          error (0, errno, _("cannot fstat %s"), quoteaf (output_file));
          return EXIT_FAILURE;
        }
      if (S_ISREG (stdout_stat.st_mode) || S_TYPEISSHM (&stdout_stat))
        {
          off_t output_offset = lseek (STDOUT_FILENO, 0, SEEK_CUR);
          if (0 <= output_offset && stdout_stat.st_size < output_offset)
            {
              if (iftruncate (STDOUT_FILENO, output_offset) != 0)
                {
                  error (0, errno,
                         _("failed to truncate to %" PRIdMAX " bytes"
                           " in output file %s"),
                         (intmax_t) output_offset, quoteaf (output_file));
                  return EXIT_FAILURE;
                }
            }
        }
    }

  if ((conversions_mask & C_FDATASYNC) && fdatasync (STDOUT_FILENO) != 0)
    {
      if (errno != ENOSYS && errno != EINVAL)
        {
          error (0, errno, _("fdatasync failed for %s"), quoteaf (output_file));
          exit_status = EXIT_FAILURE;
        }
      conversions_mask |= C_FSYNC;
    }

  if (conversions_mask & C_FSYNC)
    while (fsync (STDOUT_FILENO) != 0)
      if (errno != EINTR)
        {
          error (0, errno, _("fsync failed for %s"), quoteaf (output_file));
          return EXIT_FAILURE;
        }

  return exit_status;
}

int
main (int argc, char **argv)
{
  int i;
  int exit_status;
  off_t offset;

  install_signal_handlers ();

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  /* Arrange to close stdout if parse_long_options exits.  */
  atexit (maybe_close_stdout);

  page_size = getpagesize ();

  parse_long_options (argc, argv, PROGRAM_NAME, PACKAGE, Version,
                      usage, AUTHORS, (char const *) NULL);
  close_stdout_required = false;

  if (getopt_long (argc, argv, "", NULL, NULL) != -1)
    usage (EXIT_FAILURE);

  /* Initialize translation table to identity translation. */
  for (i = 0; i < 256; i++)
    trans_table[i] = i;

  /* Decode arguments. */
  scanargs (argc, argv);

  apply_translations ();

  if (input_file == NULL)
    {
      input_file = _("standard input");
      set_fd_flags (STDIN_FILENO, input_flags, input_file);
    }
  else
    {
      if (ifd_reopen (STDIN_FILENO, input_file, O_RDONLY | input_flags, 0) < 0)
        die (EXIT_FAILURE, errno, _("failed to open %s"),
             quoteaf (input_file));
    }

  offset = lseek (STDIN_FILENO, 0, SEEK_CUR);
  input_seekable = (0 <= offset);
  input_offset = MAX (0, offset);
  input_seek_errno = errno;

  if (output_file == NULL)
    {
      output_file = _("standard output");
      set_fd_flags (STDOUT_FILENO, output_flags, output_file);
    }
  else
    {
      mode_t perms = MODE_RW_UGO;
      int opts
        = (output_flags
           | (conversions_mask & C_NOCREAT ? 0 : O_CREAT)
           | (conversions_mask & C_EXCL ? O_EXCL : 0)
           | (seek_records || (conversions_mask & C_NOTRUNC) ? 0 : O_TRUNC));

      /* Open the output file with *read* access only if we might
         need to read to satisfy a 'seek=' request.  If we can't read
         the file, go ahead with write-only access; it might work.  */
      if ((! seek_records
           || ifd_reopen (STDOUT_FILENO, output_file, O_RDWR | opts, perms) < 0)
          && (ifd_reopen (STDOUT_FILENO, output_file, O_WRONLY | opts, perms)
              < 0))
        die (EXIT_FAILURE, errno, _("failed to open %s"),
             quoteaf (output_file));

      if (seek_records != 0 && !(conversions_mask & C_NOTRUNC))
        {
          uintmax_t size = seek_records * output_blocksize + seek_bytes;
          unsigned long int obs = output_blocksize;

          if (OFF_T_MAX / output_blocksize < seek_records)
            die (EXIT_FAILURE, 0,
                 _("offset too large: "
                   "cannot truncate to a length of seek=%"PRIuMAX""
                   " (%lu-byte) blocks"),
                 seek_records, obs);

          if (iftruncate (STDOUT_FILENO, size) != 0)
            {
              /* Complain only when ftruncate fails on a regular file, a
                 directory, or a shared memory object, as POSIX 1003.1-2004
                 specifies ftruncate's behavior only for these file types.
                 For example, do not complain when Linux kernel 2.4 ftruncate
                 fails on /dev/fd0.  */
              int ftruncate_errno = errno;
              struct stat stdout_stat;
              if (fstat (STDOUT_FILENO, &stdout_stat) != 0)
                die (EXIT_FAILURE, errno, _("cannot fstat %s"),
                     quoteaf (output_file));
              if (S_ISREG (stdout_stat.st_mode)
                  || S_ISDIR (stdout_stat.st_mode)
                  || S_TYPEISSHM (&stdout_stat))
                die (EXIT_FAILURE, ftruncate_errno,
                     _("failed to truncate to %"PRIuMAX" bytes"
                       " in output file %s"),
                     size, quoteaf (output_file));
            }
        }
    }

  start_time = gethrxtime ();
  next_time = start_time + XTIME_PRECISION;

  exit_status = dd_copy ();

  if (max_records == 0 && max_bytes == 0)
    {
      /* Special case to invalidate cache to end of file.  */
      if (i_nocache && !invalidate_cache (STDIN_FILENO, 0))
        {
          error (0, errno, _("failed to discard cache for: %s"),
                 quotef (input_file));
          exit_status = EXIT_FAILURE;
        }
      if (o_nocache && !invalidate_cache (STDOUT_FILENO, 0))
        {
          error (0, errno, _("failed to discard cache for: %s"),
                 quotef (output_file));
          exit_status = EXIT_FAILURE;
        }
    }
  else if (max_records != (uintmax_t) -1)
    {
      /* Invalidate any pending region less than page size,
         in case the kernel might round up.  */
      if (i_nocache)
        invalidate_cache (STDIN_FILENO, 0);
      if (o_nocache)
        invalidate_cache (STDOUT_FILENO, 0);
    }

  finish_up ();
  return exit_status;
}
