/* An interface to write() that writes all it is asked to write.

   Copyright (C) 2002-2003, 2009-2017 Free Software Foundation, Inc.

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


#ifdef __cplusplus
extern "C" {
#endif


/* Write COUNT bytes at BUF to descriptor FD, retrying if interrupted
   or if partial writes occur.  Return the number of bytes successfully
   written, setting errno if that is less than COUNT.  */
extern size_t full_write (int fd, const void *buf, size_t count);


#ifdef __cplusplus
}
#endif
