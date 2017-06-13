/* Save the list of files in a directory in a string.

   Copyright (C) 1997, 1999, 2001, 2003, 2005, 2009-2017 Free Software
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

/* Written by David MacKenzie <djm@gnu.ai.mit.edu>. */

#ifndef _GL_SAVEDIR_H
#define _GL_SAVEDIR_H

#include <dirent.h>

enum savedir_option
  {
    SAVEDIR_SORT_NONE,
    SAVEDIR_SORT_NAME,
#if D_INO_IN_DIRENT
    SAVEDIR_SORT_INODE,
    SAVEDIR_SORT_FASTREAD = SAVEDIR_SORT_INODE
#else
    SAVEDIR_SORT_FASTREAD = SAVEDIR_SORT_NONE
#endif
  };

char *streamsavedir (DIR *, enum savedir_option);
char *savedir (char const *, enum savedir_option);

#endif
