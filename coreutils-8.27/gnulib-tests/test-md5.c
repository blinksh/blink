/*
 * Copyright (C) 2005, 2009-2017 Free Software Foundation, Inc.
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

/* Written by Simon Josefsson. */

#include <config.h>

#include <stdio.h>
#include <string.h>

#include "md5.h"

int
main (void)
{
  /* Test vectors from RFC 1321. */

  const char *in1 = "abc";
  const char *out1 =
    "\x90\x01\x50\x98\x3C\xD2\x4F\xB0\xD6\x96\x3F\x7D\x28\xE1\x7F\x72";
  const char *in2 = "message digest";
  const char *out2 =
    "\xF9\x6B\x69\x7D\x7C\xB7\x93\x8D\x52\x5A\x2F\x31\xAA\xF1\x61\xD0";
  char buf[MD5_DIGEST_SIZE];

  if (memcmp (md5_buffer (in1, strlen (in1), buf), out1, MD5_DIGEST_SIZE) != 0)
    {
      size_t i;
      printf ("expected:\n");
      for (i = 0; i < MD5_DIGEST_SIZE; i++)
        printf ("%02x ", out1[i] & 0xFFu);
      printf ("\ncomputed:\n");
      for (i = 0; i < MD5_DIGEST_SIZE; i++)
        printf ("%02x ", buf[i] & 0xFFu);
      printf ("\n");
      return 1;
    }

  if (memcmp (md5_buffer (in2, strlen (in2), buf), out2, MD5_DIGEST_SIZE) != 0)
    {
      size_t i;
      printf ("expected:\n");
      for (i = 0; i < MD5_DIGEST_SIZE; i++)
        printf ("%02x ", out2[i] & 0xFFu);
      printf ("\ncomputed:\n");
      for (i = 0; i < MD5_DIGEST_SIZE; i++)
        printf ("%02x ", buf[i] & 0xFFu);
      printf ("\n");
      return 1;
    }

  return 0;
}
