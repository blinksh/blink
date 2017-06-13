/* Test of rename() function.
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

/* This file is designed to test both rename(a,b) and
   renameat(AT_FDCWD,a,AT_FDCWD,b).  FUNC is the function to test.
   Assumes that BASE and ASSERT are already defined, and that
   appropriate headers are already included.  If PRINT, warn before
   skipping symlink tests with status 77.  */

/* Tests whether a file, given by a file name without slashes, exists in
   the current directory, by scanning the directory entries.  */
static bool
dentry_exists (const char *filename)
{
  bool exists = false;
  DIR *dir = opendir (".");

  ASSERT (dir != NULL);
  for (;;)
    {
      struct dirent *d = readdir (dir);
      if (d == NULL)
        break;
      if (strcmp (d->d_name, filename) == 0)
        {
          exists = true;
          break;
        }
    }
  ASSERT (closedir (dir) == 0);
  return exists;
}

/* Asserts that a specific file, given by a file name without slashes, does
   not exist in the current directory.  */
static void
assert_nonexistent (const char *filename)
{
  struct stat st;

  /* The usual way to test the presence of a file is via stat() or lstat().  */
  errno = 0;
  if (stat (filename, &st) == -1)
    ASSERT (errno == ENOENT);
  else
    {
      /* But after renaming a directory over an empty directory on an NFS-
         mounted file system, on Linux 2.6.18, for a period of 30 seconds the
         old directory name is "present" according to stat() but "nonexistent"
         according to dentry_exists().  */
      ASSERT (!dentry_exists (filename));
      /* Remove the old directory name, so that subsequent mkdir calls
         succeed.  */
      (void) rmdir (filename);
    }
}

