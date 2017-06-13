/*
 * Copyright (C) 2008-2017 Free Software Foundation, Inc.
 * Written by Simon Josefsson.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

#include <config.h>

/* Get gethostname() declaration.  */
#include <unistd.h>

#include "signature.h"
SIGNATURE_CHECK (gethostname, int, (char *, size_t));

/* Get HOST_NAME_MAX definition.  */
#include <limits.h>

#include <stdio.h>
#include <string.h>
#include <errno.h>

#define NOHOSTNAME "magic-gnulib-test-string"

int
main (int argc, char *argv[] _GL_UNUSED)
{
  char buf[HOST_NAME_MAX];
  int rc;

  if (strlen (NOHOSTNAME) >= HOST_NAME_MAX)
    {
      printf ("HOST_NAME_MAX impossibly small?! %d\n", HOST_NAME_MAX);
      return 2;
    }

  strcpy (buf, NOHOSTNAME);

  rc = gethostname (buf, sizeof (buf));

  if (rc != 0)
    {
      printf ("gethostname failed, rc %d errno %d\n", rc, errno);
      return 1;
    }

  if (strcmp (buf, NOHOSTNAME) == 0)
    {
      printf ("gethostname left buffer untouched.\n");
      return 1;
    }

  if (argc > 1)
    printf ("hostname: %s\n", buf);

  return 0;
}
