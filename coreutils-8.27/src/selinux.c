/* selinux - core functions for maintaining SELinux labeling
   Copyright (C) 2012-2017 Free Software Foundation, Inc.

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

/* Written by Daniel Walsh <dwalsh@redhat.com> */

#include <config.h>
#include <selinux/selinux.h>
#include <selinux/context.h>
#include <sys/types.h>

#include "die.h"
#include "error.h"
#include "system.h"
#include "canonicalize.h"
#include "dosname.h"
#include "xfts.h"
#include "selinux.h"

#if HAVE_SELINUX_SELINUX_H

# if ! HAVE_MODE_TO_SECURITY_CLASS
/*
  This function has been added to libselinux-2.1.12-5, but is here
  for support with older versions of SELinux

  Translates a mode into an Internal SELinux security_class definition.
  Returns 0 on failure, with errno set to EINVAL.
*/
static security_class_t
mode_to_security_class (mode_t m)
{

  if (S_ISREG (m))
    return string_to_security_class ("file");
  if (S_ISDIR (m))
    return string_to_security_class ("dir");
  if (S_ISCHR (m))
    return string_to_security_class ("chr_file");
  if (S_ISBLK (m))
    return string_to_security_class ("blk_file");
  if (S_ISFIFO (m))
    return string_to_security_class ("fifo_file");
  if (S_ISLNK (m))
    return string_to_security_class ("lnk_file");
  if (S_ISSOCK (m))
    return string_to_security_class ("sock_file");

  errno = EINVAL;
  return 0;
}
# endif

/*
  This function takes a PATH and a MODE and then asks SELinux what the label
  of the path object would be if the current process label created it.
  It then returns the label.

  Returns -1 on failure.  errno will be set appropriately.
*/

static int
computecon (char const *path, mode_t mode, char **con)
{
  char *scon = NULL;
  char *tcon = NULL;
  security_class_t tclass;
  int rc = -1;

  char *dir = dir_name (path);
  if (!dir)
    goto quit;
  if (getcon (&scon) < 0)
    goto quit;
  if (getfilecon (dir, &tcon) < 0)
    goto quit;
  tclass = mode_to_security_class (mode);
  if (!tclass)
    goto quit;
  rc = security_compute_create (scon, tcon, tclass, con);

quit:
  free (dir);
  freecon (scon);
  freecon (tcon);
  return rc;
}

/*
  This function takes a path and a mode, it calls computecon to get the
  label of the path object if the current process created it, then it calls
  matchpathcon to get the default type for the object.  It substitutes the
  default type into label.  It tells the SELinux Kernel to label all new file
  system objects created by the current process with this label.

  Returns -1 on failure.  errno will be set appropriately.
*/
int
defaultcon (char const *path, mode_t mode)
{
  int rc = -1;
  char *scon = NULL;
  char *tcon = NULL;
  context_t scontext = 0, tcontext = 0;
  const char *contype;
  char *constr;
  char *newpath = NULL;

  if (! IS_ABSOLUTE_FILE_NAME (path))
    {
      /* Generate absolute path as required by subsequent matchpathcon(),
         with libselinux < 2.1.5 2011-0826.  */
      newpath = canonicalize_filename_mode (path, CAN_MISSING);
      if (! newpath)
        die (EXIT_FAILURE, errno, _("error canonicalizing %s"),
             quoteaf (path));
      path = newpath;
    }

  if (matchpathcon (path, mode, &scon) < 0)
    {
      /* "No such file or directory" is a confusing error,
         when processing files, when in fact it was the
         associated default context that was not found.
         Therefore map the error to something more appropriate
         to the context in which we're using matchpathcon().  */
      if (errno == ENOENT)
        errno = ENODATA;
      goto quit;
    }
  if (computecon (path, mode, &tcon) < 0)
    goto quit;
  if (!(scontext = context_new (scon)))
    goto quit;
  if (!(tcontext = context_new (tcon)))
    goto quit;

  if (!(contype = context_type_get (scontext)))
    goto quit;
  if (context_type_set (tcontext, contype))
    goto quit;
  if (!(constr = context_str (tcontext)))
    goto quit;

  rc = setfscreatecon (constr);

quit:
  context_free (scontext);
  context_free (tcontext);
  freecon (scon);
  freecon (tcon);
  free (newpath);
  return rc;
}

