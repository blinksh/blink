/* Return a string describing the type of a file.

   Copyright (C) 1993-1994, 2001-2002, 2004-2006, 2009-2017 Free Software
   Foundation, Inc.

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

/* Written by Paul Eggert.  */

#include "config.h"

#include "file-type.h"

#include <gettext.h>
#define _(text) gettext (text)

char const *
file_type (struct stat const *st)
{
  /* See POSIX 1003.1-2001 XCU Table 4-8 lines 17093-17107 for some of
     these formats.

     To keep diagnostics grammatical in English, the returned string
     must start with a consonant.  */

  /* Do these three first, as they're the most common.  */

  if (S_ISREG (st->st_mode))
    return st->st_size == 0 ? _("regular empty file") : _("regular file");

  if (S_ISDIR (st->st_mode))
    return _("directory");

  if (S_ISLNK (st->st_mode))
    return _("symbolic link");

  /* Do the S_TYPEIS* macros next, as they may be implemented in terms
     of S_ISNAM, and we want the more-specialized interpretation.  */

  if (S_TYPEISMQ (st))
    return _("message queue");

  if (S_TYPEISSEM (st))
    return _("semaphore");

  if (S_TYPEISSHM (st))
    return _("shared memory object");

  if (S_TYPEISTMO (st))
    return _("typed memory object");

  /* The remaining are in alphabetical order.  */

  if (S_ISBLK (st->st_mode))
    return _("block special file");

  if (S_ISCHR (st->st_mode))
    return _("character special file");

  if (S_ISCTG (st->st_mode))
    return _("contiguous data");

  if (S_ISFIFO (st->st_mode))
    return _("fifo");

  if (S_ISDOOR (st->st_mode))
    return _("door");

  if (S_ISMPB (st->st_mode))
    return _("multiplexed block special file");

  if (S_ISMPC (st->st_mode))
    return _("multiplexed character special file");

  if (S_ISMPX (st->st_mode))
    return _("multiplexed file");

  if (S_ISNAM (st->st_mode))
    return _("named file");

  if (S_ISNWK (st->st_mode))
    return _("network special file");

  if (S_ISOFD (st->st_mode))
    return _("migrated file with data");

  if (S_ISOFL (st->st_mode))
    return _("migrated file without data");

  if (S_ISPORT (st->st_mode))
    return _("port");

  if (S_ISSOCK (st->st_mode))
    return _("socket");

  if (S_ISWHT (st->st_mode))
    return _("whiteout");

  return _("weird file");
}
