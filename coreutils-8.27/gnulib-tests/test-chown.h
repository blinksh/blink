/* Tests of chown.
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

#include "nap.h"

#if !HAVE_GETEGID
# define getegid() ((gid_t) -1)
#endif

/* This file is designed to test chown(n,o,g) and
   chownat(AT_FDCWD,n,o,g,0).  FUNC is the function to test.  Assumes
   that BASE and ASSERT are already defined, and that appropriate
   headers are already included.  If PRINT, warn before skipping
   symlink tests with status 77.  */

static int
test_chown (int (*func) (char const *, uid_t, gid_t), bool print)
{
  struct stat st1;
  struct stat st2;
  gid_t *gids = NULL;
  int gids_count;
  int result;

  /* Solaris 8 is interesting - if the current process belongs to
     multiple groups, the current directory is owned by a group that
     the current process belongs to but different than getegid(), and
     the current directory does not have the S_ISGID bit, then regular
     files created in the directory belong to the directory's group,
     but symlinks belong to the current effective group id.  If
     S_ISGID is set, then both files and symlinks belong to the
     directory's group.  However, it is possible to run the testsuite
     from within a directory owned by a group we don't belong to, in
     which case all things that we create belong to the current
     effective gid.  So, work around the issues by creating a
     subdirectory (we are guaranteed that the subdirectory will be
     owned by one of our current groups), change ownership of that
     directory to the current effective gid (which will thus succeed),
     then create all other files within that directory (eliminating
     questions on whether inheritance or current id triumphs, since
     the two methods resolve to the same gid).  */
  ASSERT (mkdir (BASE "dir", 0700) == 0);
  ASSERT (stat (BASE "dir", &st1) == 0);

  /* Filter out mingw and file systems which have no concept of groups.  */
  result = func (BASE "dir", st1.st_uid, getegid ());
  if (result == -1 && (errno == ENOSYS || errno == EPERM))
    {
      ASSERT (rmdir (BASE "dir") == 0);
      if (print)
        fputs ("skipping test: no support for ownership\n", stderr);
      return 77;
    }
  ASSERT (result == 0);

  ASSERT (close (creat (BASE "dir/file", 0600)) == 0);
  ASSERT (stat (BASE "dir/file", &st1) == 0);
  ASSERT (st1.st_uid != (uid_t) -1);
  ASSERT (st1.st_gid != (gid_t) -1);
  ASSERT (st1.st_gid == getegid ());

  /* Sanity check of error cases.  */
  errno = 0;
  ASSERT (func ("", -1, -1) == -1);
  ASSERT (errno == ENOENT);
  errno = 0;
  ASSERT (func ("no_such", -1, -1) == -1);
  ASSERT (errno == ENOENT);
  errno = 0;
  ASSERT (func ("no_such/", -1, -1) == -1);
  ASSERT (errno == ENOENT);
  errno = 0;
  ASSERT (func (BASE "dir/file/", -1, -1) == -1);
  ASSERT (errno == ENOTDIR);

  /* Check that -1 does not alter ownership.  */
  ASSERT (func (BASE "dir/file", -1, st1.st_gid) == 0);
  ASSERT (func (BASE "dir/file", st1.st_uid, -1) == 0);
  ASSERT (func (BASE "dir/file", (uid_t) -1, (gid_t) -1) == 0);
  ASSERT (stat (BASE "dir/file", &st2) == 0);
  ASSERT (st1.st_uid == st2.st_uid);
  ASSERT (st1.st_gid == st2.st_gid);

  /* Even if the values aren't changing, ctime is required to change
     if at least one argument is not -1.  */
  nap ();
  ASSERT (func (BASE "dir/file", st1.st_uid, st1.st_gid) == 0);
  ASSERT (stat (BASE "dir/file", &st2) == 0);
  ASSERT (st1.st_ctime < st2.st_ctime
          || (st1.st_ctime == st2.st_ctime
              && get_stat_ctime_ns (&st1) < get_stat_ctime_ns (&st2)));

  /* Test symlink behavior.  */
  if (symlink ("link", BASE "dir/link2"))
    {
      ASSERT (unlink (BASE "dir/file") == 0);
      ASSERT (rmdir (BASE "dir") == 0);
      if (print)
        fputs ("skipping test: symlinks not supported on this file system\n",
               stderr);
      return 77;
    }
  errno = 0;
  ASSERT (func (BASE "dir/link2", -1, -1) == -1);
  ASSERT (errno == ENOENT);
  errno = 0;
  ASSERT (func (BASE "dir/link2/", st1.st_uid, st1.st_gid) == -1);
  ASSERT (errno == ENOENT);
  ASSERT (symlink ("file", BASE "dir/link") == 0);

  /* For non-privileged users, chown can only portably succeed at
     changing group ownership of a file we own.  If we belong to at
     least two groups, then verifying the correct change is simple.
     But if we belong to only one group, then we fall back on the
     other observable effect of chown: the ctime must be updated.  */
  gids_count = mgetgroups (NULL, st1.st_gid, &gids);
  if (1 < gids_count)
    {
      ASSERT (gids[1] != st1.st_gid);
      ASSERT (gids[1] != (gid_t) -1);
      ASSERT (lstat (BASE "dir/link", &st2) == 0);
      ASSERT (st1.st_uid == st2.st_uid);
      ASSERT (st1.st_gid == st2.st_gid);
      ASSERT (lstat (BASE "dir/link2", &st2) == 0);
      ASSERT (st1.st_uid == st2.st_uid);
      ASSERT (st1.st_gid == st2.st_gid);

      errno = 0;
      ASSERT (func (BASE "dir/link2/", -1, gids[1]) == -1);
      ASSERT (errno == ENOTDIR);
      ASSERT (stat (BASE "dir/file", &st2) == 0);
      ASSERT (st1.st_uid == st2.st_uid);
      ASSERT (st1.st_gid == st2.st_gid);
      ASSERT (lstat (BASE "dir/link", &st2) == 0);
      ASSERT (st1.st_uid == st2.st_uid);
      ASSERT (st1.st_gid == st2.st_gid);
      ASSERT (lstat (BASE "dir/link2", &st2) == 0);
      ASSERT (st1.st_uid == st2.st_uid);
      ASSERT (st1.st_gid == st2.st_gid);

      ASSERT (func (BASE "dir/link2", -1, gids[1]) == 0);
      ASSERT (stat (BASE "dir/file", &st2) == 0);
      ASSERT (st1.st_uid == st2.st_uid);
      ASSERT (gids[1] == st2.st_gid);
      ASSERT (lstat (BASE "dir/link", &st2) == 0);
      ASSERT (st1.st_uid == st2.st_uid);
      ASSERT (st1.st_gid == st2.st_gid);
      ASSERT (lstat (BASE "dir/link2", &st2) == 0);
      ASSERT (st1.st_uid == st2.st_uid);
      ASSERT (st1.st_gid == st2.st_gid);
    }
  else
    {
      struct stat l1;
      struct stat l2;
      ASSERT (stat (BASE "dir/file", &st1) == 0);
      ASSERT (lstat (BASE "dir/link", &l1) == 0);
      ASSERT (lstat (BASE "dir/link2", &l2) == 0);

      nap ();
      errno = 0;
      ASSERT (func (BASE "dir/link2/", -1, st1.st_gid) == -1);
      ASSERT (errno == ENOTDIR);
      ASSERT (stat (BASE "dir/file", &st2) == 0);
      ASSERT (st1.st_ctime == st2.st_ctime);
      ASSERT (get_stat_ctime_ns (&st1) == get_stat_ctime_ns (&st2));
      ASSERT (lstat (BASE "dir/link", &st2) == 0);
      ASSERT (l1.st_ctime == st2.st_ctime);
      ASSERT (get_stat_ctime_ns (&l1) == get_stat_ctime_ns (&st2));
      ASSERT (lstat (BASE "dir/link2", &st2) == 0);
      ASSERT (l2.st_ctime == st2.st_ctime);
      ASSERT (get_stat_ctime_ns (&l2) == get_stat_ctime_ns (&st2));

      ASSERT (func (BASE "dir/link2", -1, st1.st_gid) == 0);
      ASSERT (stat (BASE "dir/file", &st2) == 0);
      ASSERT (st1.st_ctime < st2.st_ctime
              || (st1.st_ctime == st2.st_ctime
                  && get_stat_ctime_ns (&st1) < get_stat_ctime_ns (&st2)));
      ASSERT (lstat (BASE "dir/link", &st2) == 0);
      ASSERT (l1.st_ctime == st2.st_ctime);
      ASSERT (get_stat_ctime_ns (&l1) == get_stat_ctime_ns (&st2));
      ASSERT (lstat (BASE "dir/link2", &st2) == 0);
      ASSERT (l2.st_ctime == st2.st_ctime);
      ASSERT (get_stat_ctime_ns (&l2) == get_stat_ctime_ns (&st2));
    }

  /* Cleanup.  */
  free (gids);
  ASSERT (unlink (BASE "dir/file") == 0);
  ASSERT (unlink (BASE "dir/link") == 0);
  ASSERT (unlink (BASE "dir/link2") == 0);
  ASSERT (rmdir (BASE "dir") == 0);
  return 0;
}