/*
  This function takes a PATH of an existing file system object, and a LOCAL
  boolean that indicates whether the function should set the object's label
  to the default for the local process, or one using system wide settings.
  If LOCAL == true, it will ask the SELinux Kernel what the default label
  for all objects created should be and then sets the label on the object.
  Otherwise it calls matchpathcon on the object to ask the system what the
  default label should be, extracts the type field and then modifies the file
  system object.  Note only the type field is updated, thus preserving MLS
  levels and user identity etc. of the PATH.

  Returns -1 on failure.  errno will be set appropriately.
*/
static int
restorecon_private (char const *path, bool local)
{
  int rc = -1;
  struct stat sb;
  char *scon = NULL;
  char *tcon = NULL;
  context_t scontext = 0, tcontext = 0;
  const char *contype;
  char *constr;
  int fd;

  if (local)
    {
      if (getfscreatecon (&tcon) < 0)
        return rc;
      if (!tcon)
        {
          errno = ENODATA;
          return rc;
        }
      rc = lsetfilecon (path, tcon);
      freecon (tcon);
      return rc;
    }

  fd = open (path, O_RDONLY | O_NOFOLLOW);
  if (fd == -1 && (errno != ELOOP))
    goto quit;

  if (fd != -1)
    {
      if (fstat (fd, &sb) < 0)
        goto quit;
    }
  else
    {
      if (lstat (path, &sb) < 0)
        goto quit;
    }

  if (matchpathcon (path, sb.st_mode, &scon) < 0)
    {
      /* "No such file or directory" is a confusing error,
         when processing files, when in fact it was the
         associated default context that was not found.
         Therefore map the error to something more appropriate
         to the context in which we're using matchpathcon().  */
      if (errno == ENOENT)
        errno = ENODATA;
      goto quit;
    }
  if (!(scontext = context_new (scon)))
    goto quit;

  if (fd != -1)
    {
      if (fgetfilecon (fd, &tcon) < 0)
        goto quit;
    }
  else
    {
      if (lgetfilecon (path, &tcon) < 0)
        goto quit;
    }

  if (!(tcontext = context_new (tcon)))
    goto quit;

  if (!(contype = context_type_get (scontext)))
    goto quit;
  if (context_type_set (tcontext, contype))
    goto quit;
  if (!(constr = context_str (tcontext)))
    goto quit;

  if (fd != -1)
    rc = fsetfilecon (fd, constr);
  else
    rc = lsetfilecon (path, constr);

quit:
  if (fd != -1)
    close (fd);
  context_free (scontext);
  context_free (tcontext);
  freecon (scon);
  freecon (tcon);
  return rc;
}

/*
  This function takes three parameters:

  PATH of an existing file system object.

  A RECURSE boolean which if the file system object is a directory, will
  call restorecon_private on every file system object in the directory.

  A LOCAL boolean that indicates whether the function should set object labels
  to the default for the local process, or use system wide settings.

  Returns false on failure.  errno will be set appropriately.
*/
bool
restorecon (char const *path, bool recurse, bool local)
{
  char *newpath = NULL;
  FTS *fts;
  bool ok = true;

  if (! IS_ABSOLUTE_FILE_NAME (path) && ! local)
    {
      /* Generate absolute path as required by subsequent matchpathcon(),
         with libselinux < 2.1.5 2011-0826.  Also generating the absolute
         path before the fts walk, will generate absolute paths in the
         fts entries, which may be quicker to process in any case.  */
      newpath = canonicalize_filename_mode (path, CAN_MISSING);
      if (! newpath)
        die (EXIT_FAILURE, errno, _("error canonicalizing %s"),
             quoteaf (path));
    }

  const char *ftspath[2] = { newpath ? newpath : path, NULL };

  if (! recurse)
    {
      ok = restorecon_private (*ftspath, local) != -1;
      free (newpath);
      return ok;
    }

  fts = xfts_open ((char *const *) ftspath, FTS_PHYSICAL, NULL);
  while (1)
    {
      FTSENT *ent;

      ent = fts_read (fts);
      if (ent == NULL)
        {
          if (errno != 0)
            {
              error (0, errno, _("fts_read failed"));
              ok = false;
            }
          break;
        }

      ok &= restorecon_private (fts->fts_path, local) != -1;
    }

  if (fts_close (fts) != 0)
    {
      error (0, errno, _("fts_close failed"));
      ok = false;
    }

  free (newpath);
  return ok;
}
#endif
