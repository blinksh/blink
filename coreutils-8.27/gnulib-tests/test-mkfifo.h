/* Tests of mkfifo and friends.
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

/* Written by Eric Blake <ebb9@byu.net>, 2009.  */

/* This file is designed to test mkfifo(n,m), mknod(n,m|S_IFIFO,0),
   mkfifoat(AT_FDCWD,n,m), and mknodat(AT_FDCWD,n,m|S_IFIFO,0).  FUNC
   is the function to test.  Assumes that BASE and ASSERT are already
   defined, and that appropriate headers are already included.  If
   PRINT, warn before skipping symlink tests with status 77.  */

static int
test_mkfifo (int (*func) (char const *, mode_t), bool print)
{
  int result = func (BASE "fifo", 0600);
  struct stat st;
  if (result == -1 && errno == ENOSYS)
    {
      if (print)
        fputs ("skipping test: no support for named fifos\n", stderr);
      return 77;
    }
  ASSERT (result == 0);
  ASSERT (stat (BASE "fifo", &st) == 0);
  ASSERT (S_ISFIFO (st.st_mode));

  /* Sanity checks of failures.  */
  errno = 0;
  ASSERT (func ("", S_IRUSR | S_IWUSR) == -1);
  ASSERT (errno == ENOENT);
  errno = 0;
  ASSERT (func (".", 0600) == -1);
  /* Allow HP-UX 11.11's EISDIR, even though POSIX says it's wrong,
     since it doesn't really hurt anything and we lack the energy to
     fix it.  */
  ASSERT (errno == EEXIST || errno == EINVAL || errno == EISDIR);
  errno = 0;
  ASSERT (func (BASE "fifo", 0600) == -1);
  ASSERT (errno == EEXIST);
  ASSERT (unlink (BASE "fifo") == 0);
  errno = 0;
  ASSERT (func (BASE "fifo/", 0600) == -1);
  ASSERT (errno == ENOENT || errno == ENOTDIR);

  /* Test trailing slash behavior.  */
  if (symlink (BASE "fifo", BASE "link"))
    {
      if (print)
        fputs ("skipping test: symlinks not supported on this file system\n",
               stderr);
      return 77;
    }
  errno = 0;
  ASSERT (func (BASE "link", 0600) == -1);
  ASSERT (errno == EEXIST);
  errno = 0;
  ASSERT (func (BASE "link/", 0600) == -1);
  ASSERT (errno == EEXIST || errno == ENOENT || errno == ENOTDIR);
  errno = 0;
  ASSERT (unlink (BASE "fifo") == -1);
  ASSERT (errno == ENOENT);
  ASSERT (unlink (BASE "link") == 0);
  return 0;
}
