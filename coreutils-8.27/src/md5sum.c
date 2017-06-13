/* Compute checksums of files or strings.
   Copyright (C) 1995-2017 Free Software Foundation, Inc.

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

/* Written by Ulrich Drepper <drepper@gnu.ai.mit.edu>.  */

#include <config.h>

#include <getopt.h>
#include <sys/types.h>

#include "system.h"
#include "argmatch.h"
#include "quote.h"
#include "xdectoint.h"
#include "xstrtol.h"

#if HASH_ALGO_BLAKE2
# include "blake2/b2sum.h"
#endif
#if HASH_ALGO_MD5
# include "md5.h"
#endif
#if HASH_ALGO_SHA1
# include "sha1.h"
#endif
#if HASH_ALGO_SHA256 || HASH_ALGO_SHA224
# include "sha256.h"
#endif
#if HASH_ALGO_SHA512 || HASH_ALGO_SHA384
# include "sha512.h"
#endif
#include "die.h"
#include "error.h"
#include "fadvise.h"
#include "stdio--.h"
#include "xbinary-io.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#if HASH_ALGO_MD5
# define PROGRAM_NAME "md5sum"
# define DIGEST_TYPE_STRING "MD5"
# define DIGEST_STREAM md5_stream
# define DIGEST_BITS 128
# define DIGEST_REFERENCE "RFC 1321"
# define DIGEST_ALIGN 4
#elif HASH_ALGO_BLAKE2
# define PROGRAM_NAME "b2sum"
# define DIGEST_TYPE_STRING "BLAKE2"
# define DIGEST_STREAM blake2fns[b2_algorithm]
# define DIGEST_BITS 512
# define DIGEST_REFERENCE "RFC 7693"
# define DIGEST_ALIGN 8
#elif HASH_ALGO_SHA1
# define PROGRAM_NAME "sha1sum"
# define DIGEST_TYPE_STRING "SHA1"
# define DIGEST_STREAM sha1_stream
# define DIGEST_BITS 160
# define DIGEST_REFERENCE "FIPS-180-1"
# define DIGEST_ALIGN 4
#elif HASH_ALGO_SHA256
# define PROGRAM_NAME "sha256sum"
# define DIGEST_TYPE_STRING "SHA256"
# define DIGEST_STREAM sha256_stream
# define DIGEST_BITS 256
# define DIGEST_REFERENCE "FIPS-180-2"
# define DIGEST_ALIGN 4
#elif HASH_ALGO_SHA224
# define PROGRAM_NAME "sha224sum"
# define DIGEST_TYPE_STRING "SHA224"
# define DIGEST_STREAM sha224_stream
# define DIGEST_BITS 224
# define DIGEST_REFERENCE "RFC 3874"
# define DIGEST_ALIGN 4
#elif HASH_ALGO_SHA512
# define PROGRAM_NAME "sha512sum"
# define DIGEST_TYPE_STRING "SHA512"
# define DIGEST_STREAM sha512_stream
# define DIGEST_BITS 512
# define DIGEST_REFERENCE "FIPS-180-2"
# define DIGEST_ALIGN 8
#elif HASH_ALGO_SHA384
# define PROGRAM_NAME "sha384sum"
# define DIGEST_TYPE_STRING "SHA384"
# define DIGEST_STREAM sha384_stream
# define DIGEST_BITS 384
# define DIGEST_REFERENCE "FIPS-180-2"
# define DIGEST_ALIGN 8
#else
# error "Can't decide which hash algorithm to compile."
#endif

#if HASH_ALGO_BLAKE2
# define AUTHORS \
  proper_name ("Padraig Brady"), \
  proper_name ("Samuel Neves")
#else
# define AUTHORS \
  proper_name ("Ulrich Drepper"), \
  proper_name ("Scott Miller"), \
  proper_name ("David Madore")
# define DIGEST_HEX_BYTES (DIGEST_BITS / 4)
#endif
#define DIGEST_BIN_BYTES (DIGEST_BITS / 8)


