/* Copy access control list from one file to another.  -*- coding: utf-8 -*-

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

#include "config.h"

#include "acl.h"

#include "acl-internal.h"


/* Copy access control lists from one file to another. If SOURCE_DESC is
   a valid file descriptor, use file descriptor operations, else use
   filename based operations on SRC_NAME. Likewise for DEST_DESC and
   DST_NAME.
   If access control lists are not available, fchmod the target file to
   MODE.  Also sets the non-permission bits of the destination file
   (S_ISUID, S_ISGID, S_ISVTX) to those from MODE if any are set.
   Return 0 if successful.
   Return -2 and set errno for an error relating to the source file.
   Return -1 and set errno for an error relating to the destination file.  */

int
qcopy_acl (const char *src_name, int source_desc, const char *dst_name,
           int dest_desc, mode_t mode)
{
  struct permission_context ctx;
  int ret;

  ret = get_permissions (src_name, source_desc, mode, &ctx);
  if (ret != 0)
    return -2;
  ret = set_permissions (&ctx, dst_name, dest_desc);
  free_permission_context (&ctx);
  return ret;
}
