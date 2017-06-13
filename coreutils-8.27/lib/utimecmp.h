/* utimecmp.h -- compare file timestamps

   Copyright (C) 2004, 2009-2017 Free Software Foundation, Inc.

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

#ifndef UTIMECMP_H
#define UTIMECMP_H 1

#include <sys/types.h>
#include <sys/stat.h>

/* Options for utimecmp.  */
enum
{
  /* Before comparing, truncate the source timestamp to the
     resolution of the destination file system and to the resolution
     of utimens.  */
  UTIMECMP_TRUNCATE_SOURCE = 1
};

int utimecmp (char const *, struct stat const *, struct stat const *, int);

#endif
