/* Retrieve information about a FILE stream.
   Copyright (C) 2007-2017 Free Software Foundation, Inc.

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

#include <stddef.h>
#include <stdio.h>

/* Assuming the stream STREAM is open for reading:
   Return a pointer to the input buffer of STREAM, or NULL.
   If the returned pointer is non-NULL, *SIZEP is set to the (positive) size
   of the input buffer.
   If the returned pointer is NULL, you should use getc (STREAM),
   fgetc (STREAM), or fread (..., STREAM) to access the input from STREAM.

   The resulting pointer becomes invalid upon any operation on STREAM.

   STREAM must not be wide-character oriented.  */

#if HAVE___FREADPTR /* musl libc */

# include <stdio_ext.h>
# define freadptr(stream,sizep) __freadptr (stream, sizep)

#else

# ifdef __cplusplus
extern "C" {
# endif

extern const char * freadptr (FILE *stream, size_t *sizep);

# ifdef __cplusplus
}
# endif

#endif
