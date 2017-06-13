/* Tests of linkat.
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

#include <config.h>

#include <unistd.h>

#include "signature.h"
SIGNATURE_CHECK (linkat, int, (int, char const *, int, char const *, int));

#include <fcntl.h>
#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#include "areadlink.h"
#include "filenamecat.h"
#include "same-inode.h"
#include "ignore-value.h"
#include "macros.h"

#define BASE "test-linkat.t"

#include "test-link.h"

static int dfd1 = AT_FDCWD;
static int dfd2 = AT_FDCWD;
static int flag = AT_SYMLINK_FOLLOW;

/* Wrapper to test linkat like link.  */
static int
do_link (char const *name1, char const *name2)
{
  return linkat (dfd1, name1, dfd2, name2, flag);
}

/* Can we expect that link() and linkat(), when called on a symlink,
   increment the link count of that symlink?  */
#if LINK_FOLLOWS_SYMLINKS == 0
# define EXPECT_LINK_HARDLINKS_SYMLINKS 1
#elif LINK_FOLLOWS_SYMLINKS == -1
extern int __xpg4;
# define EXPECT_LINK_HARDLINKS_SYMLINKS (__xpg4 == 0)
#else
# define EXPECT_LINK_HARDLINKS_SYMLINKS 0
#endif

/* Wrapper to see if two symlinks act the same.  */
static void
check_same_link (char const *name1, char const *name2)
{
  struct stat st1;
  struct stat st2;
  char *contents1;
  char *contents2;
  ASSERT (lstat (name1, &st1) == 0);
  ASSERT (lstat (name2, &st2) == 0);
  contents1 = areadlink_with_size (name1, st1.st_size);
  contents2 = areadlink_with_size (name2, st2.st_size);
  ASSERT (contents1);
  ASSERT (contents2);
  ASSERT (strcmp (contents1, contents2) == 0);
  if (EXPECT_LINK_HARDLINKS_SYMLINKS)
    ASSERT (SAME_INODE (st1, st2));
  free (contents1);
  free (contents2);
}

