/* getndelim2 - Read a line from a stream, stopping at one of 2 delimiters,
   with bounded memory allocation.

   Copyright (C) 1993, 1996-1998, 2000, 2003-2004, 2006, 2008-2017 Free
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

/* Originally written by Jan Brittenson, bson@gnu.ai.mit.edu.  */

#include "config.h"

#include "getndelim2.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#if USE_UNLOCKED_IO
# include "unlocked-io.h"
#endif
#if !HAVE_FLOCKFILE
# undef flockfile
# define flockfile(x) ((void) 0)
#endif
#if !HAVE_FUNLOCKFILE
# undef funlockfile
# define funlockfile(x) ((void) 0)
#endif

#include <limits.h>
#include <stdint.h>

#include "freadptr.h"
#include "freadseek.h"
#include "memchr2.h"

#ifndef SSIZE_MAX
# define SSIZE_MAX ((ssize_t) (SIZE_MAX / 2))
#endif

/* Use this to suppress gcc's "...may be used before initialized" warnings. */
#if defined GCC_LINT || defined lint
# define IF_LINT(Code) Code
#else
# define IF_LINT(Code) /* empty */
#endif

/* The maximum value that getndelim2 can return without suffering from
   overflow problems, either internally (because of pointer
   subtraction overflow) or due to the API (because of ssize_t).  */
#define GETNDELIM2_MAXIMUM (PTRDIFF_MAX < SSIZE_MAX ? PTRDIFF_MAX : SSIZE_MAX)

/* Try to add at least this many bytes when extending the buffer.
   MIN_CHUNK must be no greater than GETNDELIM2_MAXIMUM.  */
#define MIN_CHUNK 64

ssize_t
getndelim2 (char **lineptr, size_t *linesize, size_t offset, size_t nmax,
            int delim1, int delim2, FILE *stream)
{
  size_t nbytes_avail;          /* Allocated but unused bytes in *LINEPTR.  */
  char *read_pos;               /* Where we're reading into *LINEPTR. */
  ssize_t bytes_stored = -1;
  char *ptr = *lineptr;
  size_t size = *linesize;
  bool found_delimiter;

  if (!ptr)
    {
      size = nmax < MIN_CHUNK ? nmax : MIN_CHUNK;
      ptr = malloc (size);
      if (!ptr)
        return -1;
    }

  if (size < offset)
    goto done;

  nbytes_avail = size - offset;
  read_pos = ptr + offset;

  if (nbytes_avail == 0 && nmax <= size)
    goto done;

  /* Normalize delimiters, since memchr2 doesn't handle EOF.  */
  if (delim1 == EOF)
    delim1 = delim2;
  else if (delim2 == EOF)
    delim2 = delim1;

  flockfile (stream);

  found_delimiter = false;
  do
    {
      /* Here always ptr + size == read_pos + nbytes_avail.
         Also nbytes_avail > 0 || size < nmax.  */

      int c IF_LINT (= 0);
      const char *buffer;
      size_t buffer_len;

      buffer = freadptr (stream, &buffer_len);
      if (buffer)
        {
          if (delim1 != EOF)
            {
              const char *end = memchr2 (buffer, delim1, delim2, buffer_len);
              if (end)
                {
                  buffer_len = end - buffer + 1;
                  found_delimiter = true;
                }
            }
        }
      else
        {
          c = getc (stream);
          if (c == EOF)
            {
              /* Return partial line, if any.  */
              if (read_pos == ptr)
                goto unlock_done;
              else
                break;
            }
          if (c == delim1 || c == delim2)
            found_delimiter = true;
          buffer_len = 1;
        }

      /* We always want at least one byte left in the buffer, since we
         always (unless we get an error while reading the first byte)
         NUL-terminate the line buffer.  */

      if (nbytes_avail < buffer_len + 1 && size < nmax)
        {
          /* Grow size proportionally, not linearly, to avoid O(n^2)
             running time.  */
          size_t newsize = size < MIN_CHUNK ? size + MIN_CHUNK : 2 * size;
          char *newptr;

          /* Increase newsize so that it becomes
             >= (read_pos - ptr) + buffer_len.  */
          if (newsize - (read_pos - ptr) < buffer_len + 1)
            newsize = (read_pos - ptr) + buffer_len + 1;
          /* Respect nmax.  This handles possible integer overflow.  */
          if (! (size < newsize && newsize <= nmax))
            newsize = nmax;

          if (GETNDELIM2_MAXIMUM < newsize - offset)
            {
              size_t newsizemax = offset + GETNDELIM2_MAXIMUM + 1;
              if (size == newsizemax)
                goto unlock_done;
              newsize = newsizemax;
            }

          nbytes_avail = newsize - (read_pos - ptr);
          newptr = realloc (ptr, newsize);
          if (!newptr)
            goto unlock_done;
          ptr = newptr;
          size = newsize;
          read_pos = size - nbytes_avail + ptr;
        }

      /* Here, if size < nmax, nbytes_avail >= buffer_len + 1.
         If size == nmax, nbytes_avail > 0.  */

      if (1 < nbytes_avail)
        {
          size_t copy_len = nbytes_avail - 1;
          if (buffer_len < copy_len)
            copy_len = buffer_len;
          if (buffer)
            memcpy (read_pos, buffer, copy_len);
          else
            *read_pos = c;
          read_pos += copy_len;
          nbytes_avail -= copy_len;
        }

      /* Here still nbytes_avail > 0.  */

      if (buffer && freadseek (stream, buffer_len))
        goto unlock_done;
    }
  while (!found_delimiter);

  /* Done - NUL terminate and return the number of bytes read.
     At this point we know that nbytes_avail >= 1.  */
  *read_pos = '\0';

  bytes_stored = read_pos - (ptr + offset);

 unlock_done:
  funlockfile (stream);

 done:
  *lineptr = ptr;
  *linesize = size;
  return bytes_stored ? bytes_stored : -1;
}
