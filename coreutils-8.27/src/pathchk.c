/* pathchk -- check whether file names are valid or portable
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

#include <config.h>
#include <stdio.h>
#include <getopt.h>
#include <sys/types.h>
#include <wchar.h>

#include "system.h"
#include "error.h"
#include "quote.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "pathchk"

#define AUTHORS \
  proper_name ("Paul Eggert"), \
  proper_name ("David MacKenzie"), \
  proper_name ("Jim Meyering")

#ifndef _POSIX_PATH_MAX
# define _POSIX_PATH_MAX 256
#endif
#ifndef _POSIX_NAME_MAX
# define _POSIX_NAME_MAX 14
#endif

#ifdef _XOPEN_NAME_MAX
# define NAME_MAX_MINIMUM _XOPEN_NAME_MAX
#else
# define NAME_MAX_MINIMUM _POSIX_NAME_MAX
#endif
#ifdef _XOPEN_PATH_MAX
# define PATH_MAX_MINIMUM _XOPEN_PATH_MAX
#else
# define PATH_MAX_MINIMUM _POSIX_PATH_MAX
#endif

#if ! (HAVE_PATHCONF && defined _PC_NAME_MAX && defined _PC_PATH_MAX)
# ifndef _PC_NAME_MAX
#  define _PC_NAME_MAX 0
#  define _PC_PATH_MAX 1
# endif
# ifndef pathconf
#  define pathconf(file, flag) \
     (flag == _PC_NAME_MAX ? NAME_MAX_MINIMUM : PATH_MAX_MINIMUM)
# endif
#endif

static bool validate_file_name (char *, bool, bool);

/* For long options that have no equivalent short option, use a
   non-character as a pseudo short option, starting with CHAR_MAX + 1.  */
enum
{
  PORTABILITY_OPTION = CHAR_MAX + 1
};

static struct option const longopts[] =
{
  {"portability", no_argument, NULL, PORTABILITY_OPTION},
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
      printf (_("Usage: %s [OPTION]... NAME...\n"), program_name);
      fputs (_("\
Diagnose invalid or unportable file names.\n\
\n\
  -p                  check for most POSIX systems\n\
  -P                  check for empty names and leading \"-\"\n\
      --portability   check for all POSIX systems (equivalent to -p -P)\n\
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
  bool ok = true;
  bool check_basic_portability = false;
  bool check_extra_portability = false;
  int optc;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdout);

  while ((optc = getopt_long (argc, argv, "+pP", longopts, NULL)) != -1)
    {
      switch (optc)
        {
        case PORTABILITY_OPTION:
          check_basic_portability = true;
          check_extra_portability = true;
          break;

        case 'p':
          check_basic_portability = true;
          break;

        case 'P':
          check_extra_portability = true;
          break;

        case_GETOPT_HELP_CHAR;

        case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);

        default:
          usage (EXIT_FAILURE);
        }
    }

  if (optind == argc)
    {
      error (0, 0, _("missing operand"));
      usage (EXIT_FAILURE);
    }

  for (; optind < argc; ++optind)
    ok &= validate_file_name (argv[optind],
                              check_basic_portability, check_extra_portability);

  return ok ? EXIT_SUCCESS : EXIT_FAILURE;
}

/* If FILE contains a component with a leading "-", report an error
   and return false; otherwise, return true.  */

static bool
no_leading_hyphen (char const *file)
{
  char const *p;

  for (p = file;  (p = strchr (p, '-'));  p++)
    if (p == file || p[-1] == '/')
      {
        error (0, 0, _("leading '-' in a component of file name %s"),
               quoteaf (file));
        return false;
      }

  return true;
}

/* If FILE (of length FILELEN) contains only portable characters,
   return true, else report an error and return false.  */

static bool
portable_chars_only (char const *file, size_t filelen)
{
  size_t validlen = strspn (file,
                            ("/"
                             "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                             "abcdefghijklmnopqrstuvwxyz"
                             "0123456789._-"));
  char const *invalid = file + validlen;

  if (*invalid)
    {
      mbstate_t mbstate = { 0, };
      size_t charlen = mbrlen (invalid, filelen - validlen, &mbstate);
      error (0, 0,
             _("nonportable character %s in file name %s"),
             quotearg_n_style_mem (1, locale_quoting_style, invalid,
                                   (charlen <= MB_LEN_MAX ? charlen : 1)),
             quoteaf_n (0, file));
      return false;
    }

  return true;
}

/* Return the address of the start of the next file name component in F.  */

static char * _GL_ATTRIBUTE_PURE
component_start (char *f)
{
  while (*f == '/')
    f++;
  return f;
}

/* Return the size of the file name component F.  F must be nonempty.  */

static size_t _GL_ATTRIBUTE_PURE
component_len (char const *f)
{
  size_t len;
  for (len = 1; f[len] != '/' && f[len]; len++)
    continue;
  return len;
}

