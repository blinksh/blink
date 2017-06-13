/* Test of reopening a stream.
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

/* Specification.  */
#include "stdio--.h"

/* Helpers.  */
#include <unistd.h>

/* This test intentionally closes stderr.  So, we arrange to have fd 10
   (outside the range of interesting fd's during the test) set up to
   duplicate the original stderr.  */

#define BACKUP_STDERR_FILENO 10
#define ASSERT_STREAM myerr
#include "macros.h"

static FILE *myerr;

int
main (void)
{
  FILE *fp;

  /* We close fd 2 later, so save it in fd 10.  */
  if (dup2 (STDERR_FILENO, BACKUP_STDERR_FILENO) != BACKUP_STDERR_FILENO
      || (myerr = fdopen (BACKUP_STDERR_FILENO, "w")) == NULL)
    return 2;

  {
    FILE *tmp;
    ASSERT (tmp = fopen ("/dev/null", "r"));
    ASSERT (STDERR_FILENO < fileno (tmp));
    ASSERT (fp = fopen ("/dev/null", "w"));
    ASSERT (fileno (tmp) < fileno (fp));
    ASSERT (fclose (tmp) == 0);
  }

  /* Gap in fds.  */
  ASSERT (freopen ("/dev/null", "r+", fp) == fp);
  ASSERT (STDERR_FILENO < fileno (fp));

  ASSERT (freopen ("/dev/null", "r", stdin) == stdin);
  ASSERT (STDIN_FILENO == fileno (stdin));

  ASSERT (freopen ("/dev/null", "w", stdout) == stdout);
  ASSERT (STDOUT_FILENO == fileno (stdout));

  ASSERT (freopen ("/dev/null", "w", stderr) == stderr);
  ASSERT (STDERR_FILENO == fileno (stderr));

  /* fd 0 closed.  */
  ASSERT (close (STDIN_FILENO) == 0);

  ASSERT (freopen ("/dev/null", "w", stdout) == stdout);
  ASSERT (STDOUT_FILENO == fileno (stdout));

  ASSERT (freopen ("/dev/null", "w", stderr) == stderr);
  ASSERT (STDERR_FILENO == fileno (stderr));

  ASSERT (freopen ("/dev/null", "a", fp) == fp);
  ASSERT (STDERR_FILENO < fileno (fp));

  /* fd 1 closed.  */
  ASSERT (close (STDOUT_FILENO) == 0);

  ASSERT (freopen ("/dev/null", "w", stderr) == stderr);
  ASSERT (STDERR_FILENO == fileno (stderr));

  ASSERT (freopen ("/dev/null", "a+", fp) == fp);
  ASSERT (STDERR_FILENO < fileno (fp));

  /* fd 2 closed.  */
  ASSERT (close (STDERR_FILENO) == 0);

  ASSERT (freopen ("/dev/null", "w+", fp) == fp);
  ASSERT (STDERR_FILENO < fileno (fp));

  return 0;
}
