/* getpagesize emulation for systems where it cannot be done in a C macro.

   Copyright (C) 2007, 2009-2017 Free Software Foundation, Inc.

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

/* Written by Bruno Haible and Martin Lambers.  */

#include "config.h"

/* Specification. */
#include <unistd.h>

/* This implementation is only for native Windows systems.  */
#if (defined _WIN32 || defined __WIN32__) && ! defined __CYGWIN__

# define WIN32_LEAN_AND_MEAN
# include <windows.h>

int
getpagesize (void)
{
  SYSTEM_INFO system_info;
  GetSystemInfo (&system_info);
  return system_info.dwPageSize;
}

#endif