static int
test_rename (int (*func) (char const *, char const *), bool print)
{
  /* Setup.  */
  struct stat st;
  int fd = creat (BASE "file", 0600);
  ASSERT (0 <= fd);
  ASSERT (write (fd, "hi", 2) == 2);
  ASSERT (close (fd) == 0);
  ASSERT (mkdir (BASE "dir", 0700) == 0);

  /* Files present here:
       {BASE}file
       {BASE}dir/
   */

  /* Obvious errors.  */

  { /* Missing source.  */
    {
      errno = 0;
      ASSERT (func (BASE "missing", BASE "missing") == -1);
      ASSERT (errno == ENOENT);
    }
    {
      errno = 0;
      ASSERT (func (BASE "missing/", BASE "missing") == -1);
      ASSERT (errno == ENOENT);
    }
    {
      errno = 0;
      ASSERT (func (BASE "missing", BASE "missing/") == -1);
      ASSERT (errno == ENOENT);
    }
  }
  { /* Empty operand.  */
    {
      errno = 0;
      ASSERT (func ("", BASE "missing") == -1);
      ASSERT (errno == ENOENT);
    }
    {
      errno = 0;
      ASSERT (func (BASE "file", "") == -1);
      ASSERT (errno == ENOENT);
    }
    {
      errno = 0;
      ASSERT (func (BASE "", "") == -1);
      ASSERT (errno == ENOENT);
    }
  }

  /* Files.  */

  { /* Trailing slash.  */
    {
      errno = 0;
      ASSERT (func (BASE "file", BASE "file2/") == -1);
      ASSERT (errno == ENOENT || errno == ENOTDIR);
    }
    {
      errno = 0;
      ASSERT (func (BASE "file/", BASE "file2") == -1);
      ASSERT (errno == ENOTDIR);
    }
    {
      errno = 0;
      ASSERT (stat (BASE "file2", &st) == -1);
      ASSERT (errno == ENOENT);
    }
  }
  { /* Simple rename.  */
    ASSERT (func (BASE "file", BASE "file2") == 0);
    errno = 0;
    ASSERT (stat (BASE "file", &st) == -1);
    ASSERT (errno == ENOENT);
    memset (&st, 0, sizeof st);
    ASSERT (stat (BASE "file2", &st) == 0);
    ASSERT (st.st_size == 2);
  }
  /* Files present here:
       {BASE}file2
       {BASE}dir/
   */
  { /* Overwrite.  */
    ASSERT (close (creat (BASE "file", 0600)) == 0);
    errno = 0;
    ASSERT (func (BASE "file2", BASE "file/") == -1);
    ASSERT (errno == ENOTDIR);
    ASSERT (func (BASE "file2", BASE "file") == 0);
    memset (&st, 0, sizeof st);
    ASSERT (stat (BASE "file", &st) == 0);
    ASSERT (st.st_size == 2);
    errno = 0;
    ASSERT (stat (BASE "file2", &st) == -1);
    ASSERT (errno == ENOENT);
  }
  /* Files present here:
       {BASE}file
       {BASE}dir/
   */

  /* Directories.  */

  { /* Simple rename.  */
    {
      ASSERT (func (BASE "dir", BASE "dir2/") == 0);
      errno = 0;
      ASSERT (stat (BASE "dir", &st) == -1);
      ASSERT (errno == ENOENT);
      ASSERT (stat (BASE "dir2", &st) == 0);
    }
    /* Files present here:
         {BASE}file
         {BASE}dir2/
     */
    {
      ASSERT (func (BASE "dir2/", BASE "dir") == 0);
      ASSERT (stat (BASE "dir", &st) == 0);
      errno = 0;
      ASSERT (stat (BASE "dir2", &st) == -1);
      ASSERT (errno == ENOENT);
    }
    /* Files present here:
         {BASE}file
         {BASE}dir/
     */
    {
      ASSERT (func (BASE "dir", BASE "dir2") == 0);
      errno = 0;
      ASSERT (stat (BASE "dir", &st) == -1);
      ASSERT (errno == ENOENT);
      ASSERT (stat (BASE "dir2", &st) == 0);
    }
    /* Files present here:
         {BASE}file
         {BASE}dir2/
     */
    { /* Empty onto empty.  */
      ASSERT (mkdir (BASE "dir", 0700) == 0);
      /* Files present here:
           {BASE}file
           {BASE}dir/
           {BASE}dir2/
       */
      ASSERT (func (BASE "dir2", BASE "dir") == 0);
      /* Files present here:
           {BASE}file
           {BASE}dir/
       */
      ASSERT (mkdir (BASE "dir2", 0700) == 0);
      /* Files present here:
           {BASE}file
           {BASE}dir/
           {BASE}dir2/
       */
      ASSERT (func (BASE "dir2", BASE "dir/") == 0);
      /* Files present here:
           {BASE}file
           {BASE}dir/
       */
      ASSERT (mkdir (BASE "dir2", 0700) == 0);
      /* Files present here:
           {BASE}file
           {BASE}dir/
           {BASE}dir2/
       */
      ASSERT (func (BASE "dir2/", BASE "dir") == 0);
      /* Files present here:
           {BASE}file
           {BASE}dir/
       */
      ASSERT (mkdir (BASE "dir2", 0700) == 0);
    }
    /* Files present here:
         {BASE}file
         {BASE}dir/
         {BASE}dir2/
     */
    { /* Empty onto full.  */
      ASSERT (close (creat (BASE "dir/file", 0600)) == 0);
      /* Files present here:
           {BASE}file
           {BASE}dir/
           {BASE}dir/file
           {BASE}dir2/
       */
      {
        errno = 0;
        ASSERT (func (BASE "dir2", BASE "dir") == -1);
        ASSERT (errno == EEXIST || errno == ENOTEMPTY);
      }
      {
        errno = 0;
        ASSERT (func (BASE "dir2/", BASE "dir") == -1);
        ASSERT (errno == EEXIST || errno == ENOTEMPTY);
      }
      {
        errno = 0;
        ASSERT (func (BASE "dir2", BASE "dir/") == -1);
        ASSERT (errno == EEXIST || errno == ENOTEMPTY);
      }
    }
    { /* Full onto empty.  */
      ASSERT (func (BASE "dir", BASE "dir2") == 0);
      assert_nonexistent (BASE "dir");
      ASSERT (stat (BASE "dir2/file", &st) == 0);
      /* Files present here:
           {BASE}file
           {BASE}dir2/
           {BASE}dir2/file
       */
      ASSERT (mkdir (BASE "dir", 0700) == 0);
      /* Files present here:
           {BASE}file
           {BASE}dir/
           {BASE}dir2/
           {BASE}dir2/file
       */
      {
        ASSERT (func (BASE "dir2/", BASE "dir") == 0);
        ASSERT (stat (BASE "dir/file", &st) == 0);
        errno = 0;
        ASSERT (stat (BASE "dir2", &st) == -1);
        ASSERT (errno == ENOENT);
      }
      /* Files present here:
           {BASE}file
           {BASE}dir/
           {BASE}dir/file
       */
      ASSERT (mkdir (BASE "dir2", 0700) == 0);
      /* Files present here:
           {BASE}file
           {BASE}dir/
           {BASE}dir/file
           {BASE}dir2/
       */
      {
        ASSERT (func (BASE "dir", BASE "dir2/") == 0);
        assert_nonexistent (BASE "dir");
        ASSERT (stat (BASE "dir2/file", &st) == 0);
      }
      /* Files present here:
           {BASE}file
           {BASE}dir2/
           {BASE}dir2/file
       */
      ASSERT (unlink (BASE "dir2/file") == 0);
    }
    /* Files present here:
         {BASE}file
         {BASE}dir2/
     */
    { /* Reject trailing dot.  */
      {
        errno = 0;
        ASSERT (func (BASE "dir2", BASE "dir/.") == -1);
        ASSERT (errno == EINVAL || errno == ENOENT);
      }
      ASSERT (mkdir (BASE "dir", 0700) == 0);
      /* Files present here:
           {BASE}file
           {BASE}dir/
           {BASE}dir2/
       */
      {
        errno = 0;
        ASSERT (func (BASE "dir2", BASE "dir/.") == -1);
        ASSERT (errno == EINVAL || errno == EBUSY || errno == EISDIR
                || errno == ENOTEMPTY || errno == EEXIST);
      }
      {
        errno = 0;
        ASSERT (func (BASE "dir2/.", BASE "dir") == -1);
        ASSERT (errno == EINVAL || errno == EBUSY || errno == EEXIST);
      }
      ASSERT (rmdir (BASE "dir") == 0);
      /* Files present here:
           {BASE}file
           {BASE}dir2/
       */
      {
        errno = 0;
        ASSERT (func (BASE "dir2", BASE "dir/.//") == -1);
        ASSERT (errno == EINVAL || errno == ENOENT);
      }
      ASSERT (mkdir (BASE "dir", 0700) == 0);
      /* Files present here:
           {BASE}file
           {BASE}dir/
           {BASE}dir2/
       */
      {
        errno = 0;
        ASSERT (func (BASE "dir2", BASE "dir/.//") == -1);
        ASSERT (errno == EINVAL || errno == EBUSY || errno == EISDIR
                || errno == ENOTEMPTY || errno == EEXIST);
      }
      {
        errno = 0;
        ASSERT (func (BASE "dir2/.//", BASE "dir") == -1);
        ASSERT (errno == EINVAL || errno == EBUSY || errno == EEXIST);
      }
      ASSERT (rmdir (BASE "dir2") == 0);
      /* Files present here:
           {BASE}file
           {BASE}dir/
       */
    }
    { /* Move into subdir.  */
      {
        errno = 0;
        ASSERT (func (BASE "dir", BASE "dir/sub") == -1);
        ASSERT (errno == EINVAL || errno == EACCES);
      }
      {
        errno = 0;
        ASSERT (stat (BASE "dir/sub", &st) == -1);
        ASSERT (errno == ENOENT);
      }
      ASSERT (mkdir (BASE "dir/sub", 0700) == 0);
      /* Files present here:
           {BASE}file
           {BASE}dir/
           {BASE}dir/sub/
       */
      {
        errno = 0;
        ASSERT (func (BASE "dir", BASE "dir/sub") == -1);
        ASSERT (errno == EINVAL);
        ASSERT (stat (BASE "dir/sub", &st) == 0);
      }
      ASSERT (rmdir (BASE "dir/sub") == 0);
    }
  }
  /* Files present here:
       {BASE}file
       {BASE}dir/
   */

  /* Mixing file and directory.  */

  {
    { /* File onto dir.  */
      {
        errno = 0;
        ASSERT (func (BASE "file", BASE "dir") == -1);
        ASSERT (errno == EISDIR || errno == ENOTDIR);
      }
      {
        errno = 0;
        ASSERT (func (BASE "file", BASE "dir/") == -1);
        ASSERT (errno == EISDIR || errno == ENOTDIR);
      }
    }
    { /* Dir onto file.  */
      {
        errno = 0;
        ASSERT (func (BASE "dir", BASE "file") == -1);
        ASSERT (errno == ENOTDIR);
      }
      {
        errno = 0;
        ASSERT (func (BASE "dir/", BASE "file") == -1);
        ASSERT (errno == ENOTDIR);
      }
    }
  }

  /* Hard links.  */

  { /* File onto self.  */
    ASSERT (func (BASE "file", BASE "file") == 0);
    memset (&st, 0, sizeof st);
    ASSERT (stat (BASE "file", &st) == 0);
    ASSERT (st.st_size == 2);
  }
  /* Files present here:
       {BASE}file
       {BASE}dir/
   */
  { /* Empty dir onto self.  */
    ASSERT (func (BASE "dir", BASE "dir") == 0);
    ASSERT (stat (BASE "dir", &st) == 0);
  }
  /* Files present here:
       {BASE}file
       {BASE}dir/
   */
  ASSERT (close (creat (BASE "dir/file", 0600)) == 0);
  /* Files present here:
       {BASE}file
       {BASE}dir/
       {BASE}dir/file
   */
  { /* Full dir onto self.  */
    ASSERT (func (BASE "dir", BASE "dir") == 0);
  }
  ASSERT (unlink (BASE "dir/file") == 0);
  /* Files present here:
       {BASE}file
       {BASE}dir/
   */
  {
    /*  Not all file systems support link.  Mingw doesn't have
        reliable st_nlink on hard links, but our implementation does
        fail with EPERM on poor file systems, and we can detect the
        inferior stat() via st_ino.  Cygwin 1.5.x copies rather than
        links files on those file systems, but there, st_nlink and
        st_ino are reliable.  */
    int ret = link (BASE "file", BASE "file2");
    if (!ret)
      {
        memset (&st, 0, sizeof st);
        ASSERT (stat (BASE "file2", &st) == 0);
        if (st.st_ino && st.st_nlink != 2)
          {
            ASSERT (unlink (BASE "file2") == 0);
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
            ASSERT (unlink (BASE "file") == 0);
            ASSERT (rmdir (BASE "dir") == 0);
            return 77;
          default:
            perror ("link");
            return 1;
          }
      }
    ASSERT (ret == 0);
  }
  /* Files present here:
       {BASE}file
       {BASE}file2       (hard link to file)
       {BASE}dir/
   */
  { /* File onto hard link.  */
    ASSERT (func (BASE "file", BASE "file2") == 0);
    memset (&st, 0, sizeof st);
    ASSERT (stat (BASE "file", &st) == 0);
    ASSERT (st.st_size == 2);
    memset (&st, 0, sizeof st);
    ASSERT (stat (BASE "file2", &st) == 0);
    ASSERT (st.st_size == 2);
  }
  /* Files present here:
       {BASE}file
       {BASE}file2
       {BASE}dir/
   */
  ASSERT (unlink (BASE "file2") == 0);
  /* Files present here:
       {BASE}file
       {BASE}dir/
   */

  /* Symlinks.  */

  if (symlink (BASE "file", BASE "link1"))
    {
      if (print)
        fputs ("skipping test: symlinks not supported on this file system\n",
               stderr);
      ASSERT (unlink (BASE "file") == 0);
      ASSERT (rmdir (BASE "dir") == 0);
      return 77;
    }
  /* Files present here:
       {BASE}file
       {BASE}link1 -> {BASE}file
       {BASE}dir/
   */
  { /* Simple rename.  */
    ASSERT (func (BASE "link1", BASE "link2") == 0);
    ASSERT (stat (BASE "file", &st) == 0);
    errno = 0;
    ASSERT (lstat (BASE "link1", &st) == -1);
    ASSERT (errno == ENOENT);
    memset (&st, 0, sizeof st);
    ASSERT (lstat (BASE "link2", &st) == 0);
    ASSERT (S_ISLNK (st.st_mode));
  }
  /* Files present here:
       {BASE}file
       {BASE}link2 -> {BASE}file
       {BASE}dir/
   */
  { /* Overwrite.  */
    ASSERT (symlink (BASE "nowhere", BASE "link1") == 0);
    /* Files present here:
         {BASE}file
         {BASE}link1 -> {BASE}nowhere
         {BASE}link2 -> {BASE}file
         {BASE}dir/
     */
    {
      ASSERT (func (BASE "link2", BASE "link1") == 0);
      memset (&st, 0, sizeof st);
      ASSERT (stat (BASE "link1", &st) == 0);
      ASSERT (st.st_size == 2);
      errno = 0;
      ASSERT (lstat (BASE "link2", &st) == -1);
      ASSERT (errno == ENOENT);
    }
  }
  /* Files present here:
       {BASE}file
       {BASE}link1 -> {BASE}file
       {BASE}dir/
   */
  { /* Symlink loop.  */
    ASSERT (symlink (BASE "link2", BASE "link2") == 0);
    /* Files present here:
         {BASE}file
         {BASE}link1 -> {BASE}file
         {BASE}link2 -> {BASE}link2
         {BASE}dir/
     */
    {
      ASSERT (func (BASE "link2", BASE "link2") == 0);
    }
    {
      errno = 0;
      ASSERT (func (BASE "link2/", BASE "link2") == -1);
      ASSERT (errno == ELOOP || errno == ENOTDIR);
    }
    ASSERT (func (BASE "link2", BASE "link3") == 0);
    /* Files present here:
         {BASE}file
         {BASE}link1 -> {BASE}file
         {BASE}link3 -> {BASE}link2
         {BASE}dir/
     */
    ASSERT (unlink (BASE "link3") == 0);
  }
  /* Files present here:
       {BASE}file
       {BASE}link1 -> {BASE}file
       {BASE}dir/
   */
  { /* Dangling link.  */
    ASSERT (symlink (BASE "nowhere", BASE "link2") == 0);
    /* Files present here:
         {BASE}file
         {BASE}link1 -> {BASE}file
         {BASE}link2 -> {BASE}nowhere
         {BASE}dir/
     */
    {
      ASSERT (func (BASE "link2", BASE "link3") == 0);
      errno = 0;
      ASSERT (lstat (BASE "link2", &st) == -1);
      ASSERT (errno == ENOENT);
      memset (&st, 0, sizeof st);
      ASSERT (lstat (BASE "link3", &st) == 0);
    }
  }
  /* Files present here:
       {BASE}file
       {BASE}link1 -> {BASE}file
       {BASE}link3 -> {BASE}nowhere
       {BASE}dir/
   */
  { /* Trailing slash on dangling.  */
    {
      errno = 0;
      ASSERT (func (BASE "link3/", BASE "link2") == -1);
      ASSERT (errno == ENOENT || errno == ENOTDIR);
    }
    {
      errno = 0;
      ASSERT (func (BASE "link3", BASE "link2/") == -1);
      ASSERT (errno == ENOENT || errno == ENOTDIR);
    }
    {
      errno = 0;
      ASSERT (lstat (BASE "link2", &st) == -1);
      ASSERT (errno == ENOENT);
    }
    memset (&st, 0, sizeof st);
    ASSERT (lstat (BASE "link3", &st) == 0);
  }
  /* Files present here:
       {BASE}file
       {BASE}link1 -> {BASE}file
       {BASE}link3 -> {BASE}nowhere
       {BASE}dir/
   */
  { /* Trailing slash on link to file.  */
    {
      errno = 0;
      ASSERT (func (BASE "link1/", BASE "link2") == -1);
      ASSERT (errno == ENOTDIR);
    }
    {
      errno = 0;
      ASSERT (func (BASE "link1", BASE "link3/") == -1);
      ASSERT (errno == ENOENT || errno == ENOTDIR);
    }
  }
  /* Files present here:
       {BASE}file
       {BASE}link1 -> {BASE}file
       {BASE}link3 -> {BASE}nowhere
       {BASE}dir/
   */

  /* Mixing symlink and file.  */

  { /* File onto link.  */
    ASSERT (close (creat (BASE "file2", 0600)) == 0);
    /* Files present here:
         {BASE}file
         {BASE}file2
         {BASE}link1 -> {BASE}file
         {BASE}link3 -> {BASE}nowhere
         {BASE}dir/
     */
    {
      ASSERT (func (BASE "file2", BASE "link3") == 0);
      errno = 0;
      ASSERT (stat (BASE "file2", &st) == -1);
      ASSERT (errno == ENOENT);
      memset (&st, 0, sizeof st);
      ASSERT (lstat (BASE "link3", &st) == 0);
      ASSERT (S_ISREG (st.st_mode));
    }
    /* Files present here:
         {BASE}file
         {BASE}link1 -> {BASE}file
         {BASE}link3
         {BASE}dir/
     */
    ASSERT (unlink (BASE "link3") == 0);
  }
  /* Files present here:
       {BASE}file
       {BASE}link1 -> {BASE}file
       {BASE}dir/
   */
  { /* Link onto file.  */
    ASSERT (symlink (BASE "nowhere", BASE "link2") == 0);
    /* Files present here:
         {BASE}file
         {BASE}link1 -> {BASE}file
         {BASE}link2 -> {BASE}nowhere
         {BASE}dir/
     */
    ASSERT (close (creat (BASE "file2", 0600)) == 0);
    /* Files present here:
         {BASE}file
         {BASE}file2
         {BASE}link1 -> {BASE}file
         {BASE}link2 -> {BASE}nowhere
         {BASE}dir/
     */
    {
      ASSERT (func (BASE "link2", BASE "file2") == 0);
      errno = 0;
      ASSERT (lstat (BASE "link2", &st) == -1);
      ASSERT (errno == ENOENT);
      memset (&st, 0, sizeof st);
      ASSERT (lstat (BASE "file2", &st) == 0);
      ASSERT (S_ISLNK (st.st_mode));
    }
    /* Files present here:
         {BASE}file
         {BASE}file2 -> {BASE}nowhere
         {BASE}link1 -> {BASE}file
         {BASE}dir/
     */
    ASSERT (unlink (BASE "file2") == 0);
  }
  /* Files present here:
       {BASE}file
       {BASE}link1 -> {BASE}file
       {BASE}dir/
   */
  { /* Trailing slash.  */
    {
      errno = 0;
      ASSERT (func (BASE "file/", BASE "link1") == -1);
      ASSERT (errno == ENOTDIR);
    }
    {
      errno = 0;
      ASSERT (func (BASE "file", BASE "link1/") == -1);
      ASSERT (errno == ENOTDIR || errno == ENOENT);
    }
    {
      errno = 0;
      ASSERT (func (BASE "link1/", BASE "file") == -1);
      ASSERT (errno == ENOTDIR);
    }
    {
      errno = 0;
      ASSERT (func (BASE "link1", BASE "file/") == -1);
      ASSERT (errno == ENOTDIR || errno == ENOENT);
      memset (&st, 0, sizeof st);
      ASSERT (lstat (BASE "file", &st) == 0);
      ASSERT (S_ISREG (st.st_mode));
      memset (&st, 0, sizeof st);
      ASSERT (lstat (BASE "link1", &st) == 0);
      ASSERT (S_ISLNK (st.st_mode));
    }
  }
  /* Files present here:
       {BASE}file
       {BASE}link1 -> {BASE}file
       {BASE}dir/
   */

  /* Mixing symlink and directory.  */

  { /* Directory onto link.  */
    {
      errno = 0;
      ASSERT (func (BASE "dir", BASE "link1") == -1);
      ASSERT (errno == ENOTDIR);
    }
    {
      errno = 0;
      ASSERT (func (BASE "dir/", BASE "link1") == -1);
      ASSERT (errno == ENOTDIR);
    }
    {
      errno = 0;
      ASSERT (func (BASE "dir", BASE "link1/") == -1);
      ASSERT (errno == ENOTDIR);
    }
  }
  { /* Link onto directory.  */
    {
      errno = 0;
      ASSERT (func (BASE "link1", BASE "dir") == -1);
      ASSERT (errno == EISDIR || errno == ENOTDIR);
    }
    {
      errno = 0;
      ASSERT (func (BASE "link1", BASE "dir/") == -1);
      ASSERT (errno == EISDIR || errno == ENOTDIR);
    }
    {
      errno = 0;
      ASSERT (func (BASE "link1/", BASE "dir") == -1);
      ASSERT (errno == ENOTDIR);
      memset (&st, 0, sizeof st);
      ASSERT (lstat (BASE "link1", &st) == 0);
      ASSERT (S_ISLNK (st.st_mode));
      memset (&st, 0, sizeof st);
      ASSERT (lstat (BASE "dir", &st) == 0);
      ASSERT (S_ISDIR (st.st_mode));
    }
  }
  /* Files present here:
       {BASE}file
       {BASE}link1 -> {BASE}file
       {BASE}dir/
   */

  /* POSIX requires rename("link-to-dir/","other") to rename "dir" and
     leave "link-to-dir" dangling, but GNU rejects this.  POSIX
     requires rename("dir","dangling/") to create the directory so
     that "dangling/" now resolves, but GNU rejects this.  While we
     prefer GNU behavior, we don't enforce it.  However, we do test
     that the system either follows POSIX in both cases, or follows
     GNU.  */
  {
    int result;
    ASSERT (symlink (BASE "dir2", BASE "link2") == 0);
    /* Files present here:
         {BASE}file
         {BASE}link1 -> {BASE}file
         {BASE}link2 -> {BASE}dir2
         {BASE}dir/
     */
    errno = 0;
    result = func (BASE "dir", BASE "link2/");
    if (result == 0)
      {
        /* POSIX.  */
        errno = 0;
        ASSERT (lstat (BASE "dir", &st) == -1);
        ASSERT (errno == ENOENT);
        memset (&st, 0, sizeof st);
        ASSERT (lstat (BASE "dir2", &st) == 0);
        ASSERT (S_ISDIR (st.st_mode));
        memset (&st, 0, sizeof st);
        ASSERT (lstat (BASE "link2", &st) == 0);
        ASSERT (S_ISLNK (st.st_mode));
        /* Files present here:
             {BASE}file
             {BASE}link1 -> {BASE}file
             {BASE}link2 -> {BASE}dir2
             {BASE}dir2/
         */
        {
          ASSERT (func (BASE "link2/", BASE "dir") == 0);
          memset (&st, 0, sizeof st);
          ASSERT (lstat (BASE "dir", &st) == 0);
          ASSERT (S_ISDIR (st.st_mode));
          errno = 0;
          ASSERT (lstat (BASE "dir2", &st) == -1);
          ASSERT (errno == ENOENT);
          memset (&st, 0, sizeof st);
          ASSERT (lstat (BASE "link2", &st) == 0);
          ASSERT (S_ISLNK (st.st_mode));
        }
      }
    else
      {
        /* GNU.  */
        ASSERT (result == -1);
        ASSERT (errno == ENOTDIR);
        memset (&st, 0, sizeof st);
        ASSERT (lstat (BASE "dir", &st) == 0);
        ASSERT (S_ISDIR (st.st_mode));
        errno = 0;
        ASSERT (lstat (BASE "dir2", &st) == -1);
        ASSERT (errno == ENOENT);
        memset (&st, 0, sizeof st);
        ASSERT (lstat (BASE "link2", &st) == 0);
        ASSERT (S_ISLNK (st.st_mode));
        ASSERT (unlink (BASE "link2") == 0);
        ASSERT (symlink (BASE "dir", BASE "link2") == 0);
        /* Files present here:
             {BASE}file
             {BASE}link1 -> {BASE}file
             {BASE}link2 -> {BASE}dir
             {BASE}dir/
         */
        errno = 0; /* OpenBSD notices that link2/ and dir are the same.  */
        result = func (BASE "link2/", BASE "dir");
        if (result) /* GNU/Linux rejects attempts to use link2/.  */
          {
            ASSERT (result == -1);
            ASSERT (errno == ENOTDIR || errno == EISDIR);
          }
        memset (&st, 0, sizeof st);
        ASSERT (lstat (BASE "dir", &st) == 0);
        ASSERT (S_ISDIR (st.st_mode));
        errno = 0;
        ASSERT (lstat (BASE "dir2", &st) == -1);
        ASSERT (errno == ENOENT);
        memset (&st, 0, sizeof st);
        ASSERT (lstat (BASE "link2", &st) == 0);
        ASSERT (S_ISLNK (st.st_mode));
      }
  }
  /* Files present here:
       {BASE}file
       {BASE}link1 -> {BASE}file
       {BASE}link2 -> {BASE}dir or {BASE}dir2
       {BASE}dir/
   */

  /* Clean up.  */
  ASSERT (unlink (BASE "file") == 0);
  ASSERT (rmdir (BASE "dir") == 0);
  ASSERT (unlink (BASE "link1") == 0);
  ASSERT (unlink (BASE "link2") == 0);

  return 0;
}