/* The minimum length of a valid digest line.  This length does
   not include any newline character at the end of a line.  */
#if HASH_ALGO_BLAKE2
# define MIN_DIGEST_LINE_LENGTH 3 /* With -l 8.  */
#else
# define MIN_DIGEST_LINE_LENGTH \
   (DIGEST_HEX_BYTES /* length of hexadecimal message digest */ \
    + 1 /* blank */ \
    + 1 /* minimum filename length */ )
#endif

/* True if any of the files read were the standard input. */
static bool have_read_stdin;

/* The minimum length of a valid checksum line for the selected algorithm.  */
static size_t min_digest_line_length;

/* Set to the length of a digest hex string for the selected algorithm.  */
static size_t digest_hex_bytes;

/* With --check, don't generate any output.
   The exit code indicates success or failure.  */
static bool status_only = false;

/* With --check, print a message to standard error warning about each
   improperly formatted checksum line.  */
static bool warn = false;

/* With --check, ignore missing files.  */
static bool ignore_missing = false;

/* With --check, suppress the "OK" printed for each verified file.  */
static bool quiet = false;

/* With --check, exit with a non-zero return code if any line is
   improperly formatted. */
static bool strict = false;

/* Whether a BSD reversed format checksum is detected.  */
static int bsd_reversed = -1;

#if HASH_ALGO_BLAKE2
static char const *const algorithm_in_string[] =
{
  "blake2b", NULL
};
static char const *const algorithm_out_string[] =
{
  "BLAKE2b", NULL
};
enum Algorithm
{
  BLAKE2b
};
static enum Algorithm const algorithm[] =
{
  BLAKE2b
};
ARGMATCH_VERIFY (algorithm_in_string, algorithm);
ARGMATCH_VERIFY (algorithm_out_string, algorithm);

static enum Algorithm b2_algorithm;
static uintmax_t b2_length;
static blake2fn blake2fns[]=
{
  blake2b_stream
};
static uintmax_t blake2_max_len[]=
{
  BLAKE2B_OUTBYTES
};
#endif /* HASH_ALGO_BLAKE2 */

/* For long options that have no equivalent short option, use a
   non-character as a pseudo short option, starting with CHAR_MAX + 1.  */
enum
{
  IGNORE_MISSING_OPTION = CHAR_MAX + 1,
  STATUS_OPTION,
  QUIET_OPTION,
  STRICT_OPTION,
  TAG_OPTION
};

static struct option const long_options[] =
{
#if HASH_ALGO_BLAKE2
  { "length", required_argument, NULL, 'l'},
#endif
  { "binary", no_argument, NULL, 'b' },
  { "check", no_argument, NULL, 'c' },
  { "ignore-missing", no_argument, NULL, IGNORE_MISSING_OPTION},
  { "quiet", no_argument, NULL, QUIET_OPTION },
  { "status", no_argument, NULL, STATUS_OPTION },
  { "text", no_argument, NULL, 't' },
  { "warn", no_argument, NULL, 'w' },
  { "strict", no_argument, NULL, STRICT_OPTION },
  { "tag", no_argument, NULL, TAG_OPTION },
  { GETOPT_HELP_OPTION_DECL },
  { GETOPT_VERSION_OPTION_DECL },
  { NULL, 0, NULL, 0 }
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
Print or check %s (%d-bit) checksums.\n\
"),
              program_name,
              DIGEST_TYPE_STRING,
              DIGEST_BITS);

      emit_stdin_note ();
      if (O_BINARY)
        fputs (_("\
\n\
  -b, --binary         read in binary mode (default unless reading tty stdin)\n\
"), stdout);
      else
        fputs (_("\
\n\
  -b, --binary         read in binary mode\n\
"), stdout);

      printf (_("\
  -c, --check          read %s sums from the FILEs and check them\n"),
              DIGEST_TYPE_STRING);
