/* dirfd.c -- return the file descriptor associated with an open DIR*

   Copyright (C) 2001, 2006, 2008-2017 Free Software Foundation, Inc.

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

/* Written by Jim Meyering. */

#include "config.h"

#include <dirent.h>
#include <errno.h>

#ifdef __KLIBC__
# include <stdlib.h>
# include <io.h>

static struct dirp_fd_list
{
  DIR *dirp;
  int fd;
  struct dirp_fd_list *next;
} *dirp_fd_start = NULL;

/* Register fd associated with dirp to dirp_fd_list. */
int
_gl_register_dirp_fd (int fd, DIR *dirp)
{
  struct dirp_fd_list *new_dirp_fd = malloc (sizeof *new_dirp_fd);
  if (!new_dirp_fd)
    return -1;

  new_dirp_fd->dirp = dirp;
  new_dirp_fd->fd = fd;
  new_dirp_fd->next = dirp_fd_start;

  dirp_fd_start = new_dirp_fd;

  return 0;
}

/* Unregister fd from dirp_fd_list with closing it */
void
_gl_unregister_dirp_fd (int fd)
{
  struct dirp_fd_list *dirp_fd;
  struct dirp_fd_list *dirp_fd_prev;

  for (dirp_fd_prev = NULL, dirp_fd = dirp_fd_start; dirp_fd;
       dirp_fd_prev = dirp_fd, dirp_fd = dirp_fd->next)
    {
      if (dirp_fd->fd == fd)
        {
          if (dirp_fd_prev)
            dirp_fd_prev->next = dirp_fd->next;
          else  /* dirp_fd == dirp_fd_start */
            dirp_fd_start = dirp_fd_start->next;

          close (fd);
          free (dirp_fd);
          break;
        }
    }
}
#endif

int
dirfd (DIR *dir_p)
{
  int fd = DIR_TO_FD (dir_p);
  if (fd == -1)
#ifndef __KLIBC__
    errno = ENOTSUP;
#else
    {
      struct dirp_fd_list *dirp_fd;

      for (dirp_fd = dirp_fd_start; dirp_fd; dirp_fd = dirp_fd->next)
        if (dirp_fd->dirp == dir_p)
          return dirp_fd->fd;

      errno = EINVAL;
    }
#endif

  return fd;
}
