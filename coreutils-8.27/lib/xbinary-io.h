/* Binary mode I/O with checking
   Copyright 2017 Free Software Foundation, Inc.

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

#ifndef _XBINARY_IO_H
#define _XBINARY_IO_H

#include "binary-io.h"

#ifndef _GL_INLINE_HEADER_BEGIN
 #error "Please include config.h first."
#endif
_GL_INLINE_HEADER_BEGIN
#ifndef XBINARY_IO_INLINE
# define XBINARY_IO_INLINE _GL_INLINE
#endif

#if O_BINARY
extern _Noreturn void xset_binary_mode_error (void);
#else
XBINARY_IO_INLINE void xset_binary_mode_error (void) {}
#endif

/* Set the mode of FD to MODE, which should be either O_TEXT or O_BINARY.
   Report an error and exit if this fails.  */

XBINARY_IO_INLINE void
xset_binary_mode (int fd, int mode)
{
  if (set_binary_mode (fd, mode) < 0)
    xset_binary_mode_error ();
}

_GL_INLINE_HEADER_END

#endif /* _XBINARY_IO_H */