#if HASH_ALGO_BLAKE2
        fputs (_("\
  -l, --length         digest length in bits; must not exceed the maximum for\n\
                       the blake2 algorithm and must be a multiple of 8\n\
"), stdout);
#endif
      fputs (_("\
      --tag            create a BSD-style checksum\n\
"), stdout);
      if (O_BINARY)
        fputs (_("\
  -t, --text           read in text mode (default if reading tty stdin)\n\
"), stdout);
      else
        fputs (_("\
  -t, --text           read in text mode (default)\n\
"), stdout);
      fputs (_("\
\n\
The following five options are useful only when verifying checksums:\n\
      --ignore-missing  don't fail or report status for missing files\n\
      --quiet          don't print OK for each successfully verified file\n\
      --status         don't output anything, status code shows success\n\
      --strict         exit non-zero for improperly formatted checksum lines\n\
  -w, --warn           warn about improperly formatted checksum lines\n\
\n\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      printf (_("\
\n\
The sums are computed as described in %s.  When checking, the input\n\
should be a former output of this program.  The default mode is to print a\n\
line with checksum, a space, a character indicating input mode ('*' for binary,\
\n' ' for text or where binary is insignificant), and name for each FILE.\n"),
              DIGEST_REFERENCE);
      emit_ancillary_info (PROGRAM_NAME);
    }

  exit (status);
}

#define ISWHITE(c) ((c) == ' ' || (c) == '\t')

/* Given a file name, S of length S_LEN, that is not NUL-terminated,
   modify it in place, performing the equivalent of this sed substitution:
   's/\\n/\n/g;s/\\\\/\\/g' i.e., replacing each "\\n" string with a newline
   and each "\\\\" with a single backslash, NUL-terminate it and return S.
   If S is not a valid escaped file name, i.e., if it ends with an odd number
   of backslashes or if it contains a backslash followed by anything other
   than "n" or another backslash, return NULL.  */

static char *
filename_unescape (char *s, size_t s_len)
{
  char *dst = s;

  for (size_t i = 0; i < s_len; i++)
    {
      switch (s[i])
        {
        case '\\':
          if (i == s_len - 1)
            {
              /* File name ends with an unescaped backslash: invalid.  */
              return NULL;
            }
          ++i;
          switch (s[i])
            {
            case 'n':
              *dst++ = '\n';
              break;
            case '\\':
              *dst++ = '\\';
              break;
            default:
              /* Only '\' or 'n' may follow a backslash.  */
              return NULL;
            }
          break;

        case '\0':
          /* The file name may not contain a NUL.  */
          return NULL;

        default:
          *dst++ = s[i];
          break;
        }
    }
  if (dst < s + s_len)
    *dst = '\0';

  return s;
}

/* Split the checksum string S (of length S_LEN) from a BSD 'md5' or
   'sha1' command into two parts: a hexadecimal digest, and the file
   name.  S is modified.  Return true if successful.  */

static bool
bsd_split_3 (char *s, size_t s_len, unsigned char **hex_digest,
             char **file_name, bool escaped_filename)
{
  size_t i;

  if (s_len == 0)
    return false;

  /* Find end of filename.  */
  i = s_len - 1;
  while (i && s[i] != ')')
    i--;

  if (s[i] != ')')
    return false;

  *file_name = s;

  if (escaped_filename && filename_unescape (s, i) == NULL)
    return false;

  s[i++] = '\0';

  while (ISWHITE (s[i]))
    i++;

  if (s[i] != '=')
    return false;

  i++;

  while (ISWHITE (s[i]))
    i++;

  *hex_digest = (unsigned char *) &s[i];
  return true;
}

/* Split the string S (of length S_LEN) into three parts:
   a hexadecimal digest, binary flag, and the file name.
   S is modified.  Return true if successful.  */

