/* Test of link() function.
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

/* This file is designed to test both link(a,b) and
   linkat(AT_FDCWD,a,AT_FDCWD,b,0).  FUNC is the function to test.
   Assumes that BASE and ASSERT are already defined, and that
   appropriate headers are already included.  If PRINT, warn before
   skipping tests with status 77.  This test does not try to create
   hard links to symlinks, but does test other aspects of symlink.  */

static int
test_link (int (*func) (char const *, char const *), bool print)
{
  int fd;
  int ret;

  /* Create first file.  */
  fd = open (BASE "a", O_CREAT | O_EXCL | O_WRONLY, 0600);
  ASSERT (0 <= fd);
  ASSERT (write (fd, "hello", 5) == 5);
  ASSERT (close (fd) == 0);

  /* Not all file systems support link.  Mingw doesn't have reliable
     st_nlink on hard links, but our implementation does fail with
     EPERM on poor file systems, and we can detect the inferior stat()
     via st_ino.  Cygwin 1.5.x copies rather than links files on those
     file systems, but there, st_nlink and st_ino are reliable.  */
  ret = func (BASE "a", BASE "b");
  if (!ret)
  {
    struct stat st;
    ASSERT (stat (BASE "b", &st) == 0);
    if (st.st_ino && st.st_nlink != 2)
      {
        ASSERT (unlink (BASE "b") == 0);
        errno = EPERM;
        ret = -1;
      }
  }
  if (ret == -1)
    {
      /* If the device does not support hard links, errno is
         EPERM on Linux, EOPNOTSUPP on FreeBSD.  */
      switch (errno)
        {
        case EPERM:
        case EOPNOTSUPP:
          if (print)
            fputs ("skipping test: "
                   "hard links not supported on this file system\n",
                   stderr);
          ASSERT (unlink (BASE "a") == 0);
          return 77;
        default:
          perror ("link");
          return 1;
        }
    }
  ASSERT (ret == 0);

  /* Now, for some behavior tests.  Modify the contents of 'b', and
     ensure that 'a' can see it, both while 'b' exists and after.  */
  fd = open (BASE "b", O_APPEND | O_WRONLY);
  ASSERT (0 <= fd);
  ASSERT (write (fd, "world", 5) == 5);
  ASSERT (close (fd) == 0);
  {
    char buf[11] = { 0 };
    fd = open (BASE "a", O_RDONLY);
    ASSERT (0 <= fd);
    ASSERT (read (fd, buf, 10) == 10);
    ASSERT (strcmp (buf, "helloworld") == 0);
    ASSERT (close (fd) == 0);
    ASSERT (unlink (BASE "b") == 0);
    fd = open (BASE "a", O_RDONLY);
    ASSERT (0 <= fd);
    ASSERT (read (fd, buf, 10) == 10);
    ASSERT (strcmp (buf, "helloworld") == 0);
    ASSERT (close (fd) == 0);
  }

  /* Test for various error conditions.  */
  ASSERT (mkdir (BASE "d", 0700) == 0);
  errno = 0;
  ASSERT (func (BASE "a", ".") == -1);
  ASSERT (errno == EEXIST || errno == EINVAL);
  errno = 0;
  ASSERT (func (BASE "a", BASE "a") == -1);
  ASSERT (errno == EEXIST);
  ASSERT (func (BASE "a", BASE "b") == 0);
  errno = 0;
  ASSERT (func (BASE "a", BASE "b") == -1);
  ASSERT (errno == EEXIST);
  errno = 0;
  ASSERT (func (BASE "a", BASE "d") == -1);
  ASSERT (errno == EEXIST);
  errno = 0;
  ASSERT (func (BASE "c", BASE "e") == -1);
  ASSERT (errno == ENOENT);
  errno = 0;
  ASSERT (func (BASE "a", BASE "c/.") == -1);
  ASSERT (errno == ENOENT);
  errno = 0;
  ASSERT (func (BASE "a/", BASE "c") == -1);
  ASSERT (errno == ENOTDIR || errno == EINVAL);
  errno = 0;
  ASSERT (func (BASE "a", BASE "c/") == -1);
  ASSERT (errno == ENOTDIR || errno == ENOENT || errno == EINVAL);

  /* Most platforms reject hard links to directories, and even on
     those that do permit it, most users can't create them.  We assume
     that if this test is run as root and we managed to create a hard
     link, then unlink better be able to clean it up.  */
  {
    int result;
    errno = 0;
    result = func (BASE "d", BASE "c");
    if (result == 0)
      {
        /* Probably root on Solaris.  */
        ASSERT (unlink (BASE "c") == 0);
      }
    else
      {
        /* Most everyone else.  */
        ASSERT (errno == EPERM || errno == EACCES || errno == EISDIR);
        errno = 0;
        ASSERT (func (BASE "d/.", BASE "c") == -1);
        ASSERT (errno == EPERM || errno == EACCES || errno == EISDIR
                || errno == EINVAL);
        errno = 0;
        ASSERT (func (BASE "d/.//", BASE "c") == -1);
        ASSERT (errno == EPERM || errno == EACCES || errno == EISDIR
                || errno == EINVAL);
      }
  }
  ASSERT (unlink (BASE "a") == 0);
  errno = 0;
  ASSERT (unlink (BASE "c") == -1);
  ASSERT (errno == ENOENT);
  ASSERT (rmdir (BASE "d") == 0);

  /* Test invalid use of symlink.  */
  if (symlink (BASE "a", BASE "link") != 0)
    {
      ASSERT (unlink (BASE "b") == 0);
      if (print)
        fputs ("skipping test: symlinks not supported on this file system\n",
               stderr);
      return 77;
    }
  errno = 0;
  ASSERT (func (BASE "b", BASE "link/") == -1);
  ASSERT (errno == ENOTDIR || errno == ENOENT || errno == EEXIST
          || errno == EINVAL);
  errno = 0;
  ASSERT (func (BASE "b", BASE "link") == -1);
  ASSERT (errno == EEXIST);
  ASSERT (rename (BASE "b", BASE "a") == 0);
  errno = 0;
  ASSERT (func (BASE "link/", BASE "b") == -1);
  ASSERT (errno == ENOTDIR || errno == EEXIST || errno == EINVAL);

  /* Clean up.  */
  ASSERT (unlink (BASE "a") == 0);
  ASSERT (unlink (BASE "link") == 0);

  return 0;
}
