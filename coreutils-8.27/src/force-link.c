/* Implement ln -f "atomically"

   Copyright 2017 Free Software Foundation, Inc.

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

/* Written by Paul Eggert.  */

/* A naive "ln -f A B" unlinks B and then links A to B.  This module
   instead links A to a randomly-named temporary T in B's directory,
   and then renames T to B.  This approach has a window with a
   randomly-named temporary, which is safer for many applications than
   a window where B does not exist.  */

#include <config.h>
#include "system.h"

#include "force-link.h"

#include <tempname.h>

/* A basename pattern suitable for a temporary file.  It should work
   even on file systems like FAT that support only short names.
   "Cu" is short for "Coreutils" or for "Changeable unstable",
   take your pick....  */

static char const simple_pattern[] = "CuXXXXXX";
enum { x_suffix_len = sizeof "XXXXXX" - 1 };

/* A size for smallish buffers containing file names.  Longer file
   names can use malloc.  */

enum { smallsize = 256 };

/* Return a template for a file in the same directory as DSTNAME.
   Use BUF if the template fits, otherwise use malloc and return NULL
   (setting errno) if unsuccessful.  */

static char *
samedir_template (char const *dstname, char buf[smallsize])
{
  ptrdiff_t dstdirlen = last_component (dstname) - dstname;
  size_t dsttmpsize = dstdirlen + sizeof simple_pattern;
  char *dsttmp;
  if (dsttmpsize <= smallsize)
    dsttmp = buf;
  else
    {
      dsttmp = malloc (dsttmpsize);
      if (!dsttmp)
        return dsttmp;
    }
  strcpy (mempcpy (dsttmp, dstname, dstdirlen), simple_pattern);
  return dsttmp;
}


/* Auxiliaries for force_linkat.  */

struct link_arg
{
  int srcdir;
  char const *srcname;
  int dstdir;
  int flags;
};

static int
try_link (char *dest, void *arg)
{
  struct link_arg *a = arg;
  return linkat (a->srcdir, a->srcname, a->dstdir, dest, a->flags);
}

/* Hard-link directory SRCDIR's file SRCNAME to directory DSTDIR's
   file DSTNAME, using linkat-style FLAGS to control the linking.
   If FORCE and DSTNAME already exists, replace it atomically.  Return
   1 if successful and DSTNAME already existed,
   0 if successful and DSTNAME did not already exist, and
   -1 (setting errno) on failure.  */
extern int
force_linkat (int srcdir, char const *srcname,
              int dstdir, char const *dstname, int flags, bool force)
{
  int r = linkat (srcdir, srcname, dstdir, dstname, flags);
  if (!force || r == 0 || errno != EEXIST)
    return r;

  char buf[smallsize];
  char *dsttmp = samedir_template (dstname, buf);
  if (! dsttmp)
    return -1;
  struct link_arg arg = { srcdir, srcname, dstdir, flags };
  int err;

  if (try_tempname_len (dsttmp, 0, &arg, try_link, x_suffix_len) != 0)
    err = errno;
  else
    {
      err = renameat (dstdir, dsttmp, dstdir, dstname) == 0 ? 0 : errno;
      /* Unlink DSTTMP even if renameat succeeded, in case DSTTMP
         and DSTNAME were already the same hard link and renameat
         was a no-op.  */
      unlinkat (dstdir, dsttmp, 0);
    }

  if (dsttmp != buf)
    free (dsttmp);
  if (!err)
    return 1;
  errno = err;
  return -1;
}


/* Auxiliaries for force_symlinkat.  */

struct symlink_arg
{
  char const *srcname;
  int dstdir;
};

static int
try_symlink (char *dest, void *arg)
{
  struct symlink_arg *a = arg;
  return symlinkat (a->srcname, a->dstdir, dest);
}

/* Create a symlink containing SRCNAME in directory DSTDIR's file DSTNAME.
   If FORCE and DSTNAME already exists, replace it atomically.  Return
   1 if successful and DSTNAME already existed,
   0 if successful and DSTNAME did not already exist, and
   -1 (setting errno) on failure.  */
extern int
force_symlinkat (char const *srcname, int dstdir, char const *dstname,
                 bool force)
{
  int r = symlinkat (srcname, dstdir, dstname);
  if (!force || r == 0 || errno != EEXIST)
    return r;

  char buf[smallsize];
  char *dsttmp = samedir_template (dstname, buf);
  if (!dsttmp)
    return -1;
  struct symlink_arg arg = { srcname, dstdir };
  int err;

  if (try_tempname_len (dsttmp, 0, &arg, try_symlink, x_suffix_len) != 0)
    err = errno;
  else if (renameat (dstdir, dsttmp, dstdir, dstname) != 0)
    {
      err = errno;
      unlinkat (dstdir, dsttmp, 0);
    }
  else
    {
      /* Don't worry about renameat being a no-op, since DSTTMP is
         newly created.  */
      err = 0;
    }

  if (dsttmp != buf)
    free (dsttmp);
  if (!err)
    return 1;
  errno = err;
  return -1;
}