static bool
split_3 (char *s, size_t s_len,
         unsigned char **hex_digest, int *binary, char **file_name)
{
  bool escaped_filename = false;
  size_t algo_name_len;

  size_t i = 0;
  while (ISWHITE (s[i]))
    ++i;

  if (s[i] == '\\')
    {
      ++i;
      escaped_filename = true;
    }

  /* Check for BSD-style checksum line. */

  algo_name_len = strlen (DIGEST_TYPE_STRING);
  if (STREQ_LEN (s + i, DIGEST_TYPE_STRING, algo_name_len))
    {
      i += algo_name_len;
#if HASH_ALGO_BLAKE2
      /* Terminate and match algorithm name.  */
      char const *algo_name = &s[i - algo_name_len];
      while (! ISWHITE (s[i]) && s[i] != '-' && s[i] != '(')
        ++i;
      bool length_specified = s[i] == '-';
      bool openssl_format = s[i] == '('; /* and no length_specified */
      s[i++] = '\0';
      ptrdiff_t algo = argmatch (algo_name, algorithm_out_string, NULL, 0);
      if (algo < 0)
        return false;
      else
        b2_algorithm = algo;
      if (openssl_format)
        s[--i] = '(';

      if (length_specified)
        {
          unsigned long int tmp_ulong;
          if (xstrtoul (s + i, NULL, 0, &tmp_ulong, NULL) == LONGINT_OK
              && 0 < tmp_ulong && tmp_ulong <= blake2_max_len[b2_algorithm] * 8
              && tmp_ulong % 8 == 0)
            b2_length = tmp_ulong;
          else
            return false;

          while (ISDIGIT (s[i]))
            ++i;
        }
      else
        b2_length = blake2_max_len[b2_algorithm] * 8;

      digest_hex_bytes = b2_length / 4;
#endif
      if (s[i] == ' ')
        ++i;
      if (s[i] == '(')
        {
          ++i;
          *binary = 0;
          return bsd_split_3 (s + i, s_len - i,
                              hex_digest, file_name, escaped_filename);
        }
      return false;
    }

  /* Ignore this line if it is too short.
     Each line must have at least 'min_digest_line_length - 1' (or one more, if
     the first is a backslash) more characters to contain correct message digest
     information.  */
  if (s_len - i < min_digest_line_length + (s[i] == '\\'))
    return false;

  *hex_digest = (unsigned char *) &s[i];

#if HASH_ALGO_BLAKE2
  /* Auto determine length.  */
  unsigned char const *hp = *hex_digest;
  digest_hex_bytes = 0;
  while (isxdigit (*hp++))
    digest_hex_bytes++;
  if (digest_hex_bytes < 2 || digest_hex_bytes % 2
      || blake2_max_len[b2_algorithm] * 2 < digest_hex_bytes)
    return false;
  b2_length = digest_hex_bytes * 4;
#endif

  /* The first field has to be the n-character hexadecimal
     representation of the message digest.  If it is not followed
     immediately by a white space it's an error.  */
  i += digest_hex_bytes;
  if (!ISWHITE (s[i]))
    return false;

  s[i++] = '\0';

  /* If "bsd reversed" format detected.  */
  if ((s_len - i == 1) || (s[i] != ' ' && s[i] != '*'))
    {
      /* Don't allow mixing bsd and standard formats,
         to minimize security issues with attackers
         renaming files with leading spaces.
         This assumes that with bsd format checksums
         that the first file name does not have
         a leading ' ' or '*'.  */
      if (bsd_reversed == 0)
        return false;
      bsd_reversed = 1;
    }
  else if (bsd_reversed != 1)
    {
      bsd_reversed = 0;
      *binary = (s[i++] == '*');
    }

  /* All characters between the type indicator and end of line are
     significant -- that includes leading and trailing white space.  */
  *file_name = &s[i];

  if (escaped_filename)
    return filename_unescape (&s[i], s_len - i) != NULL;

  return true;
}

/* Return true if S is a NUL-terminated string of DIGEST_HEX_BYTES hex digits.
   Otherwise, return false.  */
