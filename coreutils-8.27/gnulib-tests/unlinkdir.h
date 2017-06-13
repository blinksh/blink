/* unlinkdir.h - determine (and maybe change) whether we can unlink directories

   Copyright (C) 2005, 2009-2017 Free Software Foundation, Inc.

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

/* Written by Paul Eggert and Jim Meyering.  */

#include <stdbool.h>

#if UNLINK_CANNOT_UNLINK_DIR
# define cannot_unlink_dir() true
#else
bool cannot_unlink_dir (void);
#endif
