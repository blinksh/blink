/* Test whether a file descriptor is a pipe.

   Copyright (C) 2006, 2008-2017 Free Software Foundation, Inc.

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

/* Written by Paul Eggert.  */

#include "config.h"

#include "isapipe.h"

#include <errno.h>

#if (defined _WIN32 || defined __WIN32__) && ! defined __CYGWIN__
/* Windows platforms.  */

/* Get GetFileType.  */
# include <windows.h>

/* Get _get_osfhandle.  */
# include "msvc-nothrow.h"

int
isapipe (int fd)
{
  HANDLE h = (HANDLE) _get_osfhandle (fd);

  if (h == INVALID_HANDLE_VALUE)
    {
      errno = EBADF;
      return -1;
    }

  return (GetFileType (h) == FILE_TYPE_PIPE);
}

#else
/* Unix platforms.  */

# include <stdbool.h>
# include <sys/types.h>
# include <sys/stat.h>
# include <unistd.h>

/* The maximum link count for pipes; (nlink_t) -1 if not known.  */
# ifndef PIPE_LINK_COUNT_MAX
#  define PIPE_LINK_COUNT_MAX ((nlink_t) (-1))
# endif

/* Return 1 if FD is a pipe, 0 if not, -1 (setting errno) on error.

   Test fairly strictly whether FD is a pipe.  lseek and checking for
   ESPIPE does not suffice, since many non-pipe files cause lseek to
   fail with errno == ESPIPE.  */

int
isapipe (int fd)
{
  nlink_t pipe_link_count_max = PIPE_LINK_COUNT_MAX;
  bool check_for_fifo = (HAVE_FIFO_PIPES == 1);
  struct stat st;
  int fstat_result = fstat (fd, &st);

  if (fstat_result != 0)
    return fstat_result;

  /* We want something that succeeds only for pipes, but on
     POSIX-conforming hosts S_ISFIFO succeeds for both FIFOs and pipes
     and we know of no portable, reliable way to distinguish them in
     general.  However, in practice pipes always have a link count <=
     PIPE_LINK_COUNT_MAX (unless someone attaches them to the file
     system name space using fattach, in which case they're not really
     pipes any more), so test for that as well.

     On Darwin 7.7, pipes are sockets, so check for those instead.  */

  if (! ((HAVE_FIFO_PIPES == 0 || HAVE_FIFO_PIPES == 1)
         && PIPE_LINK_COUNT_MAX != (nlink_t) -1)
      && (S_ISFIFO (st.st_mode) | S_ISSOCK (st.st_mode)))
    {
      int fd_pair[2];
      int pipe_result = pipe (fd_pair);
      if (pipe_result != 0)
        return pipe_result;
      else
        {
          struct stat pipe_st;
          int fstat_pipe_result = fstat (fd_pair[0], &pipe_st);
          int fstat_pipe_errno = errno;
          close (fd_pair[0]);
          close (fd_pair[1]);
          if (fstat_pipe_result != 0)
            {
              errno = fstat_pipe_errno;
              return fstat_pipe_result;
            }
          check_for_fifo = (S_ISFIFO (pipe_st.st_mode) != 0);
          pipe_link_count_max = pipe_st.st_nlink;
        }
    }

  return
    (st.st_nlink <= pipe_link_count_max
     && (check_for_fifo ? S_ISFIFO (st.st_mode) : S_ISSOCK (st.st_mode)));
}

#endif