static bool _GL_ATTRIBUTE_PURE
hex_digits (unsigned char const *s)
{
  unsigned int i;
  for (i = 0; i < digest_hex_bytes; i++)
    {
      if (!isxdigit (*s))
        return false;
      ++s;
    }
  return *s == '\0';
}

/* If ESCAPE is true, then translate each NEWLINE byte to the string, "\\n",
   and each backslash to "\\\\".  */
static void
print_filename (char const *file, bool escape)
{
  if (! escape)
    {
      fputs (file, stdout);
      return;
    }

  while (*file)
    {
      switch (*file)
        {
        case '\n':
          fputs ("\\n", stdout);
          break;

        case '\\':
          fputs ("\\\\", stdout);
          break;

        default:
          putchar (*file);
          break;
        }
      file++;
    }
}

/* An interface to the function, DIGEST_STREAM.
   Operate on FILENAME (it may be "-").

   *BINARY indicates whether the file is binary.  BINARY < 0 means it
   depends on whether binary mode makes any difference and the file is
   a terminal; in that case, clear *BINARY if the file was treated as
   text because it was a terminal.

   Put the checksum in *BIN_RESULT, which must be properly aligned.
   Put true in *MISSING if the file can't be opened due to ENOENT.
   Return true if successful.  */

static bool
digest_file (const char *filename, int *binary, unsigned char *bin_result,
             bool *missing)
{
  FILE *fp;
  int err;
  bool is_stdin = STREQ (filename, "-");

  *missing = false;

  if (is_stdin)
    {
      have_read_stdin = true;
      fp = stdin;
      if (O_BINARY && *binary)
        {
          if (*binary < 0)
            *binary = ! isatty (STDIN_FILENO);
          if (*binary)
            xset_binary_mode (STDIN_FILENO, O_BINARY);
        }
    }
  else
    {
      fp = fopen (filename, (O_BINARY && *binary ? "rb" : "r"));
      if (fp == NULL)
        {
          if (ignore_missing && errno == ENOENT)
            {
              *missing = true;
              return true;
            }
          error (0, errno, "%s", quotef (filename));
          return false;
        }
    }

  fadvise (fp, FADVISE_SEQUENTIAL);

#if HASH_ALGO_BLAKE2
  err = DIGEST_STREAM (fp, bin_result, b2_length / 8);
#else
  err = DIGEST_STREAM (fp, bin_result);
#endif
  if (err)
    {
      error (0, errno, "%s", quotef (filename));
      if (fp != stdin)
        fclose (fp);
      return false;
    }

  if (!is_stdin && fclose (fp) != 0)
    {
      error (0, errno, "%s", quotef (filename));
      return false;
    }

  return true;
}

