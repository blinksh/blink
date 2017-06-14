/* __fpending.c -- return the number of pending output bytes on a stream
   Copyright (C) 2000, 2004 Free Software Foundation, Inc.

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

/* Written by Jim Meyering. */

#ifdef HAVE_CONFIG_H
# include <config.h>
#endif

#include "__fpending.h"

/* Return the number of pending (aka buffered, unflushed)
   bytes on the stream, FP, that is open for writing.  */
size_t
__fpending (FILE *fp)
{
  return PENDING_OUTPUT_N_BYTES;
}
