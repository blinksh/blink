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

#include "config.h"

/* Specification.  */
#include "freadptr.h"

#include <stdlib.h>

#include "stdio-impl.h"

const char *
freadptr (FILE *fp, size_t *sizep)
{
  size_t size;

  /* Keep this code in sync with freadahead!  */
#if defined _IO_ftrylockfile || __GNU_LIBRARY__ == 1 /* GNU libc, BeOS, Haiku, Linux libc5 */
  if (fp->_IO_write_ptr > fp->_IO_write_base)
    return NULL;
  size = fp->_IO_read_end - fp->_IO_read_ptr;
  if (size == 0)
    return NULL;
  *sizep = size;
  return (const char *) fp->_IO_read_ptr;
#elif defined __sferror || defined __DragonFly__ || defined __ANDROID__
  /* FreeBSD, NetBSD, OpenBSD, DragonFly, Mac OS X, Cygwin, Minix 3, Android */
  if ((fp_->_flags & __SWR) != 0 || fp_->_r < 0)
    return NULL;
  size = fp_->_r;
  if (size == 0)
    return NULL;
  *sizep = size;
  return (const char *) fp_->_p;
#elif defined __EMX__               /* emx+gcc */
  if ((fp->_flags & _IOWRT) != 0)
    return NULL;
  /* Note: fp->_ungetc_count > 0 implies fp->_rcount <= 0,
           fp->_ungetc_count = 0 implies fp->_rcount >= 0.  */
  if (fp->_rcount <= 0)
    return NULL;
  if (!(fp->_ungetc_count == 0))
    abort ();
  *sizep = fp->_rcount;
  return fp->_ptr;
#elif defined __minix               /* Minix */
  if ((fp_->_flags & _IOWRITING) != 0)
    return NULL;
  size = fp_->_count;
  if (size == 0)
    return NULL;
  *sizep = size;
  return (const char *) fp_->_ptr;
#elif defined _IOERR                /* AIX, HP-UX, IRIX, OSF/1, Solaris, OpenServer, mingw, MSVC, NonStop Kernel */
  if ((fp_->_flag & _IOWRT) != 0)
    return NULL;
  size = fp_->_cnt;
  if (size == 0)
    return NULL;
  *sizep = size;
  return (const char *) fp_->_ptr;
#elif defined __UCLIBC__            /* uClibc */
# ifdef __STDIO_BUFFERS
  if (fp->__modeflags & __FLAG_WRITING)
    return NULL;
  if (fp->__modeflags & __FLAG_UNGOT)
    return NULL;
  size = fp->__bufread - fp->__bufpos;
  if (size == 0)
    return NULL;
  *sizep = size;
  return (const char *) fp->__bufpos;
# else
  return NULL;
# endif
#elif defined __QNX__               /* QNX */
  if ((fp->_Mode & 0x2000 /* _MWRITE */) != 0)
    return NULL;
  /* fp->_Buf <= fp->_Next <= fp->_Rend */
  size = fp->_Rend - fp->_Next;
  if (size == 0)
    return NULL;
  *sizep = size;
  return (const char *) fp->_Next;
#elif defined __MINT__              /* Atari FreeMiNT */
  if (!fp->__mode.__read)
    return NULL;
  size = fp->__get_limit - fp->__bufp;
  if (size == 0)
    return NULL;
  *sizep = size;
  return fp->__bufp;
#elif defined EPLAN9                /* Plan9 */
  if (fp->state == 4 /* WR */)
    return NULL;
  if (fp->rp >= fp->wp)
    return NULL;
  *sizep = fp->wp - fp->rp;
  return fp->rp;
#elif defined SLOW_BUT_NO_HACKS     /* users can define this */
  /* This implementation is correct on any ANSI C platform.  It is just
     awfully slow.  */
  return NULL;
#else
 #error "Please port gnulib freadptr.c to your platform! Look at the definition of fflush, fread, getc, getc_unlocked on your system, then report this to bug-gnulib."
#endif
}
