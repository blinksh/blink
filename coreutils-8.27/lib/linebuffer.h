/* linebuffer.h -- declarations for reading arbitrarily long lines

   Copyright (C) 1986, 1991, 1998-1999, 2002-2003, 2007, 2009-2017 Free
   Software Foundation, Inc.

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

#if !defined LINEBUFFER_H
# define LINEBUFFER_H

# include <stdio.h>

/* A 'struct linebuffer' holds a line of text. */

struct linebuffer
{
  size_t size;                  /* Allocated. */
  size_t length;                /* Used. */
  char *buffer;
};

/* Initialize linebuffer LINEBUFFER for use. */
void initbuffer (struct linebuffer *linebuffer);

/* Read an arbitrarily long line of text from STREAM into LINEBUFFER.
   Consider lines to be terminated by DELIMITER.
   Keep the delimiter; append DELIMITER if we reach EOF and it wasn't
   the last character in the file.  Do not NUL-terminate.
   Return LINEBUFFER, except at end of file return NULL.  */
struct linebuffer *readlinebuffer_delim (struct linebuffer *linebuffer,
                                         FILE *stream, char delimiter);

/* Read an arbitrarily long line of text from STREAM into LINEBUFFER.
   Keep the newline; append a newline if it's the last line of a file
   that ends in a non-newline character.  Do not NUL-terminate.
   Return LINEBUFFER, except at end of file return NULL.  */
struct linebuffer *readlinebuffer (struct linebuffer *linebuffer, FILE *stream);

/* Free linebuffer LINEBUFFER and its data, all allocated with malloc. */
void freebuffer (struct linebuffer *);

#endif /* LINEBUFFER_H */
