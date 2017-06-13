/* Tests of utimens.
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

#include "utimens.h"

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#include "ignore-value.h"
#include "macros.h"

#define BASE "test-utimens.t"

#include "test-futimens.h"
#include "test-lutimens.h"
#include "test-utimens.h"

/* Wrap fdutimens to behave like futimens.  */
static int
do_futimens (int fd, struct timespec const times[2])
{
  return fdutimens (fd, NULL, times);
}

/* Test the use of file descriptors alongside a name.  */
static int
do_fdutimens (char const *name, struct timespec const times[2])
{
  int result;
  int fd = open (name, O_WRONLY);
  if (fd < 0)
    fd = open (name, O_RDONLY);
  errno = 0;
  result = fdutimens (fd, name, times);
  if (0 <= fd)
    {
      int saved_errno = errno;
      close (fd);
      errno = saved_errno;
    }
  return result;
}

int
main (void)
{
  int result1; /* Skip because of no symlink support.  */
  int result2; /* Skip because of no futimens support.  */
  int result3; /* Skip because of no lutimens support.  */

  /* Clean up any trash from prior testsuite runs.  */
  ignore_value (system ("rm -rf " BASE "*"));

  result1 = test_utimens (utimens, true);
  ASSERT (test_utimens (do_fdutimens, false) == result1);
  /* Print only one skip message.  */
  result2 = test_futimens (do_futimens, result1 == 0);
  result3 = test_lutimens (lutimens, (result1 + result2) == 0);
  /* We expect 0/0, 0/77, or 77/77, but not 77/0.  */
  ASSERT (result1 <= result3);
  return result1 | result2 | result3;
}
