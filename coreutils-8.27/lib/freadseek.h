/* Skipping input from a FILE stream.
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

#ifdef __cplusplus
extern "C" {
#endif

/* Assuming the stream STREAM is open for reading:

   Read and discard OFFSET bytes from STREAM.

   freadseek (STREAM, OFFSET) is the same as
   fseek (STREAM, OFFSET, SEEK_CUR), except that the latter does not work
   on non-seekable input streams (such as pipes).

   Upon success, return 0.
   Upon premature end of stream, return 0 (like fseek does).
   Upon error, set the error indicator in the stream and return EOF.

   STREAM must not be wide-character oriented.  */

extern int freadseek (FILE *stream, size_t offset);

#ifdef __cplusplus
}
#endif