static bool
digest_check (const char *checkfile_name)
{
  FILE *checkfile_stream;
  uintmax_t n_misformatted_lines = 0;
  uintmax_t n_improperly_formatted_lines = 0;
  uintmax_t n_mismatched_checksums = 0;
  uintmax_t n_open_or_read_failures = 0;
  bool properly_formatted_lines = false;
  bool matched_checksums = false;
  unsigned char bin_buffer_unaligned[DIGEST_BIN_BYTES + DIGEST_ALIGN];
  /* Make sure bin_buffer is properly aligned. */
  unsigned char *bin_buffer = ptr_align (bin_buffer_unaligned, DIGEST_ALIGN);
  uintmax_t line_number;
  char *line;
  size_t line_chars_allocated;
  bool is_stdin = STREQ (checkfile_name, "-");

  if (is_stdin)
    {
      have_read_stdin = true;
      checkfile_name = _("standard input");
      checkfile_stream = stdin;
    }
  else
    {
      checkfile_stream = fopen (checkfile_name, "r");
      if (checkfile_stream == NULL)
        {
          error (0, errno, "%s", quotef (checkfile_name));
          return false;
        }
    }

  line_number = 0;
  line = NULL;
  line_chars_allocated = 0;
  do
    {
      char *filename IF_LINT ( = NULL);
      int binary;
      unsigned char *hex_digest IF_LINT ( = NULL);
      ssize_t line_length;

      ++line_number;
      if (line_number == 0)
        die (EXIT_FAILURE, 0, _("%s: too many checksum lines"),
             quotef (checkfile_name));

      line_length = getline (&line, &line_chars_allocated, checkfile_stream);
      if (line_length <= 0)
        break;

      /* Ignore comment lines, which begin with a '#' character.  */
      if (line[0] == '#')
        continue;

      /* Remove any trailing newline.  */
      if (line[line_length - 1] == '\n')
        line[--line_length] = '\0';

      if (! (split_3 (line, line_length, &hex_digest, &binary, &filename)
             && ! (is_stdin && STREQ (filename, "-"))
             && hex_digits (hex_digest)))
        {
          ++n_misformatted_lines;

          if (warn)
            {
              error (0, 0,
                     _("%s: %" PRIuMAX
                       ": improperly formatted %s checksum line"),
                     quotef (checkfile_name), line_number,
                     DIGEST_TYPE_STRING);
            }

          ++n_improperly_formatted_lines;
        }
      else
        {
          static const char bin2hex[] = { '0', '1', '2', '3',
                                          '4', '5', '6', '7',
                                          '8', '9', 'a', 'b',
                                          'c', 'd', 'e', 'f' };
          bool ok;
          bool missing;
          /* Only escape in the edge case producing multiple lines,
             to ease automatic processing of status output.  */
          bool needs_escape = ! status_only && strchr (filename, '\n');

          properly_formatted_lines = true;

          ok = digest_file (filename, &binary, bin_buffer, &missing);

          if (!ok)
            {
              ++n_open_or_read_failures;
              if (!status_only)
                {
                  if (needs_escape)
                    putchar ('\\');
                  print_filename (filename, needs_escape);
                  printf (": %s\n", _("FAILED open or read"));
                }
            }
          else if (ignore_missing && missing)
            {
              /* Ignore missing files with --ignore-missing.  */
              ;
            }
          else
            {
              size_t digest_bin_bytes = digest_hex_bytes / 2;
              size_t cnt;

              /* Compare generated binary number with text representation
                 in check file.  Ignore case of hex digits.  */
              for (cnt = 0; cnt < digest_bin_bytes; ++cnt)
                {
                  if (tolower (hex_digest[2 * cnt])
                      != bin2hex[bin_buffer[cnt] >> 4]
                      || (tolower (hex_digest[2 * cnt + 1])
                          != (bin2hex[bin_buffer[cnt] & 0xf])))
                    break;
                }
              if (cnt != digest_bin_bytes)
                ++n_mismatched_checksums;
              else
                matched_checksums = true;

              if (!status_only)
                {
                  if (cnt != digest_bin_bytes || ! quiet)
                    {
                      if (needs_escape)
                        putchar ('\\');
                      print_filename (filename, needs_escape);
                    }

                  if (cnt != digest_bin_bytes)
                    printf (": %s\n", _("FAILED"));
                  else if (!quiet)
                    printf (": %s\n", _("OK"));
                }
            }
        }
    }
  while (!feof (checkfile_stream) && !ferror (checkfile_stream));

  free (line);

  if (ferror (checkfile_stream))
    {
      error (0, 0, _("%s: read error"), quotef (checkfile_name));
      return false;
    }

  if (!is_stdin && fclose (checkfile_stream) != 0)
    {
      error (0, errno, "%s", quotef (checkfile_name));
      return false;
    }

  if (! properly_formatted_lines)
    {
      /* Warn if no tests are found.  */
      error (0, 0, _("%s: no properly formatted %s checksum lines found"),
             quotef (checkfile_name), DIGEST_TYPE_STRING);
    }
  else
    {
      if (!status_only)
        {
          if (n_misformatted_lines != 0)
            error (0, 0,
                   (ngettext
                    ("WARNING: %" PRIuMAX " line is improperly formatted",
                     "WARNING: %" PRIuMAX " lines are improperly formatted",
                     select_plural (n_misformatted_lines))),
                   n_misformatted_lines);

          if (n_open_or_read_failures != 0)
            error (0, 0,
                   (ngettext
                    ("WARNING: %" PRIuMAX " listed file could not be read",
                     "WARNING: %" PRIuMAX " listed files could not be read",
                     select_plural (n_open_or_read_failures))),
                   n_open_or_read_failures);

          if (n_mismatched_checksums != 0)
            error (0, 0,
                   (ngettext
                    ("WARNING: %" PRIuMAX " computed checksum did NOT match",
                     "WARNING: %" PRIuMAX " computed checksums did NOT match",
                     select_plural (n_mismatched_checksums))),
                   n_mismatched_checksums);

          if (ignore_missing && ! matched_checksums)
            error (0, 0, _("%s: no file was verified"),
                   quotef (checkfile_name));
        }
    }

  return (properly_formatted_lines
          && matched_checksums
          && n_mismatched_checksums == 0
          && n_open_or_read_failures == 0
          && (!strict || n_improperly_formatted_lines == 0));
}

