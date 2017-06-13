/* Test of concatenation of two arbitrary file names.

   Copyright (C) 1996-2007, 2009-2017 Free Software Foundation, Inc.

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

/* Written by Jim Meyering.  */

#include <config.h>

#include "filenamecat.h"

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


int
main (int argc _GL_UNUSED, char *argv[])
{
  static char const *const tests[][3] =
    {
      {"a", "b",   "a/b"},
      {"a/", "b",  "a/b"},
      {"a/", "/b", "a/b"},
      {"a", "/b",  "a/b"},

      {"/", "b",  "/b"},
      {"/", "/b", "/b"},
      {"/", "/",  "/"},
      {"a", "/",  "a/"},   /* this might deserve a diagnostic */
      {"/a", "/", "/a/"},  /* this might deserve a diagnostic */
      {"a", "//b",  "a/b"},
      {"", "a", "a"},  /* this might deserve a diagnostic */
    };
  unsigned int i;
  bool fail = false;

  for (i = 0; i < sizeof tests / sizeof tests[0]; i++)
    {
      char *base_in_result;
      char const *const *t = tests[i];
      char *res = file_name_concat (t[0], t[1], &base_in_result);
      if (strcmp (res, t[2]) != 0)
        {
          fprintf (stderr, "test #%u: got %s, expected %s\n", i, res, t[2]);
          fail = true;
        }
    }
  exit (fail ? EXIT_FAILURE : EXIT_SUCCESS);
}
