/* Invoke freopen, but avoid some glitches.

   Copyright (C) 2009-2017 Free Software Foundation, Inc.

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

/* Written by Eric Blake.  */

#include "config.h"

#include "stdio-safer.h"

#include <errno.h>
#include <fcntl.h>
#include <stdbool.h>
#include <unistd.h>

/* Guarantee that FD is open; all smaller FDs must already be open.
   Return true if successful.  */
static bool
protect_fd (int fd)
{
  int value = open ("/dev/null", O_RDONLY);
  if (value != fd)
    {
      if (0 <= value)
        {
          close (value);
          errno = EBADF; /* Unexpected; this is as good as anything else.  */
        }
      return false;
    }
  return true;
}

/* Like freopen, but guarantee that reopening stdin, stdout, or stderr
   preserves the invariant that STDxxx_FILENO==fileno(stdxxx), and
   that no other stream will interfere with the standard streams.
   This is necessary because most freopen implementations will change
   the associated fd of a stream to the lowest available slot.  */

FILE *
freopen_safer (char const *name, char const *mode, FILE *f)
{
  /* Unfortunately, we cannot use the fopen_safer approach of using
     fdopen (dup_safer (fileno (freopen (cmd, mode, f)))), because we
     need to return f itself.  The implementation of freopen(NULL,m,f)
     is system-dependent, so the best we can do is guarantee that all
     lower-valued standard fds are open prior to the freopen call,
     even though this puts more pressure on open fds.  */
  bool protect_in = false;
  bool protect_out = false;
  bool protect_err = false;
  int saved_errno;

  switch (fileno (f))
    {
    default: /* -1 or not a standard stream.  */
      if (dup2 (STDERR_FILENO, STDERR_FILENO) != STDERR_FILENO)
        protect_err = true;
      /* fall through */
    case STDERR_FILENO:
      if (dup2 (STDOUT_FILENO, STDOUT_FILENO) != STDOUT_FILENO)
        protect_out = true;
      /* fall through */
    case STDOUT_FILENO:
      if (dup2 (STDIN_FILENO, STDIN_FILENO) != STDIN_FILENO)
        protect_in = true;
      /* fall through */
    case STDIN_FILENO:
      /* Nothing left to protect.  */
      break;
    }
  if (protect_in && !protect_fd (STDIN_FILENO))
    f = NULL;
  else if (protect_out && !protect_fd (STDOUT_FILENO))
    f = NULL;
  else if (protect_err && !protect_fd (STDERR_FILENO))
    f = NULL;
  else
    f = freopen (name, mode, f);
  saved_errno = errno;
  if (protect_err)
    close (STDERR_FILENO);
  if (protect_out)
    close (STDOUT_FILENO);
  if (protect_in)
    close (STDIN_FILENO);
  if (!f)
    errno = saved_errno;
  return f;
}