int
main (int argc, char **argv)
{
  unsigned char bin_buffer_unaligned[DIGEST_BIN_BYTES + DIGEST_ALIGN];
  /* Make sure bin_buffer is properly aligned. */
  unsigned char *bin_buffer = ptr_align (bin_buffer_unaligned, DIGEST_ALIGN);
  bool do_check = false;
  int opt;
  bool ok = true;
  int binary = -1;
  bool prefix_tag = false;

  /* Setting values of global variables.  */
  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdout);

  /* Line buffer stdout to ensure lines are written atomically and immediately
     so that processes running in parallel do not intersperse their output.  */
  setvbuf (stdout, NULL, _IOLBF, 0);

#if HASH_ALGO_BLAKE2
  const char* short_opts = "l:bctw";
  const char* b2_length_str = "";
#else
  const char* short_opts = "bctw";
#endif

  while ((opt = getopt_long (argc, argv, short_opts, long_options, NULL)) != -1)
    switch (opt)
      {
#if HASH_ALGO_BLAKE2
      case 'l':
        b2_length = xdectoumax (optarg, 0, UINTMAX_MAX, "",
                                _("invalid length"), 0);
        b2_length_str = optarg;
        if (b2_length % 8 != 0)
          {
            error (0, 0, _("invalid length: %s"), quote (b2_length_str));
            die (EXIT_FAILURE, 0, _("length is not a multiple of 8"));
          }
        break;
#endif
      case 'b':
        binary = 1;
        break;
      case 'c':
        do_check = true;
        break;
      case STATUS_OPTION:
        status_only = true;
        warn = false;
        quiet = false;
        break;
      case 't':
        binary = 0;
        break;
      case 'w':
        status_only = false;
        warn = true;
        quiet = false;
        break;
      case IGNORE_MISSING_OPTION:
        ignore_missing = true;
        break;
      case QUIET_OPTION:
        status_only = false;
        warn = false;
        quiet = true;
        break;
      case STRICT_OPTION:
        strict = true;
        break;
      case TAG_OPTION:
        prefix_tag = true;
        binary = 1;
        break;
      case_GETOPT_HELP_CHAR;
      case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);
      default:
        usage (EXIT_FAILURE);
      }

  min_digest_line_length = MIN_DIGEST_LINE_LENGTH;
#if HASH_ALGO_BLAKE2
  if (b2_length > blake2_max_len[b2_algorithm] * 8)
    {
      error (0, 0, _("invalid length: %s"), quote (b2_length_str));
      die (EXIT_FAILURE, 0,
           _("maximum digest length for %s is %"PRIuMAX" bits"),
           quote (algorithm_in_string[b2_algorithm]),
           blake2_max_len[b2_algorithm] * 8);
    }
  if (b2_length == 0 && ! do_check)
    b2_length = blake2_max_len[b2_algorithm] * 8;
  digest_hex_bytes = b2_length / 4;
