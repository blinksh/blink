/* Test of execution of file name canonicalization.
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

/* Written by Bruno Haible <bruno@clisp.org>, 2007.  */

#include <config.h>

#include "canonicalize.h"

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include "same-inode.h"
#include "ignore-value.h"

#include "null-ptr.h"
#include "macros.h"

#define BASE "t-can.tmp"

int
main (void)
{
  /* Setup some hierarchy to be used by this test.  Start by removing
     any leftovers from a previous partial run.  */
  {
    int fd;
    ignore_value (system ("rm -rf " BASE " ise"));
    ASSERT (mkdir (BASE, 0700) == 0);
    fd = creat (BASE "/tra", 0600);
    ASSERT (0 <= fd);
    ASSERT (close (fd) == 0);
  }

  /* Check for ., .., intermediate // handling, and for error cases.  */
  {
    char *result1 = canonicalize_file_name (BASE "//./..//" BASE "/tra");
    char *result2 = canonicalize_filename_mode (BASE "//./..//" BASE "/tra",
                                                CAN_EXISTING);
    ASSERT (result1 != NULL);
    ASSERT (result2 != NULL);
    ASSERT (strcmp (result1, result2) == 0);
    ASSERT (strstr (result1, "/" BASE "/tra")
            == result1 + strlen (result1) - strlen ("/" BASE "/tra"));
    free (result1);
    free (result2);
    errno = 0;
    result1 = canonicalize_file_name ("");
    ASSERT (result1 == NULL);
    ASSERT (errno == ENOENT);
    errno = 0;
    result2 = canonicalize_filename_mode ("", CAN_EXISTING);
    ASSERT (result2 == NULL);
    ASSERT (errno == ENOENT);
    errno = 0;
    result1 = canonicalize_file_name (null_ptr ());
    ASSERT (result1 == NULL);
    ASSERT (errno == EINVAL);
    errno = 0;
    result2 = canonicalize_filename_mode (NULL, CAN_EXISTING);
    ASSERT (result2 == NULL);
    ASSERT (errno == EINVAL);
    result2 = canonicalize_filename_mode (".", CAN_MISSING | CAN_ALL_BUT_LAST);
    ASSERT (result2 == NULL);
    ASSERT (errno == EINVAL);
  }

  /* Check that a non-directory with trailing slash yields NULL.  */
  {
    char *result1;
    char *result2;
    errno = 0;
    result1 = canonicalize_file_name (BASE "/tra/");
    ASSERT (result1 == NULL);
    ASSERT (errno == ENOTDIR);
    errno = 0;
    result2 = canonicalize_filename_mode (BASE "/tra/", CAN_EXISTING);
    ASSERT (result2 == NULL);
    ASSERT (errno == ENOTDIR);
  }

  /* Check that a missing directory yields NULL.  */
  {
    char *result1;
    char *result2;
    errno = 0;
    result1 = canonicalize_file_name (BASE "/zzz/..");
    ASSERT (result1 == NULL);
    ASSERT (errno == ENOENT);
    errno = 0;
    result2 = canonicalize_filename_mode (BASE "/zzz/..", CAN_EXISTING);
    ASSERT (result2 == NULL);
    ASSERT (errno == ENOENT);
  }

  /* From here on out, tests involve symlinks.  */
  if (symlink (BASE "/ket", "ise") != 0)
    {
      ASSERT (remove (BASE "/tra") == 0);
      ASSERT (rmdir (BASE) == 0);
      fputs ("skipping test: symlinks not supported on this file system\n",
             stderr);
      return 77;
    }
  ASSERT (symlink ("bef", BASE "/plo") == 0);
  ASSERT (symlink ("tra", BASE "/huk") == 0);
  ASSERT (symlink ("lum", BASE "/bef") == 0);
  ASSERT (symlink ("wum", BASE "/ouk") == 0);
  ASSERT (symlink ("../ise", BASE "/ket") == 0);
  ASSERT (mkdir (BASE "/lum", 0700) == 0);
  ASSERT (symlink ("s", BASE "/p") == 0);
  ASSERT (symlink ("d", BASE "/s") == 0);
  ASSERT (mkdir (BASE "/d", 0700) == 0);
  ASSERT (close (creat (BASE "/d/2", 0600)) == 0);
  ASSERT (symlink ("../s/2", BASE "/d/1") == 0);
  ASSERT (symlink ("//.//../..", BASE "/droot") == 0);

  /* Check that symbolic links are not resolved, with CAN_NOLINKS.  */
  {
    char *result1 = canonicalize_filename_mode (BASE "/huk", CAN_NOLINKS);
    ASSERT (result1 != NULL);
    ASSERT (strcmp (result1 + strlen (result1) - strlen ("/" BASE "/huk"),
                    "/" BASE "/huk") == 0);
    free (result1);
  }

  /* Check that the symbolic link to a file can be resolved.  */
  {
    char *result1 = canonicalize_file_name (BASE "/huk");
    char *result2 = canonicalize_file_name (BASE "/tra");
    char *result3 = canonicalize_filename_mode (BASE "/huk", CAN_EXISTING);
    ASSERT (result1 != NULL);
    ASSERT (result2 != NULL);
    ASSERT (result3 != NULL);
    ASSERT (strcmp (result1, result2) == 0);
    ASSERT (strcmp (result2, result3) == 0);
    ASSERT (strcmp (result1 + strlen (result1) - strlen ("/" BASE "/tra"),
                    "/" BASE "/tra") == 0);
    free (result1);
    free (result2);
    free (result3);
  }

  /* Check that the symbolic link to a directory can be resolved.  */
  {
    char *result1 = canonicalize_file_name (BASE "/plo");
    char *result2 = canonicalize_file_name (BASE "/bef");
    char *result3 = canonicalize_file_name (BASE "/lum");
    char *result4 = canonicalize_filename_mode (BASE "/plo", CAN_EXISTING);
    ASSERT (result1 != NULL);
    ASSERT (result2 != NULL);
    ASSERT (result3 != NULL);
    ASSERT (result4 != NULL);
    ASSERT (strcmp (result1, result2) == 0);
    ASSERT (strcmp (result2, result3) == 0);
    ASSERT (strcmp (result3, result4) == 0);
    ASSERT (strcmp (result1 + strlen (result1) - strlen ("/" BASE "/lum"),
                    "/" BASE "/lum") == 0);
    free (result1);
    free (result2);
    free (result3);
    free (result4);
  }

  /* Check that a symbolic link to a nonexistent file yields NULL.  */
  {
    char *result1;
    char *result2;
    errno = 0;
    result1 = canonicalize_file_name (BASE "/ouk");
    ASSERT (result1 == NULL);
    ASSERT (errno == ENOENT);
    errno = 0;
    result2 = canonicalize_filename_mode (BASE "/ouk", CAN_EXISTING);
    ASSERT (result2 == NULL);
    ASSERT (errno == ENOENT);
  }

  /* Check that a non-directory symlink with trailing slash yields NULL.  */
  {
    char *result1;
    char *result2;
    errno = 0;
    result1 = canonicalize_file_name (BASE "/huk/");
    ASSERT (result1 == NULL);
    ASSERT (errno == ENOTDIR);
    errno = 0;
    result2 = canonicalize_filename_mode (BASE "/huk/", CAN_EXISTING);
    ASSERT (result2 == NULL);
    ASSERT (errno == ENOTDIR);
  }

  /* Check that a missing directory via symlink yields NULL.  */
  {
    char *result1;
    char *result2;
    errno = 0;
    result1 = canonicalize_file_name (BASE "/ouk/..");
    ASSERT (result1 == NULL);
    ASSERT (errno == ENOENT);
    errno = 0;
    result2 = canonicalize_filename_mode (BASE "/ouk/..", CAN_EXISTING);
    ASSERT (result2 == NULL);
    ASSERT (errno == ENOENT);
  }

  /* Check that a loop of symbolic links is detected.  */
  {
    char *result1;
    char *result2;
    errno = 0;
    result1 = canonicalize_file_name ("ise");
    ASSERT (result1 == NULL);
    ASSERT (errno == ELOOP);
    errno = 0;
    result2 = canonicalize_filename_mode ("ise", CAN_EXISTING);
    ASSERT (result2 == NULL);
    ASSERT (errno == ELOOP);
  }

  /* Check that alternate modes can resolve missing basenames.  */
  {
    char *result1 = canonicalize_filename_mode (BASE "/zzz", CAN_ALL_BUT_LAST);
    char *result2 = canonicalize_filename_mode (BASE "/zzz", CAN_MISSING);
    char *result3 = canonicalize_filename_mode (BASE "/zzz/", CAN_ALL_BUT_LAST);
    char *result4 = canonicalize_filename_mode (BASE "/zzz/", CAN_MISSING);
    ASSERT (result1 != NULL);
    ASSERT (result2 != NULL);
    ASSERT (result3 != NULL);
    ASSERT (result4 != NULL);
    ASSERT (strcmp (result1, result2) == 0);
    ASSERT (strcmp (result2, result3) == 0);
    ASSERT (strcmp (result3, result4) == 0);
    ASSERT (strcmp (result1 + strlen (result1) - strlen ("/" BASE "/zzz"),
                    "/" BASE "/zzz") == 0);
    free (result1);
    free (result2);
    free (result3);
    free (result4);
  }

  /* Check that alternate modes can resolve broken symlink basenames.  */
  {
    char *result1 = canonicalize_filename_mode (BASE "/ouk", CAN_ALL_BUT_LAST);
    char *result2 = canonicalize_filename_mode (BASE "/ouk", CAN_MISSING);
    char *result3 = canonicalize_filename_mode (BASE "/ouk/", CAN_ALL_BUT_LAST);
    char *result4 = canonicalize_filename_mode (BASE "/ouk/", CAN_MISSING);
    ASSERT (result1 != NULL);
    ASSERT (result2 != NULL);
    ASSERT (result3 != NULL);
    ASSERT (result4 != NULL);
    ASSERT (strcmp (result1, result2) == 0);
    ASSERT (strcmp (result2, result3) == 0);
    ASSERT (strcmp (result3, result4) == 0);
    ASSERT (strcmp (result1 + strlen (result1) - strlen ("/" BASE "/wum"),
                    "/" BASE "/wum") == 0);
    free (result1);
    free (result2);
    free (result3);
    free (result4);
  }

  /* Check that alternate modes can handle missing dirnames.  */
  {
    char *result1 = canonicalize_filename_mode ("t-can.zzz/zzz", CAN_ALL_BUT_LAST);
    char *result2 = canonicalize_filename_mode ("t-can.zzz/zzz", CAN_MISSING);
    ASSERT (result1 == NULL);
    ASSERT (result2 != NULL);
    ASSERT (strcmp (result2 + strlen (result2) - 14, "/t-can.zzz/zzz") == 0);
    free (result2);
  }

  /* Ensure that the following is resolved properly.
     Before 2007-09-27, it would mistakenly report a loop.  */
  {
    char *result1 = canonicalize_filename_mode (BASE, CAN_EXISTING);
    char *result2 = canonicalize_filename_mode (BASE "/p/1", CAN_EXISTING);
    ASSERT (result1 != NULL);
    ASSERT (result2 != NULL);
    ASSERT (strcmp (result2 + strlen (result1), "/d/2") == 0);
    free (result1);
    free (result2);
  }

  /* Check that leading // is honored correctly.  */
  {
    struct stat st1;
    struct stat st2;
    char *result1 = canonicalize_file_name ("//.");
    char *result2 = canonicalize_filename_mode ("//.", CAN_EXISTING);
    char *result3 = canonicalize_file_name (BASE "/droot");
    char *result4 = canonicalize_filename_mode (BASE "/droot", CAN_EXISTING);
    ASSERT (result1);
    ASSERT (result2);
    ASSERT (result3);
    ASSERT (result4);
    ASSERT (stat ("/", &st1) == 0);
    ASSERT (stat ("//", &st2) == 0);
    if (SAME_INODE (st1, st2))
      {
        ASSERT (strcmp (result1, "/") == 0);
        ASSERT (strcmp (result2, "/") == 0);
        ASSERT (strcmp (result3, "/") == 0);
        ASSERT (strcmp (result4, "/") == 0);
      }
    else
      {
        ASSERT (strcmp (result1, "//") == 0);
        ASSERT (strcmp (result2, "//") == 0);
        ASSERT (strcmp (result3, "//") == 0);
        ASSERT (strcmp (result4, "//") == 0);
      }
    free (result1);
    free (result2);
    free (result3);
    free (result4);
  }

  /* Cleanup.  */
  ASSERT (remove (BASE "/droot") == 0);
  ASSERT (remove (BASE "/d/1") == 0);
  ASSERT (remove (BASE "/d/2") == 0);
  ASSERT (remove (BASE "/d") == 0);
  ASSERT (remove (BASE "/s") == 0);
  ASSERT (remove (BASE "/p") == 0);
  ASSERT (remove (BASE "/plo") == 0);
  ASSERT (remove (BASE "/huk") == 0);
  ASSERT (remove (BASE "/bef") == 0);
  ASSERT (remove (BASE "/ouk") == 0);
  ASSERT (remove (BASE "/ket") == 0);
  ASSERT (remove (BASE "/lum") == 0);
  ASSERT (remove (BASE "/tra") == 0);
  ASSERT (remove (BASE) == 0);
  ASSERT (remove ("ise") == 0);

  return 0;
}
