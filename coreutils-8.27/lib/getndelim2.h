/* getndelim2 - Read a line from a stream, stopping at one of 2 delimiters,
   with bounded memory allocation.

   Copyright (C) 2003-2004, 2006, 2009-2017 Free Software Foundation, Inc.

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

#ifndef GETNDELIM2_H
#define GETNDELIM2_H 1

#include <stdio.h>
#include <sys/types.h>

#define GETNLINE_NO_LIMIT ((size_t) -1)

/* Read into a buffer *LINEPTR returned from malloc (or NULL),
   pointing to *LINESIZE bytes of space.  Store the input bytes
   starting at *LINEPTR + OFFSET, and null-terminate them.  Reallocate
   the buffer as necessary, but if NMAX is not GETNLINE_NO_LIMIT
   then do not allocate more than NMAX bytes; if the line is longer
   than that, read and discard the extra bytes.  Stop reading after
   the first occurrence of DELIM1 or DELIM2, whichever comes first;
   a delimiter equal to EOF stands for no delimiter.  Read the
   input bytes from STREAM.
   Return the number of bytes read and stored at *LINEPTR + OFFSET (not
   including the NUL terminator), or -1 on error or EOF.  */
extern ssize_t getndelim2 (char **lineptr, size_t *linesize, size_t offset,
                           size_t nmax, int delim1, int delim2,
                           FILE *stream);

#endif /* GETNDELIM2_H */