/* Make sure that
   strlen (FILE) <= PATH_MAX
   && strlen (each-existing-directory-in-FILE) <= NAME_MAX

   If CHECK_BASIC_PORTABILITY is true, compare against _POSIX_PATH_MAX and
   _POSIX_NAME_MAX instead, and make sure that FILE contains no
   characters not in the POSIX portable filename character set, which
   consists of A-Z, a-z, 0-9, ., _, - (plus / for separators).

   If CHECK_BASIC_PORTABILITY is false, make sure that all leading directories
   along FILE that exist are searchable.

   If CHECK_EXTRA_PORTABILITY is true, check that file name components do not
   begin with "-".

   If either CHECK_BASIC_PORTABILITY or CHECK_EXTRA_PORTABILITY is true,
   check that the file name is not empty.

   Return true if all of these tests are successful, false if any fail.  */

static bool
validate_file_name (char *file, bool check_basic_portability,
                    bool check_extra_portability)
{
  size_t filelen = strlen (file);

  /* Start of file name component being checked.  */
  char *start;

  /* True if component lengths need to be checked.  */
  bool check_component_lengths;

  /* True if the file is known to exist.  */
  bool file_exists = false;

  if (check_extra_portability && ! no_leading_hyphen (file))
    return false;

  if ((check_basic_portability || check_extra_portability)
      && filelen == 0)
    {
      /* Fail, since empty names are not portable.  As of
         2005-01-06 POSIX does not address whether "pathchk -p ''"
         should (or is allowed to) fail, so this is not a
         conformance violation.  */
      error (0, 0, _("empty file name"));
      return false;
    }

  if (check_basic_portability)
    {
      if (! portable_chars_only (file, filelen))
        return false;
    }
  else
    {
      /* Check whether a file name component is in a directory that
         is not searchable, or has some other serious problem.
         POSIX does not allow "" as a file name, but some non-POSIX
         hosts do (as an alias for "."), so allow "" if lstat does.  */

      struct stat st;
      if (lstat (file, &st) == 0)
        file_exists = true;
      else if (errno != ENOENT || filelen == 0)
        {
          error (0, errno, "%s", quotef (file));
          return false;
        }
    }

  if (check_basic_portability
      || (! file_exists && PATH_MAX_MINIMUM <= filelen))
    {
      size_t maxsize;

      if (check_basic_portability)
        maxsize = _POSIX_PATH_MAX;
      else
        {
          long int size;
          char const *dir = (*file == '/' ? "/" : ".");
          errno = 0;
          size = pathconf (dir, _PC_PATH_MAX);
          if (size < 0 && errno != 0)
            {
              error (0, errno,
                     _("%s: unable to determine maximum file name length"),
                     dir);
              return false;
            }
          maxsize = MIN (size, SSIZE_MAX);
        }

      if (maxsize <= filelen)
        {
          unsigned long int len = filelen;
          unsigned long int maxlen = maxsize - 1;
          error (0, 0, _("limit %lu exceeded by length %lu of file name %s"),
                 maxlen, len, quoteaf (file));
          return false;
        }
    }

  /* Check whether pathconf (..., _PC_NAME_MAX) can be avoided, i.e.,
     whether all file name components are so short that they are valid
     in any file system on this platform.  If CHECK_BASIC_PORTABILITY, though,
     it's more convenient to check component lengths below.  */

  check_component_lengths = check_basic_portability;
  if (! check_component_lengths && ! file_exists)
    {
      for (start = file; *(start = component_start (start)); )
        {
          size_t length = component_len (start);

          if (NAME_MAX_MINIMUM < length)
            {
              check_component_lengths = true;
              break;
            }

          start += length;
        }
    }

  if (check_component_lengths)
    {
      /* The limit on file name components for the current component.
         This defaults to NAME_MAX_MINIMUM, for the sake of non-POSIX
         systems (NFS, say?) where pathconf fails on "." or "/" with
         errno == ENOENT.  */
      size_t name_max = NAME_MAX_MINIMUM;

      /* If nonzero, the known limit on file name components.  */
      size_t known_name_max = (check_basic_portability ? _POSIX_NAME_MAX : 0);

      for (start = file; *(start = component_start (start)); )
        {
          size_t length;

          if (known_name_max)
            name_max = known_name_max;
          else
            {
              long int len;
              char const *dir = (start == file ? "." : file);
              char c = *start;
              errno = 0;
              *start = '\0';
              len = pathconf (dir, _PC_NAME_MAX);
              *start = c;
              if (0 <= len)
                name_max = MIN (len, SSIZE_MAX);
              else
                switch (errno)
                  {
                  case 0:
                    /* There is no limit.  */
                    name_max = SIZE_MAX;
                    break;

                  case ENOENT:
                    /* DIR does not exist; use its parent's maximum.  */
                    known_name_max = name_max;
                    break;

                  default:
                    *start = '\0';
                    error (0, errno, "%s", quotef (dir));
                    *start = c;
                    return false;
                  }
            }

          length = component_len (start);

          if (name_max < length)
            {
              unsigned long int len = length;
              unsigned long int maxlen = name_max;
              char c = start[len];
              start[len] = '\0';
              error (0, 0,
                     _("limit %lu exceeded by length %lu "
                       "of file name component %s"),
                     maxlen, len, quote (start));
              start[len] = c;
              return false;
            }

          start += length;
        }
    }

  return true;
}
