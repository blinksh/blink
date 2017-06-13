/* libstdbuf -- a shared lib to preload to setup stdio buffering for a command
   Copyright (C) 2009-2017 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* Written by Pádraig Brady.  LD_PRELOAD idea from Brian Dessent.  */

#include <config.h>
#include <stdio.h>
#include "system.h"

/* Deactivate config.h's "rpl_"-prefixed definition of malloc,
   since we don't link gnulib here, and the replacement isn't
   needed in this case as we don't malloc(0).  */
#undef malloc

/* Note currently for glibc (2.3.5) the following call does not change
   the buffer size, and more problematically does not give any indication
   that the new size request was ignored:

       setvbuf (stdout, (char*)NULL, _IOFBF, 8192);

   The ISO C99 standard section 7.19.5.6 on the setvbuf function says:

   ... If buf is not a null pointer, the array it points to _may_ be used
   instead of a buffer allocated by the setvbuf function and the argument
   size specifies the size of the array; otherwise, size _may_ determine
   the size of a buffer allocated by the setvbuf function. ...

   Obviously some interpret the above to mean setvbuf(....,size)
   is only a hint from the application which I don't agree with.

   FreeBSD's libc seems more sensible in this regard. From the man page:

   The size argument may be given as zero to obtain deferred optimal-size
   buffer allocation as usual.  If it is not zero, then except for
   unbuffered files, the buf argument should point to a buffer at least size
   bytes long; this buffer will be used instead of the current buffer.  (If
   the size argument is not zero but buf is NULL, a buffer of the given size
   will be allocated immediately, and released on close.  This is an extension
   to ANSI C; portable code should use a size of 0 with any NULL buffer.)
   --------------------
   Another issue is that on glibc-2.7 the following doesn't buffer
   the first write if it's greater than 1 byte.

       setvbuf(stdout,buf,_IOFBF,127);

   Now the POSIX standard says that "allocating a buffer of size bytes does
   not necessarily imply that all of size bytes are used for the buffer area".
   However I think it's just a buggy implementation due to the various
   inconsistencies with write sizes and subsequent writes.  */

static const char *
fileno_to_name (const int fd)
{
  const char *ret = NULL;

  switch (fd)
    {
    case 0:
      ret = "stdin";
      break;
    case 1:
      ret = "stdout";
      break;
    case 2:
      ret = "stderr";
      break;
    default:
      ret = "unknown";
      break;
    }

  return ret;
}

static void
apply_mode (FILE *stream, const char *mode)
{
  char *buf = NULL;
  int setvbuf_mode;
  size_t size = 0;

  if (*mode == '0')
    setvbuf_mode = _IONBF;
  else if (*mode == 'L')
    setvbuf_mode = _IOLBF;      /* FIXME: should we allow 1ML  */
  else
    {
      setvbuf_mode = _IOFBF;
      verify (SIZE_MAX <= ULONG_MAX);
      size = strtoul (mode, NULL, 10);
      if (size > 0)
        {
          if (!(buf = malloc (size)))   /* will be freed by fclose()  */
            {
              /* We could defer the allocation to libc, however since
                 glibc currently ignores the combination of NULL buffer
                 with non zero size, we'll fail here.  */
              fprintf (stderr,
                       _("failed to allocate a %" PRIuMAX
                         " byte stdio buffer\n"), (uintmax_t) size);
              return;
            }
        }
      else
        {
          fprintf (stderr, _("invalid buffering mode %s for %s\n"),
                   mode, fileno_to_name (fileno (stream)));
          return;
        }
    }

  if (setvbuf (stream, buf, setvbuf_mode, size) != 0)
    {
      fprintf (stderr, _("could not set buffering of %s to mode %s\n"),
               fileno_to_name (fileno (stream)), mode);
      free (buf);
    }
}

/* Use __attribute to avoid elision of __attribute__ on SUNPRO_C etc.  */
static void __attribute ((constructor))
stdbuf (void)
{
  char *e_mode = getenv ("_STDBUF_E");
  char *i_mode = getenv ("_STDBUF_I");
  char *o_mode = getenv ("_STDBUF_O");
  if (e_mode) /* Do first so can write errors to stderr  */
    apply_mode (stderr, e_mode);
  if (i_mode)
    apply_mode (stdin, i_mode);
  if (o_mode)
    apply_mode (stdout, o_mode);
}
