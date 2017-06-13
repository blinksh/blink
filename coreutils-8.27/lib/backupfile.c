/* backupfile.c -- make Emacs style backup file names

   Copyright (C) 1990-2006, 2009-2017 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* Written by Paul Eggert and David MacKenzie.
   Some algorithms adapted from GNU Emacs.  */

#include "config.h"

#include "backupfile.h"

#include "argmatch.h"
#include "dirname.h"
#include "xalloc.h"

#include <errno.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include <limits.h>

#include <unistd.h>

#include "dirent--.h"
#ifndef _D_EXACT_NAMLEN
# define _D_EXACT_NAMLEN(dp) strlen ((dp)->d_name)
#endif
#if D_INO_IN_DIRENT
# define REAL_DIR_ENTRY(dp) ((dp)->d_ino != 0)
#else
# define REAL_DIR_ENTRY(dp) 1
#endif

#if ! (HAVE_PATHCONF && defined _PC_NAME_MAX)
# define pathconf(file, option) (errno = -1)
#endif

#ifndef _POSIX_NAME_MAX
# define _POSIX_NAME_MAX 14
#endif
#ifndef SIZE_MAX
# define SIZE_MAX ((size_t) -1)
#endif

#if defined _XOPEN_NAME_MAX
# define NAME_MAX_MINIMUM _XOPEN_NAME_MAX
#else
# define NAME_MAX_MINIMUM _POSIX_NAME_MAX
#endif

#ifndef HAVE_DOS_FILE_NAMES
# define HAVE_DOS_FILE_NAMES 0
#endif
#ifndef HAVE_LONG_FILE_NAMES
# define HAVE_LONG_FILE_NAMES 0
#endif

/* ISDIGIT differs from isdigit, as follows:
   - Its arg may be any int or unsigned int; it need not be an unsigned char
     or EOF.
   - It's typically faster.
   POSIX says that only '0' through '9' are digits.  Prefer ISDIGIT to
   ISDIGIT unless it's important to use the locale's definition
   of "digit" even when the host does not conform to POSIX.  */
#define ISDIGIT(c) ((unsigned int) (c) - '0' <= 9)

/* The extension added to file names to produce a simple (as opposed
   to numbered) backup file name. */
char const *simple_backup_suffix = NULL;


/* If FILE (which was of length FILELEN before an extension was
   appended to it) is too long, replace the extension with the single
   char E.  If the result is still too long, remove the char just
   before E.  */

static void
check_extension (char *file, size_t filelen, char e)
{
  char *base = last_component (file);
  size_t baselen = base_len (base);
  size_t baselen_max = HAVE_LONG_FILE_NAMES ? 255 : NAME_MAX_MINIMUM;

  if (HAVE_DOS_FILE_NAMES || NAME_MAX_MINIMUM < baselen)
    {
      /* The new base name is long enough to require a pathconf check.  */
      long name_max;

      /* Temporarily modify the buffer into its parent directory name,
         invoke pathconf on the directory, and then restore the buffer.  */
      char tmp[sizeof "."];
      memcpy (tmp, base, sizeof ".");
      strcpy (base, ".");
      errno = 0;
      name_max = pathconf (file, _PC_NAME_MAX);
      if (0 <= name_max || errno == 0)
        {
          long size = baselen_max = name_max;
          if (name_max != size)
            baselen_max = SIZE_MAX;
        }
      memcpy (base, tmp, sizeof ".");
    }

  if (HAVE_DOS_FILE_NAMES && baselen_max <= 12)
    {
      /* Live within DOS's 8.3 limit.  */
      char *dot = strchr (base, '.');
      if (!dot)
        baselen_max = 8;
      else
        {
          char const *second_dot = strchr (dot + 1, '.');
          baselen_max = (second_dot
                         ? second_dot - base
                         : dot + 1 - base + 3);
        }
    }

  if (baselen_max < baselen)
    {
      baselen = file + filelen - base;
      if (baselen_max <= baselen)
        baselen = baselen_max - 1;
      base[baselen] = e;
      base[baselen + 1] = '\0';
    }
}

/* Returned values for NUMBERED_BACKUP.  */

enum numbered_backup_result
  {
    /* The new backup name is the same length as an existing backup
       name, so it's valid for that directory.  */
    BACKUP_IS_SAME_LENGTH,

    /* Some backup names already exist, but the returned name is longer
       than any of them, and its length should be checked.  */
    BACKUP_IS_LONGER,

    /* There are no existing backup names.  The new name's length
       should be checked.  */
    BACKUP_IS_NEW
  };

/* *BUFFER contains a file name.  Store into *BUFFER the next backup
   name for the named file, with a version number greater than all the
   existing numbered backups.  Reallocate *BUFFER as necessary; its
   initial allocated size is BUFFER_SIZE, which must be at least 4
   bytes longer than the file name to make room for the initially
   appended ".~1".  FILELEN is the length of the original file name.
   The returned value indicates what kind of backup was found.  If an
   I/O or other read error occurs, use the highest backup number that
   was found.  */

