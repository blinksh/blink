/* Test whether a file has a nontrivial ACL.  -*- coding: utf-8 -*-

   Copyright (C) 2002-2003, 2005-2017 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.

   Written by Paul Eggert, Andreas Grünbacher, and Bruno Haible.  */

/* Without this pragma, gcc 4.7.0 20120126 may suggest that the
   file_has_acl function might be candidate for attribute 'const'  */
#if (__GNUC__ == 4 && 6 <= __GNUC_MINOR__) || 4 < __GNUC__
# pragma GCC diagnostic ignored "-Wsuggest-attribute=const"
#endif

#include "config.h"

#include "acl.h"

#include "acl-internal.h"

#if GETXATTR_WITH_POSIX_ACLS
# include <sys/xattr.h>
# include <linux/xattr.h>
#endif

/* Return 1 if NAME has a nontrivial access control list,
   0 if ACLs are not supported, or if NAME has no or only a base ACL,
   and -1 (setting errno) on error.  Note callers can determine
   if ACLs are not supported as errno is set in that case also.
   SB must be set to the stat buffer of NAME,
   obtained through stat() or lstat().  */

int
file_has_acl (char const *name, struct stat const *sb)
{
#if USE_ACL
  if (! S_ISLNK (sb->st_mode))
    {

# if GETXATTR_WITH_POSIX_ACLS

      ssize_t ret;

      ret = getxattr (name, XATTR_NAME_POSIX_ACL_ACCESS, NULL, 0);
      if (ret < 0 && errno == ENODATA)
        ret = 0;
      else if (ret > 0)
        return 1;

      if (ret == 0 && S_ISDIR (sb->st_mode))
        {
          ret = getxattr (name, XATTR_NAME_POSIX_ACL_DEFAULT, NULL, 0);
          if (ret < 0 && errno == ENODATA)
            ret = 0;
          else if (ret > 0)
            return 1;
        }

      if (ret < 0)
        return - acl_errno_valid (errno);
      return ret;

# elif HAVE_ACL_GET_FILE

      /* POSIX 1003.1e (draft 17 -- abandoned) specific version.  */
      /* Linux, FreeBSD, Mac OS X, IRIX, Tru64 */
      int ret;

      if (HAVE_ACL_EXTENDED_FILE) /* Linux */
        {
          /* On Linux, acl_extended_file is an optimized function: It only
             makes two calls to getxattr(), one for ACL_TYPE_ACCESS, one for
             ACL_TYPE_DEFAULT.  */
          ret = acl_extended_file (name);
        }
      else /* FreeBSD, Mac OS X, IRIX, Tru64 */
        {
#  if HAVE_ACL_TYPE_EXTENDED /* Mac OS X */
          /* On Mac OS X, acl_get_file (name, ACL_TYPE_ACCESS)
             and acl_get_file (name, ACL_TYPE_DEFAULT)
             always return NULL / EINVAL.  There is no point in making
             these two useless calls.  The real ACL is retrieved through
             acl_get_file (name, ACL_TYPE_EXTENDED).  */
          acl_t acl = acl_get_file (name, ACL_TYPE_EXTENDED);
          if (acl)
            {
              ret = acl_extended_nontrivial (acl);
              acl_free (acl);
            }
          else
            ret = -1;
#  else /* FreeBSD, IRIX, Tru64 */
          acl_t acl = acl_get_file (name, ACL_TYPE_ACCESS);
          if (acl)
            {
              int saved_errno;

              ret = acl_access_nontrivial (acl);
              saved_errno = errno;
              acl_free (acl);
              errno = saved_errno;
#   if HAVE_ACL_FREE_TEXT /* Tru64 */
              /* On OSF/1, acl_get_file (name, ACL_TYPE_DEFAULT) always
                 returns NULL with errno not set.  There is no point in
                 making this call.  */
#   else /* FreeBSD, IRIX */
              /* On Linux, FreeBSD, IRIX, acl_get_file (name, ACL_TYPE_ACCESS)
                 and acl_get_file (name, ACL_TYPE_DEFAULT) on a directory
                 either both succeed or both fail; it depends on the
                 file system.  Therefore there is no point in making the second
                 call if the first one already failed.  */
              if (ret == 0 && S_ISDIR (sb->st_mode))
                {
                  acl = acl_get_file (name, ACL_TYPE_DEFAULT);
                  if (acl)
                    {
                      ret = (0 < acl_entries (acl));
                      acl_free (acl);
                    }
                  else
                    ret = -1;
                }
#   endif
            }
          else
            ret = -1;
#  endif
        }
      if (ret < 0)
        return - acl_errno_valid (errno);
      return ret;

# elif HAVE_FACL && defined GETACL /* Solaris, Cygwin, not HP-UX */

#  if defined ACL_NO_TRIVIAL

      /* Solaris 10 (newer version), which has additional API declared in
         <sys/acl.h> (acl_t) and implemented in libsec (acl_set, acl_trivial,
         acl_fromtext, ...).  */
      return acl_trivial (name);

#  else /* Solaris, Cygwin, general case */

      /* Solaris 2.5 through Solaris 10, Cygwin, and contemporaneous versions
         of Unixware.  The acl() call returns the access and default ACL both
         at once.  */
      {
        /* Initially, try to read the entries into a stack-allocated buffer.
           Use malloc if it does not fit.  */
        enum
          {
            alloc_init = 4000 / sizeof (aclent_t), /* >= 3 */
            alloc_max = MIN (INT_MAX, SIZE_MAX / sizeof (aclent_t))
          };
        aclent_t buf[alloc_init];
        size_t alloc = alloc_init;
        aclent_t *entries = buf;
        aclent_t *malloced = NULL;
        int count;

        for (;;)
          {
            count = acl (name, GETACL, alloc, entries);
            if (count < 0 && errno == ENOSPC)
              {
                /* Increase the size of the buffer.  */
                free (malloced);
                if (alloc > alloc_max / 2)
                  {
                    errno = ENOMEM;
                    return -1;
                  }
                alloc = 2 * alloc; /* <= alloc_max */
                entries = malloced =
                  (aclent_t *) malloc (alloc * sizeof (aclent_t));
                if (entries == NULL)
                  {
                    errno = ENOMEM;
                    return -1;
                  }
                continue;
              }
            break;
          }
        if (count < 0)
          {
            if (errno == ENOSYS || errno == ENOTSUP)
              ;
            else
              {
                int saved_errno = errno;
                free (malloced);
                errno = saved_errno;
                return -1;
              }
          }
        else if (count == 0)
          ;
        else
          {
            /* Don't use MIN_ACL_ENTRIES:  It's set to 4 on Cygwin, but Cygwin
               returns only 3 entries for files with no ACL.  But this is safe:
               If there are more than 4 entries, there cannot be only the
               "user::", "group::", "other:", and "mask:" entries.  */
            if (count > 4)
              {
                free (malloced);
                return 1;
              }

            if (acl_nontrivial (count, entries))
              {
                free (malloced);
                return 1;
              }
          }
        free (malloced);
      }

#   ifdef ACE_GETACL
      /* Solaris also has a different variant of ACLs, used in ZFS and NFSv4
         file systems (whereas the other ones are used in UFS file systems).  */
      {
        /* Initially, try to read the entries into a stack-allocated buffer.
           Use malloc if it does not fit.  */
        enum
          {
            alloc_init = 4000 / sizeof (ace_t), /* >= 3 */
            alloc_max = MIN (INT_MAX, SIZE_MAX / sizeof (ace_t))
          };
        ace_t buf[alloc_init];
        size_t alloc = alloc_init;
        ace_t *entries = buf;
        ace_t *malloced = NULL;
        int count;

        for (;;)
          {
            count = acl (name, ACE_GETACL, alloc, entries);
            if (count < 0 && errno == ENOSPC)
              {
                /* Increase the size of the buffer.  */
                free (malloced);
                if (alloc > alloc_max / 2)
                  {
                    errno = ENOMEM;
                    return -1;
                  }
                alloc = 2 * alloc; /* <= alloc_max */
                entries = malloced = (ace_t *) malloc (alloc * sizeof (ace_t));
                if (entries == NULL)
                  {
                    errno = ENOMEM;
                    return -1;
                  }
                continue;
              }
            break;
          }
        if (count < 0)
          {
            if (errno == ENOSYS || errno == EINVAL)
              ;
            else
              {
                int saved_errno = errno;
                free (malloced);
                errno = saved_errno;
                return -1;
              }
          }
        else if (count == 0)
          ;
        else
          {
            /* In the old (original Solaris 10) convention:
               If there are more than 3 entries, there cannot be only the
               ACE_OWNER, ACE_GROUP, ACE_OTHER entries.
               In the newer Solaris 10 and Solaris 11 convention:
               If there are more than 6 entries, there cannot be only the
               ACE_OWNER, ACE_GROUP, ACE_EVERYONE entries, each once with
               NEW_ACE_ACCESS_ALLOWED_ACE_TYPE and once with
               NEW_ACE_ACCESS_DENIED_ACE_TYPE.  */
            if (count > 6)
              {
                free (malloced);
                return 1;
              }

            if (acl_ace_nontrivial (count, entries))
              {
                free (malloced);
                return 1;
              }
          }
        free (malloced);
      }
#   endif

      return 0;
#  endif

# elif HAVE_GETACL /* HP-UX */

      {
        struct acl_entry entries[NACLENTRIES];
        int count;

        count = getacl (name, NACLENTRIES, entries);

        if (count < 0)
          {
            /* ENOSYS is seen on newer HP-UX versions.
               EOPNOTSUPP is typically seen on NFS mounts.
               ENOTSUP was seen on Quantum StorNext file systems (cvfs).  */
            if (errno == ENOSYS || errno == EOPNOTSUPP || errno == ENOTSUP)
              ;
            else
              return -1;
          }
        else if (count == 0)
          return 0;
        else /* count > 0 */
          {
            if (count > NACLENTRIES)
              /* If NACLENTRIES cannot be trusted, use dynamic memory
                 allocation.  */
              abort ();

            /* If there are more than 3 entries, there cannot be only the
               (uid,%), (%,gid), (%,%) entries.  */
            if (count > 3)
              return 1;

            {
              struct stat statbuf;

              if (stat (name, &statbuf) < 0)
                return -1;

              return acl_nontrivial (count, entries);
            }
          }
      }

#  if HAVE_ACLV_H /* HP-UX >= 11.11 */

      {
        struct acl entries[NACLVENTRIES];
        int count;

        count = acl ((char *) name, ACL_GET, NACLVENTRIES, entries);

        if (count < 0)
          {
            /* EOPNOTSUPP is seen on NFS in HP-UX 11.11, 11.23.
               EINVAL is seen on NFS in HP-UX 11.31.  */
            if (errno == ENOSYS || errno == EOPNOTSUPP || errno == EINVAL)
              ;
            else
              return -1;
          }
        else if (count == 0)
          return 0;
        else /* count > 0 */
          {
            if (count > NACLVENTRIES)
              /* If NACLVENTRIES cannot be trusted, use dynamic memory
                 allocation.  */
              abort ();

            /* If there are more than 4 entries, there cannot be only the
               four base ACL entries.  */
            if (count > 4)
              return 1;

            return aclv_nontrivial (count, entries);
          }
      }

#  endif

# elif HAVE_ACLX_GET && defined ACL_AIX_WIP /* AIX */

      acl_type_t type;
      char aclbuf[1024];
      void *acl = aclbuf;
      size_t aclsize = sizeof (aclbuf);
      mode_t mode;

      for (;;)
        {
          /* The docs say that type being 0 is equivalent to ACL_ANY, but it
             is not true, in AIX 5.3.  */
          type.u64 = ACL_ANY;
          if (aclx_get (name, 0, &type, aclbuf, &aclsize, &mode) >= 0)
            break;
          if (errno == ENOSYS)
            return 0;
          if (errno != ENOSPC)
            {
              if (acl != aclbuf)
                {
                  int saved_errno = errno;
                  free (acl);
                  errno = saved_errno;
                }
              return -1;
            }
          aclsize = 2 * aclsize;
          if (acl != aclbuf)
            free (acl);
          acl = malloc (aclsize);
          if (acl == NULL)
            {
              errno = ENOMEM;
              return -1;
            }
        }

      if (type.u64 == ACL_AIXC)
        {
          int result = acl_nontrivial ((struct acl *) acl);
          if (acl != aclbuf)
            free (acl);
          return result;
        }
      else if (type.u64 == ACL_NFS4)
        {
          int result = acl_nfs4_nontrivial ((nfs4_acl_int_t *) acl);
          if (acl != aclbuf)
            free (acl);
          return result;
        }
      else
        {
          /* A newer type of ACL has been introduced in the system.
             We should better support it.  */
          if (acl != aclbuf)
            free (acl);
          errno = EINVAL;
          return -1;
        }

# elif HAVE_STATACL /* older AIX */

      union { struct acl a; char room[4096]; } u;

      if (statacl ((char *) name, STX_NORMAL, &u.a, sizeof (u)) < 0)
        return -1;

      return acl_nontrivial (&u.a);

# elif HAVE_ACLSORT /* NonStop Kernel */

      {
        struct acl entries[NACLENTRIES];
        int count;

        count = acl ((char *) name, ACL_GET, NACLENTRIES, entries);

        if (count < 0)
          {
            if (errno == ENOSYS || errno == ENOTSUP)
              ;
            else
              return -1;
          }
        else if (count == 0)
          return 0;
        else /* count > 0 */
          {
            if (count > NACLENTRIES)
              /* If NACLENTRIES cannot be trusted, use dynamic memory
                 allocation.  */
              abort ();

            /* If there are more than 4 entries, there cannot be only the
               four base ACL entries.  */
            if (count > 4)
              return 1;

            return acl_nontrivial (count, entries);
          }
      }

# endif
    }
#endif

  return 0;
}
