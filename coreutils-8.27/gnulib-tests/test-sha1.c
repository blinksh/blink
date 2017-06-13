/*
 * Copyright (C) 2005, 2008-2017 Free Software Foundation, Inc.
 * Written by Simon Josefsson
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

#include <stdio.h>
#include <string.h>

#include "sha1.h"

int
main (void)
{
  const char *in1 = "abcdefgh";
  const char *out1 = "\x42\x5a\xf1\x2a\x07\x43\x50\x2b"
    "\x32\x2e\x93\xa0\x15\xbc\xf8\x68\xe3\x24\xd5\x6a";
  char buf[SHA1_DIGEST_SIZE];

  if (memcmp (sha1_buffer (in1, strlen (in1), buf),
              out1, SHA1_DIGEST_SIZE) != 0)
    {
      size_t i;
      printf ("expected:\n");
      for (i = 0; i < SHA1_DIGEST_SIZE; i++)
        printf ("%02x ", out1[i] & 0xFFu);
      printf ("\ncomputed:\n");
      for (i = 0; i < SHA1_DIGEST_SIZE; i++)
        printf ("%02x ", buf[i] & 0xFFu);
      printf ("\n");
      return 1;
    }

  return 0;
}
