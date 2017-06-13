/* linebuffer.c -- read arbitrarily long lines

   Copyright (C) 1986, 1991, 1998-1999, 2001, 2003-2004, 2006-2007, 2009-2017
   Free Software Foundation, Inc.

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

/* Written by Richard Stallman. */

#include "config.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include "linebuffer.h"
#include "xalloc.h"

#if USE_UNLOCKED_IO
# include "unlocked-io.h"
#endif

/* Initialize linebuffer LINEBUFFER for use. */

void
initbuffer (struct linebuffer *linebuffer)
{
  memset (linebuffer, 0, sizeof *linebuffer);
}

struct linebuffer *
readlinebuffer (struct linebuffer *linebuffer, FILE *stream)
{
  return readlinebuffer_delim (linebuffer, stream, '\n');
}

/* Read an arbitrarily long line of text from STREAM into LINEBUFFER.
   Consider lines to be terminated by DELIMITER.
   Keep the delimiter; append DELIMITER if it's the last line of a file
   that ends in a character other than DELIMITER.  Do not NUL-terminate.
   Therefore the stream can contain NUL bytes, and the length
   (including the delimiter) is returned in linebuffer->length.
   Return NULL when stream is empty.  Return NULL and set errno upon
   error; callers can distinguish this case from the empty case by
   invoking ferror (stream).
   Otherwise, return LINEBUFFER.  */
struct linebuffer *
readlinebuffer_delim (struct linebuffer *linebuffer, FILE *stream,
                      char delimiter)
{
  int c;
  char *buffer = linebuffer->buffer;
  char *p = linebuffer->buffer;
  char *end = buffer + linebuffer->size; /* Sentinel. */

  if (feof (stream))
    return NULL;

  do
    {
      c = getc (stream);
      if (c == EOF)
        {
          if (p == buffer || ferror (stream))
            return NULL;
          if (p[-1] == delimiter)
            break;
          c = delimiter;
        }
      if (p == end)
        {
          size_t oldsize = linebuffer->size;
          buffer = x2realloc (buffer, &linebuffer->size);
          p = buffer + oldsize;
          linebuffer->buffer = buffer;
          end = buffer + linebuffer->size;
        }
      *p++ = c;
    }
  while (c != delimiter);

  linebuffer->length = p - buffer;
  return linebuffer;
}

/* Free the buffer that was allocated for linebuffer LINEBUFFER.  */

void
freebuffer (struct linebuffer *linebuffer)
{
  free (linebuffer->buffer);
}