int
main (void)
{
  int i;
  int dfd;
  char *cwd;
  int result;

  /* Clean up any trash from prior testsuite runs.  */
  ignore_value (system ("rm -rf " BASE "*"));

  /* Test behaviour for invalid file descriptors.  */
  {
    errno = 0;
    ASSERT (linkat (-1, "foo", AT_FDCWD, "bar", 0) == -1);
    ASSERT (errno == EBADF);
  }
  {
    close (99);
    errno = 0;
    ASSERT (linkat (99, "foo", AT_FDCWD, "bar", 0) == -1);
    ASSERT (errno == EBADF);
  }
  ASSERT (close (creat (BASE "oo", 0600)) == 0);
  {
    errno = 0;
    ASSERT (linkat (AT_FDCWD, BASE "oo", -1, "bar", 0) == -1);
    ASSERT (errno == EBADF);
  }
  {
    errno = 0;
    ASSERT (linkat (AT_FDCWD, BASE "oo", 99, "bar", 0) == -1);
    ASSERT (errno == EBADF);
  }
  ASSERT (unlink (BASE "oo") == 0);

  /* Test basic link functionality, without mentioning symlinks.  */
  result = test_link (do_link, true);
  dfd1 = open (".", O_RDONLY);
  ASSERT (0 <= dfd1);
  ASSERT (test_link (do_link, false) == result);
  dfd2 = dfd1;
  ASSERT (test_link (do_link, false) == result);
  dfd1 = AT_FDCWD;
  ASSERT (test_link (do_link, false) == result);
  flag = 0;
  ASSERT (test_link (do_link, false) == result);
  dfd1 = dfd2;
  ASSERT (test_link (do_link, false) == result);
  dfd2 = AT_FDCWD;
  ASSERT (test_link (do_link, false) == result);
  ASSERT (close (dfd1) == 0);
  dfd1 = AT_FDCWD;
  ASSERT (test_link (do_link, false) == result);

  /* Create locations to manipulate.  */
  ASSERT (mkdir (BASE "sub1", 0700) == 0);
  ASSERT (mkdir (BASE "sub2", 0700) == 0);
  ASSERT (close (creat (BASE "00", 0600)) == 0);
  cwd = getcwd (NULL, 0);
  ASSERT (cwd);

  dfd = open (BASE "sub1", O_RDONLY);
  ASSERT (0 <= dfd);
  ASSERT (chdir (BASE "sub2") == 0);

  /* There are 16 possible scenarios, based on whether an fd is
     AT_FDCWD or real, whether a file is absolute or relative, coupled
     with whether flag is set for 32 iterations.

     To ensure that we test all of the code paths (rather than
     triggering early normalization optimizations), we use a loop to
     repeatedly rename a file in the parent directory, use an fd open
     on subdirectory 1, all while executing in subdirectory 2; all
     relative names are thus given with a leading "../".  Finally, the
     last scenario (two relative paths given, neither one AT_FDCWD)
     has two paths, based on whether the two fds are equivalent, so we
     do the other variant after the loop.  */
  for (i = 0; i < 32; i++)
    {
      int fd1 = (i & 8) ? dfd : AT_FDCWD;
      char *file1 = mfile_name_concat ((i & 4) ? ".." : cwd, BASE "xx", NULL);
      int fd2 = (i & 2) ? dfd : AT_FDCWD;
      char *file2 = mfile_name_concat ((i & 1) ? ".." : cwd, BASE "xx", NULL);
      ASSERT (file1);
      ASSERT (file2);
      flag = (i & 0x10 ? AT_SYMLINK_FOLLOW : 0);

      ASSERT (sprintf (strchr (file1, '\0') - 2, "%02d", i) == 2);
      ASSERT (sprintf (strchr (file2, '\0') - 2, "%02d", i + 1) == 2);
      ASSERT (linkat (fd1, file1, fd2, file2, flag) == 0);
      ASSERT (unlinkat (fd1, file1, 0) == 0);
      free (file1);
      free (file2);
    }
  dfd2 = open ("..", O_RDONLY);
  ASSERT (0 <= dfd2);
  ASSERT (linkat (dfd, "../" BASE "32", dfd2, BASE "33", 0) == 0);
  ASSERT (linkat (dfd, "../" BASE "33", dfd2, BASE "34",
                  AT_SYMLINK_FOLLOW) == 0);
  ASSERT (close (dfd2) == 0);

  /* Now we change back to the parent directory, and set dfd to ".",
     in order to test behavior on symlinks.  */
  ASSERT (chdir ("..") == 0);
  ASSERT (close (dfd) == 0);
  if (symlink (BASE "sub1", BASE "link1"))
    {
      ASSERT (unlink (BASE "32") == 0);
      ASSERT (unlink (BASE "33") == 0);
      ASSERT (unlink (BASE "34") == 0);
      ASSERT (rmdir (BASE "sub1") == 0);
      ASSERT (rmdir (BASE "sub2") == 0);
      free (cwd);
      if (!result)
        fputs ("skipping test: symlinks not supported on this file system\n",
               stderr);
      return result;
    }
  dfd = open (".", O_RDONLY);
  ASSERT (0 <= dfd);
  ASSERT (symlink (BASE "34", BASE "link2") == 0);
  ASSERT (symlink (BASE "link3", BASE "link3") == 0);
  ASSERT (symlink (BASE "nowhere", BASE "link4") == 0);

  /* Link cannot overwrite existing files.  */
  errno = 0;
  ASSERT (linkat (dfd, BASE "link1", dfd, BASE "sub1", 0) == -1);
  ASSERT (errno == EEXIST);
  errno = 0;
  ASSERT (linkat (dfd, BASE "link1/", dfd, BASE "sub1", 0) == -1);
  ASSERT (errno == EEXIST || errno == EPERM || errno == EACCES);
  errno = 0;
  ASSERT (linkat (dfd, BASE "link1", dfd, BASE "sub1/", 0) == -1);
  ASSERT (errno == EEXIST || errno == ENOTDIR);
  errno = 0;
  ASSERT (linkat (dfd, BASE "link1", dfd, BASE "sub1",
                  AT_SYMLINK_FOLLOW) == -1);
  ASSERT (errno == EEXIST || errno == EPERM || errno == EACCES);
  errno = 0;
  ASSERT (linkat (dfd, BASE "link1/", dfd, BASE "sub1",
                  AT_SYMLINK_FOLLOW) == -1);
  ASSERT (errno == EEXIST || errno == EPERM || errno == EACCES
          || errno == EINVAL);
  errno = 0;
  ASSERT (linkat (dfd, BASE "link1", dfd, BASE "sub1/",
                  AT_SYMLINK_FOLLOW) == -1);
  ASSERT (errno == EEXIST || errno == EPERM || errno == EACCES
          || errno == EINVAL);
  errno = 0;
  ASSERT (linkat (dfd, BASE "link1", dfd, BASE "link2", 0) == -1);
  ASSERT (errno == EEXIST);
  errno = 0;
  ASSERT (linkat (dfd, BASE "link1", dfd, BASE "link2",
                  AT_SYMLINK_FOLLOW) == -1);
  ASSERT (errno == EEXIST || errno == EPERM || errno == EACCES);
  errno = 0;
  ASSERT (linkat (dfd, BASE "link1", dfd, BASE "link3", 0) == -1);
  ASSERT (errno == EEXIST || errno == ELOOP);
  errno = 0;
  ASSERT (linkat (dfd, BASE "link1", dfd, BASE "link3",
                  AT_SYMLINK_FOLLOW) == -1);
  ASSERT (errno == EEXIST || errno == EPERM || errno == EACCES
          || errno == ELOOP);
  errno = 0;
  ASSERT (linkat (dfd, BASE "link2", dfd, BASE "link3", 0) == -1);
  ASSERT (errno == EEXIST || errno == ELOOP);
  errno = 0;
  ASSERT (linkat (dfd, BASE "link2", dfd, BASE "link3",
                  AT_SYMLINK_FOLLOW) == -1);
  ASSERT (errno == EEXIST || errno == ELOOP);

  /* AT_SYMLINK_FOLLOW only follows first argument, not second.  */
  errno = 0;
  ASSERT (linkat (dfd, BASE "link1", dfd, BASE "link4", 0) == -1);
  ASSERT (errno == EEXIST);
  ASSERT (linkat (dfd, BASE "link1", dfd, BASE "link4",
                  AT_SYMLINK_FOLLOW) == -1);
  ASSERT (errno == EEXIST || errno == EPERM || errno == EACCES);
  errno = 0;
  ASSERT (linkat (dfd, BASE "34", dfd, BASE "link4", 0) == -1);
  ASSERT (errno == EEXIST);
  errno = 0;
  ASSERT (linkat (dfd, BASE "34", dfd, BASE "link4", AT_SYMLINK_FOLLOW) == -1);
  ASSERT (errno == EEXIST);

  /* Trailing slash handling.  */
  errno = 0;
  ASSERT (linkat (dfd, BASE "link2/", dfd, BASE "link5", 0) == -1);
  ASSERT (errno == ENOTDIR);
  errno = 0;
  ASSERT (linkat (dfd, BASE "link2/", dfd, BASE "link5",
                  AT_SYMLINK_FOLLOW) == -1);
  ASSERT (errno == ENOTDIR || errno == EINVAL);
  errno = 0;
  ASSERT (linkat (dfd, BASE "link3/", dfd, BASE "link5", 0) == -1);
  ASSERT (errno == ELOOP);
  errno = 0;
  ASSERT (linkat (dfd, BASE "link3/", dfd, BASE "link5",
                  AT_SYMLINK_FOLLOW) == -1);
  ASSERT (errno == ELOOP || errno == EINVAL);
  errno = 0;
  ASSERT (linkat (dfd, BASE "link4/", dfd, BASE "link5", 0) == -1);
  ASSERT (errno == ENOENT);
  errno = 0;
  ASSERT (linkat (dfd, BASE "link4/", dfd, BASE "link5",
                  AT_SYMLINK_FOLLOW) == -1);
  ASSERT (errno == ENOENT || errno == EINVAL);

  /* Check for hard links to symlinks.  */
  ASSERT (linkat (dfd, BASE "link1", dfd, BASE "link5", 0) == 0);
  check_same_link (BASE "link1", BASE "link5");
  ASSERT (unlink (BASE "link5") == 0);
  errno = 0;
  ASSERT (linkat (dfd, BASE "link1", dfd, BASE "link5",
                  AT_SYMLINK_FOLLOW) == -1);
  ASSERT (errno == EPERM || errno == EACCES);
  ASSERT (linkat (dfd, BASE "link2", dfd, BASE "link5", 0) == 0);
  check_same_link (BASE "link2", BASE "link5");
  ASSERT (unlink (BASE "link5") == 0);
  ASSERT (linkat (dfd, BASE "link2", dfd, BASE "file", AT_SYMLINK_FOLLOW) == 0);
  errno = 0;
  ASSERT (areadlink (BASE "file") == NULL);
  ASSERT (errno == EINVAL);
  ASSERT (unlink (BASE "file") == 0);
  ASSERT (linkat (dfd, BASE "link3", dfd, BASE "link5", 0) == 0);
  check_same_link (BASE "link3", BASE "link5");
  ASSERT (unlink (BASE "link5") == 0);
  errno = 0;
  ASSERT (linkat (dfd, BASE "link3", dfd, BASE "link5",
                  AT_SYMLINK_FOLLOW) == -1);
  ASSERT (errno == ELOOP);
  ASSERT (linkat (dfd, BASE "link4", dfd, BASE "link5", 0) == 0);
  check_same_link (BASE "link4", BASE "link5");
  ASSERT (unlink (BASE "link5") == 0);
  errno = 0;
  ASSERT (linkat (dfd, BASE "link4", dfd, BASE "link5",
                  AT_SYMLINK_FOLLOW) == -1);
  ASSERT (errno == ENOENT);

  /* Check that symlink to symlink to file is followed all the way.  */
  ASSERT (symlink (BASE "link2", BASE "link5") == 0);
  ASSERT (linkat (dfd, BASE "link5", dfd, BASE "link6", 0) == 0);
  check_same_link (BASE "link5", BASE "link6");
  ASSERT (unlink (BASE "link6") == 0);
  ASSERT (linkat (dfd, BASE "link5", dfd, BASE "file", AT_SYMLINK_FOLLOW) == 0);
  errno = 0;
  ASSERT (areadlink (BASE "file") == NULL);
  ASSERT (errno == EINVAL);
  ASSERT (unlink (BASE "file") == 0);
  ASSERT (unlink (BASE "link5") == 0);
  ASSERT (symlink (BASE "link3", BASE "link5") == 0);
  errno = 0;
  ASSERT (linkat (dfd, BASE "link5", dfd, BASE "file",
                  AT_SYMLINK_FOLLOW) == -1);
  ASSERT (errno == ELOOP);
  ASSERT (unlink (BASE "link5") == 0);
  ASSERT (symlink (BASE "link4", BASE "link5") == 0);
  errno = 0;
  ASSERT (linkat (dfd, BASE "link5", dfd, BASE "file",
                  AT_SYMLINK_FOLLOW) == -1);
  ASSERT (errno == ENOENT);

  /* Now for some real fun with directory crossing.  */
  ASSERT (symlink (cwd, BASE "sub1/link") == 0);
  ASSERT (symlink (".././/" BASE "sub1/link/" BASE "link2",
                   BASE "sub2/link") == 0);
  ASSERT (close (dfd) == 0);
  dfd = open (BASE "sub1", O_RDONLY);
  ASSERT (0 <= dfd);
  dfd2 = open (BASE "sub2", O_RDONLY);
  ASSERT (0 < dfd2);
  ASSERT (linkat (dfd, "../" BASE "sub2/link", dfd2, "./..//" BASE "sub1/file",
              AT_SYMLINK_FOLLOW) == 0);
  errno = 0;
  ASSERT (areadlink (BASE "sub1/file") == NULL);
  ASSERT (errno == EINVAL);

  /* Cleanup.  */
  ASSERT (close (dfd) == 0);
  ASSERT (close (dfd2) == 0);
  ASSERT (unlink (BASE "sub1/file") == 0);
  ASSERT (unlink (BASE "sub1/link") == 0);
  ASSERT (unlink (BASE "sub2/link") == 0);
  ASSERT (unlink (BASE "32") == 0);
  ASSERT (unlink (BASE "33") == 0);
  ASSERT (unlink (BASE "34") == 0);
  ASSERT (rmdir (BASE "sub1") == 0);
  ASSERT (rmdir (BASE "sub2") == 0);
  ASSERT (unlink (BASE "link1") == 0);
  ASSERT (unlink (BASE "link2") == 0);
  ASSERT (unlink (BASE "link3") == 0);
  ASSERT (unlink (BASE "link4") == 0);
  ASSERT (unlink (BASE "link5") == 0);
  free (cwd);
  return result;
}