#else
  digest_hex_bytes = DIGEST_HEX_BYTES;
#endif

  if (prefix_tag && !binary)
   {
     /* This could be supported in a backwards compatible way
        by prefixing the output line with a space in text mode.
        However that's invasive enough that it was agreed to
        not support this mode with --tag, as --text use cases
        are adequately supported by the default output format.  */
     error (0, 0, _("--tag does not support --text mode"));
     usage (EXIT_FAILURE);
   }

  if (prefix_tag && do_check)
    {
      error (0, 0, _("the --tag option is meaningless when "
                     "verifying checksums"));
      usage (EXIT_FAILURE);
    }

  if (0 <= binary && do_check)
    {
      error (0, 0, _("the --binary and --text options are meaningless when "
                     "verifying checksums"));
      usage (EXIT_FAILURE);
    }

  if (ignore_missing && !do_check)
    {
      error (0, 0,
             _("the --ignore-missing option is meaningful only when "
               "verifying checksums"));
      usage (EXIT_FAILURE);
    }

  if (status_only && !do_check)
    {
      error (0, 0,
       _("the --status option is meaningful only when verifying checksums"));
      usage (EXIT_FAILURE);
    }

  if (warn && !do_check)
    {
      error (0, 0,
       _("the --warn option is meaningful only when verifying checksums"));
      usage (EXIT_FAILURE);
    }

  if (quiet && !do_check)
    {
      error (0, 0,
       _("the --quiet option is meaningful only when verifying checksums"));
      usage (EXIT_FAILURE);
    }

  if (strict & !do_check)
   {
     error (0, 0,
        _("the --strict option is meaningful only when verifying checksums"));
     usage (EXIT_FAILURE);
   }

  if (!O_BINARY && binary < 0)
    binary = 0;

  char **operand_lim = argv + argc;
  if (optind == argc)
    *operand_lim++ = bad_cast ("-");

  for (char **operandp = argv + optind; operandp < operand_lim; operandp++)
    {
      char *file = *operandp;

      if (do_check)
        ok &= digest_check (file);
      else
        {
          int file_is_binary = binary;
          bool missing;

          if (! digest_file (file, &file_is_binary, bin_buffer, &missing))
            ok = false;
          else
            {
              /* We don't really need to escape, and hence detect, the '\\'
                 char, and not doing so should be both forwards and backwards
                 compatible, since only escaped lines would have a '\\' char at
                 the start.  However just in case users are directly comparing
                 against old (hashed) outputs, in the presence of files
                 containing '\\' characters, we decided to not simplify the
                 output in this case.  */
              bool needs_escape = strchr (file, '\\') || strchr (file, '\n');

              if (prefix_tag)
                {
                  if (needs_escape)
                    putchar ('\\');

#if HASH_ALGO_BLAKE2
                  fputs (algorithm_out_string[b2_algorithm], stdout);
                  if (b2_length < blake2_max_len[b2_algorithm] * 8)
                    printf ("-%"PRIuMAX, b2_length);
#else
                  fputs (DIGEST_TYPE_STRING, stdout);
#endif
                  fputs (" (", stdout);
                  print_filename (file, needs_escape);
                  fputs (") = ", stdout);
                }

              size_t i;

              /* Output a leading backslash if the file name contains
                 a newline or backslash.  */
              if (!prefix_tag && needs_escape)
                putchar ('\\');

              for (i = 0; i < (digest_hex_bytes / 2); ++i)
                printf ("%02x", bin_buffer[i]);

              if (!prefix_tag)
                {
                  putchar (' ');

                  putchar (file_is_binary ? '*' : ' ');

                  print_filename (file, needs_escape);
                }

              putchar ('\n');
            }
        }
    }

  if (have_read_stdin && fclose (stdin) == EOF)
    die (EXIT_FAILURE, errno, _("standard input"));

  return ok ? EXIT_SUCCESS : EXIT_FAILURE;
}