static enum numbered_backup_result
numbered_backup (char **buffer, size_t buffer_size, size_t filelen)
{
  enum numbered_backup_result result = BACKUP_IS_NEW;
  DIR *dirp;
  struct dirent *dp;
  char *buf = *buffer;
  size_t versionlenmax = 1;
  char *base = last_component (buf);
  size_t base_offset = base - buf;
  size_t baselen = base_len (base);

  /* Temporarily modify the buffer into its parent directory name,
     open the directory, and then restore the buffer.  */
  char tmp[sizeof "."];
  memcpy (tmp, base, sizeof ".");
  strcpy (base, ".");
  dirp = opendir (buf);
  memcpy (base, tmp, sizeof ".");
  strcpy (base + baselen, ".~1~");

  if (!dirp)
    return result;

  while ((dp = readdir (dirp)) != NULL)
    {
      char const *p;
      char *q;
      bool all_9s;
      size_t versionlen;
      size_t new_buflen;

      if (! REAL_DIR_ENTRY (dp) || _D_EXACT_NAMLEN (dp) < baselen + 4)
        continue;

      if (memcmp (buf + base_offset, dp->d_name, baselen + 2) != 0)
        continue;

      p = dp->d_name + baselen + 2;

      /* Check whether this file has a version number and if so,
         whether it is larger.  Use string operations rather than
         integer arithmetic, to avoid problems with integer overflow.  */

      if (! ('1' <= *p && *p <= '9'))
        continue;
      all_9s = (*p == '9');
      for (versionlen = 1; ISDIGIT (p[versionlen]); versionlen++)
        all_9s &= (p[versionlen] == '9');

      if (! (p[versionlen] == '~' && !p[versionlen + 1]
             && (versionlenmax < versionlen
                 || (versionlenmax == versionlen
                     && memcmp (buf + filelen + 2, p, versionlen) <= 0))))
        continue;

      /* This directory has the largest version number seen so far.
         Append this highest numbered extension to the file name,
         prepending '0' to the number if it is all 9s.  */

      versionlenmax = all_9s + versionlen;
      result = (all_9s ? BACKUP_IS_LONGER : BACKUP_IS_SAME_LENGTH);
      new_buflen = filelen + 2 + versionlenmax + 1;
      if (buffer_size <= new_buflen)
        {
          buf = xnrealloc (buf, 2, new_buflen);
          buffer_size = new_buflen * 2;
        }
      q = buf + filelen;
      *q++ = '.';
      *q++ = '~';
      *q = '0';
      q += all_9s;
      memcpy (q, p, versionlen + 2);

      /* Add 1 to the version number.  */

      q += versionlen;
      while (*--q == '9')
        *q = '0';
      ++*q;
    }

  closedir (dirp);
  *buffer = buf;
  return result;
}

/* Return the name of the new backup file for the existing file FILE,
   allocated with malloc.  Report an error and fail if out of memory.
   Do not call this function if backup_type == no_backups.  */

char *
find_backup_file_name (char const *file, enum backup_type backup_type)
{
  size_t filelen = strlen (file);
  char *s;
  size_t ssize;
  bool simple = true;

  /* Initialize the default simple backup suffix.  */
  if (! simple_backup_suffix)
    {
      char const *env_suffix = getenv ("SIMPLE_BACKUP_SUFFIX");
      if (env_suffix && *env_suffix)
        simple_backup_suffix = env_suffix;
      else
        simple_backup_suffix = "~";
    }

  /* Allow room for simple or ".~N~" backups.  The guess must be at
     least sizeof ".~1~", but otherwise will be adjusted as needed.  */
  size_t simple_backup_suffix_size = strlen (simple_backup_suffix) + 1;
  size_t backup_suffix_size_guess = simple_backup_suffix_size;
  enum { GUESS = sizeof ".~12345~" };
  if (backup_suffix_size_guess < GUESS)
    backup_suffix_size_guess = GUESS;

  ssize = filelen + backup_suffix_size_guess + 1;
  s = xmalloc (ssize);
  memcpy (s, file, filelen + 1);

  if (backup_type != simple_backups)
    switch (numbered_backup (&s, ssize, filelen))
      {
      case BACKUP_IS_SAME_LENGTH:
        return s;

      case BACKUP_IS_LONGER:
        simple = false;
        break;

      case BACKUP_IS_NEW:
        simple = (backup_type == numbered_existing_backups);
        break;
      }

  if (simple)
    memcpy (s + filelen, simple_backup_suffix, simple_backup_suffix_size);
  check_extension (s, filelen, '~');
  return s;
}

static char const * const backup_args[] =
{
  /* In a series of synonyms, present the most meaningful first, so
     that argmatch_valid be more readable. */
  "none", "off",
  "simple", "never",
  "existing", "nil",
  "numbered", "t",
  NULL
};

static const enum backup_type backup_types[] =
{
  no_backups, no_backups,
  simple_backups, simple_backups,
  numbered_existing_backups, numbered_existing_backups,
  numbered_backups, numbered_backups
};

/* Ensure that these two vectors have the same number of elements,
   not counting the final NULL in the first one.  */
ARGMATCH_VERIFY (backup_args, backup_types);

/* Return the type of backup specified by VERSION.
   If VERSION is NULL or the empty string, return numbered_existing_backups.
   If VERSION is invalid or ambiguous, fail with a diagnostic appropriate
   for the specified CONTEXT.  Unambiguous abbreviations are accepted.  */

enum backup_type
get_version (char const *context, char const *version)
{
  if (version == 0 || *version == 0)
    return numbered_existing_backups;
  else
    return XARGMATCH (context, version, backup_args, backup_types);
}


/* Return the type of backup specified by VERSION.
   If VERSION is NULL, use the value of the envvar VERSION_CONTROL.
   If the specified string is invalid or ambiguous, fail with a diagnostic
   appropriate for the specified CONTEXT.
   Unambiguous abbreviations are accepted.  */

enum backup_type
xget_version (char const *context, char const *version)
{
  if (version && *version)
    return get_version (context, version);
  else
    return get_version ("$VERSION_CONTROL", getenv ("VERSION_CONTROL"));
}
