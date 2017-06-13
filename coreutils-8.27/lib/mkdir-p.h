/* mkdir-p.h -- Ensure that a directory and its parents exist.

   Copyright (C) 1994-1997, 2000, 2003-2006, 2009-2017 Free Software
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

/* Written by Paul Eggert, David MacKenzie, and Jim Meyering.  */

#include <stdbool.h>
#include <sys/types.h>

struct savewd;
bool make_dir_parents (char *dir,
                       struct savewd *wd,
                       int (*make_ancestor) (char const *, char const *,
                                             void *),
                       void *options,
                       mode_t mode,
                       void (*announce) (char const *, void *),
                       mode_t mode_bits,
                       uid_t owner,
                       gid_t group,
                       bool preserve_existing);
