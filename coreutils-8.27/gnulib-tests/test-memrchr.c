/*
 * Copyright (C) 2008-2017 Free Software Foundation, Inc.
 * Written by Eric Blake and Bruno Haible
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

#include <string.h>

#include "signature.h"
SIGNATURE_CHECK (memrchr, void *, (void const *, int, size_t));

#include <stdlib.h>

#include "zerosize-ptr.h"
#include "macros.h"

/* Calculating void * + int is not portable, so this wrapper converts
   to char * to make the tests easier to write.  */
#define MEMRCHR (char *) memrchr

int
main (void)
{
  size_t n = 0x100000;
  char *input = malloc (n);
  ASSERT (input);

  input[n - 1] = 'a';
  input[n - 2] = 'b';
  memset (input + n - 1026, 'c', 1024);
  memset (input + 2, 'd', n - 1028);
  input[1] = 'e';
  input[0] = 'a';

  /* Basic behavior tests.  */
  ASSERT (MEMRCHR (input, 'a', n) == input + n - 1);

  ASSERT (MEMRCHR (input, 'a', 0) == NULL);
  ASSERT (MEMRCHR (zerosize_ptr (), 'a', 0) == NULL);

  ASSERT (MEMRCHR (input, 'b', n) == input + n - 2);
  ASSERT (MEMRCHR (input, 'c', n) == input + n - 3);
  ASSERT (MEMRCHR (input, 'd', n) == input + n - 1027);

  ASSERT (MEMRCHR (input, 'a', n - 1) == input);
  ASSERT (MEMRCHR (input, 'e', n - 1) == input + 1);

  ASSERT (MEMRCHR (input, 'f', n) == NULL);
  ASSERT (MEMRCHR (input, '\0', n) == NULL);

  /* Check that a very long haystack is handled quickly if the byte is
     found near the end.  */
  {
    size_t repeat = 10000;
    for (; repeat > 0; repeat--)
      {
        ASSERT (MEMRCHR (input, 'c', n) == input + n - 3);
      }
  }

  /* Alignment tests.  */
  {
    int i, j;
    for (i = 0; i < 32; i++)
      {
        for (j = 0; j < 256; j++)
          input[i + j] = j;
        for (j = 0; j < 256; j++)
          {
            ASSERT (MEMRCHR (input + i, j, 256) == input + i + j);
          }
      }
  }

  free (input);

  return 0;
}
