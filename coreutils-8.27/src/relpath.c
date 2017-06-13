/* relpath - print the relative path
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

/* Written by Pádraig Brady.  */

#include <config.h>

#include "error.h"
#include "system.h"
#include "relpath.h"


/* Return the length of the longest common prefix
   of canonical PATH1 and PATH2, ensuring only full path components
   are matched.  Return 0 on no match.  */
static int _GL_ATTRIBUTE_PURE
path_common_prefix (const char *path1, const char *path2)
{
  int i = 0;
  int ret = 0;

  /* We already know path1[0] and path2[0] are '/'.  Special case
     '//', which is only present in a canonical name on platforms
     where it is distinct.  */
  if ((path1[1] == '/') != (path2[1] == '/'))
    return 0;

  while (*path1 && *path2)
    {
      if (*path1 != *path2)
        break;
      if (*path1 == '/')
        ret = i + 1;
      path1++;
      path2++;
      i++;
    }

  if ((!*path1 && !*path2)
      || (!*path1 && *path2 == '/')
      || (!*path2 && *path1 == '/'))
    ret = i;

  return ret;
}

/* Either output STR to stdout or
   if *PBUF is not NULL then append STR to *PBUF
   and update *PBUF to point to the end of the buffer
   and adjust *PLEN to reflect the remaining space.
   Return TRUE on failure.  */
static bool
buffer_or_output (const char* str, char **pbuf, size_t *plen)
{
  if (*pbuf)
    {
      size_t slen = strlen (str);
      if (slen >= *plen)
        return true;
      memcpy (*pbuf, str, slen + 1);
      *pbuf += slen;
      *plen -= slen;
    }
  else
    {
      fputs (str, stdout);
    }

  return false;
}

/* Output the relative representation if possible.
   If BUF is non-NULL, write to that buffer rather than to stdout.  */
bool
relpath (const char *can_fname, const char *can_reldir, char *buf, size_t len)
{
  bool buf_err = false;

  /* Skip the prefix common to --relative-to and path.  */
  int common_index = path_common_prefix (can_reldir, can_fname);
  if (!common_index)
    return false;

  const char *relto_suffix = can_reldir + common_index;
  const char *fname_suffix = can_fname + common_index;

  /* Skip over extraneous '/'.  */
  if (*relto_suffix == '/')
    relto_suffix++;
  if (*fname_suffix == '/')
    fname_suffix++;

  /* Replace remaining components of --relative-to with '..', to get
     to a common directory.  Then output the remainder of fname.  */
  if (*relto_suffix)
    {
      buf_err |= buffer_or_output ("..", &buf, &len);
      for (; *relto_suffix; ++relto_suffix)
        {
          if (*relto_suffix == '/')
            buf_err |= buffer_or_output ("/..", &buf, &len);
        }

      if (*fname_suffix)
        {
          buf_err |= buffer_or_output ("/", &buf, &len);
          buf_err |= buffer_or_output (fname_suffix, &buf, &len);
        }
    }
  else
    {
        buf_err |= buffer_or_output (*fname_suffix ? fname_suffix : ".",
                                     &buf, &len);
    }

  if (buf_err)
    error (0, ENAMETOOLONG, "%s", _("generating relative path"));

  return !buf_err;
}
