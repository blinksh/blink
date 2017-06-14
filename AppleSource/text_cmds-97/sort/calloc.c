/* calloc() function that is glibc compatible.
   This wrapper function is required at least on Tru64 UNIX 5.1.
   Copyright (C) 2004, 2005 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software Foundation,
   Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.  */

/* written by Jim Meyering */

#ifdef HAVE_CONFIG_H
# include <config.h>
#endif
#undef calloc

#include <stdlib.h>

/* Allocate and zero-fill an NxS-byte block of memory from the heap.
   If N or S is zero, allocate and zero-fill a 1-byte block.  */

void *
rpl_calloc (size_t n, size_t s)
{
  size_t bytes;

  if (n == 0 || s == 0)
    return calloc (1, 1);

  /* Defend against buggy calloc implementations that mishandle
     size_t overflow.  */
  bytes = n * s;
  if (bytes / s != n)
    return NULL;

  return calloc (n, s);
}
