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

#include "config.h"

/* Specification.  */
#include "freadseek.h"

#include <stdlib.h>
#include <unistd.h>

#include "freadahead.h"
#include "freadptr.h"

#include "stdio-impl.h"

/* Increment the in-memory pointer.  INCREMENT must be at most the buffer size
   returned by freadptr().
   This is very cheap (no system calls).  */
static void
freadptrinc (FILE *fp, size_t increment)
{
  /* Keep this code in sync with freadptr!  */
#if HAVE___FREADPTRINC              /* musl libc */
  __freadptrinc (fp, increment);
#elif defined _IO_ftrylockfile || __GNU_LIBRARY__ == 1 /* GNU libc, BeOS, Haiku, Linux libc5 */
  fp->_IO_read_ptr += increment;
#elif defined __sferror || defined __DragonFly__ || defined __ANDROID__
  /* FreeBSD, NetBSD, OpenBSD, DragonFly, Mac OS X, Cygwin, Minix 3, Android */
  fp_->_p += increment;
  fp_->_r -= increment;
#elif defined __EMX__               /* emx+gcc */
  fp->_ptr += increment;
  fp->_rcount -= increment;
#elif defined __minix               /* Minix */
  fp_->_ptr += increment;
  fp_->_count -= increment;
#elif defined _IOERR                /* AIX, HP-UX, IRIX, OSF/1, Solaris, OpenServer, mingw, MSVC, NonStop Kernel */
  fp_->_ptr += increment;
  fp_->_cnt -= increment;
#elif defined __UCLIBC__            /* uClibc */
# ifdef __STDIO_BUFFERS
  fp->__bufpos += increment;
# else
  abort ();
# endif
#elif defined __QNX__               /* QNX */
  fp->_Next += increment;
#elif defined __MINT__              /* Atari FreeMiNT */
  fp->__bufp += increment;
#elif defined EPLAN9                /* Plan9 */
  fp->rp += increment;
#elif defined SLOW_BUT_NO_HACKS     /* users can define this */
#else
 #error "Please port gnulib freadseek.c to your platform! Look at the definition of getc, getc_unlocked on your system, then report this to bug-gnulib."
#endif
}

int
freadseek (FILE *fp, size_t offset)
{
  size_t total_buffered;
  int fd;

  if (offset == 0)
    return 0;

  /* Seek over the already read and buffered input as quickly as possible,
     without doing any system calls.  */
  total_buffered = freadahead (fp);
  /* This loop is usually executed at most twice: once for ungetc buffer (if
     present) and once for the main buffer.  */
  while (total_buffered > 0)
    {
      size_t buffered;

      if (freadptr (fp, &buffered) != NULL && buffered > 0)
        {
          size_t increment = (buffered < offset ? buffered : offset);

          freadptrinc (fp, increment);
          offset -= increment;
          if (offset == 0)
            return 0;
          total_buffered -= increment;
          if (total_buffered == 0)
            break;
        }
      /* Read one byte.  If we were reading from the ungetc buffer, this
         switches the stream back to the main buffer.  */
      if (fgetc (fp) == EOF)
        goto eof;
      offset--;
      if (offset == 0)
        return 0;
      total_buffered--;
    }

  /* Test whether the stream is seekable or not.  */
  fd = fileno (fp);
  if (fd >= 0 && lseek (fd, 0, SEEK_CUR) >= 0)
    {
      /* FP refers to a regular file.  fseek is most efficient in this case.  */
      return fseeko (fp, offset, SEEK_CUR);
    }
  else
    {
      /* FP is a non-seekable stream, possibly not even referring to a file
         descriptor.  Read OFFSET bytes explicitly and discard them.  */
      char buf[4096];

      do
        {
          size_t count = (sizeof (buf) < offset ? sizeof (buf) : offset);
          if (fread (buf, 1, count, fp) < count)
            goto eof;
          offset -= count;
        }
      while (offset > 0);

      return 0;
   }

 eof:
  /* EOF, or error before or while reading.  */
  if (ferror (fp))
    return EOF;
  else
    /* Encountered EOF.  */
    return 0;
}
