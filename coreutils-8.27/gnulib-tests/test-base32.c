/* Self tests for base32.
   Copyright (C) 2004, 2008-2017 Free Software Foundation, Inc.
   Based on the tests for base64 written by Simon Josefsson.
   Adapted for base32 by Gijs van Tulder.

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

#include <config.h>

#include "base32.h"

#include <stddef.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include "macros.h"

int
main (void)
{
  const char *in = "abcdefghijklmnop";
  const char *b32in = "MFRGGZDFMZTWQ2LKNNWG23TPOA======";
  char out[255];
  size_t len;
  bool ok;
  char *p;

  memset (out, 0x42, sizeof (out));
  base32_encode (in, 0, out, 0);
  ASSERT (out[0] == '\x42');

  memset (out, 0x42, sizeof (out));
  base32_encode (in, 1, out, 10);
  ASSERT (memcmp (out, "ME======", 1) == 0);

  memset (out, 0x42, sizeof (out));
  base32_encode (in, 1, out, 2);
  ASSERT (memcmp (out, "ME======", 2) == 0);

  memset (out, 0x42, sizeof (out));
  base32_encode (in, 1, out, 3);
  ASSERT (memcmp (out, "ME======", 3) == 0);

  memset (out, 0x42, sizeof (out));
  base32_encode (in, 1, out, 4);
  ASSERT (memcmp (out, "ME======", 4) == 0);

  memset (out, 0x42, sizeof (out));
  base32_encode (in, 1, out, 8);
  ASSERT (memcmp (out, "ME======", 8) == 0);

  memset (out, 0x42, sizeof (out));
  base32_encode (in, 2, out, 8);
  ASSERT (memcmp (out, "MFRA====", 8) == 0);

  memset (out, 0x42, sizeof (out));
  base32_encode (in, 3, out, 8);
  ASSERT (memcmp (out, "MFRGG===", 8) == 0);

  memset (out, 0x42, sizeof (out));
  base32_encode (in, 4, out, 8);
  ASSERT (memcmp (out, "MFRGGZA=", 8) == 0);

  memset (out, 0x42, sizeof (out));
  base32_encode (in, 5, out, 8);
  ASSERT (memcmp (out, "MFRGGZDF", 8) == 0);

  memset (out, 0x42, sizeof (out));
  base32_encode (in, 6, out, 16);
  ASSERT (memcmp (out, "MFRGGZDFMY======", 16) == 0);

  memset (out, 0x42, sizeof (out));
  base32_encode (in, 6, out, 100);
  ASSERT (memcmp (out, "MFRGGZDFMY======", 16) == 0);

  /* Decode. */

  memset (out, 0x42, sizeof (out));
  len = 0;
  ok = base32_decode (b32in, 8, out, &len);
  ASSERT (ok);
  ASSERT (len == 0);

  memset (out, 0x42, sizeof (out));
  len = 1;
  ok = base32_decode (b32in, 8, out, &len);
  ASSERT (ok);
  ASSERT (len == 1);
  ASSERT (memcmp (out, "abcdefghijklmnop", 1) == 0);

  memset (out, 0x42, sizeof (out));
  len = 2;
  ok = base32_decode (b32in, 8, out, &len);
  ASSERT (ok);
  ASSERT (len == 2);
  ASSERT (memcmp (out, "abcdefghijklmnop", 2) == 0);

  memset (out, 0x42, sizeof (out));
  len = 3;
  ok = base32_decode (b32in, 8, out, &len);
  ASSERT (ok);
  ASSERT (len == 3);
  ASSERT (memcmp (out, "abcdefghijklmnop", 3) == 0);

  memset (out, 0x42, sizeof (out));
  len = 4;
  ok = base32_decode (b32in, 8, out, &len);
  ASSERT (ok);
  ASSERT (len == 4);
  ASSERT (memcmp (out, "abcdefghijklmnop", 4) == 0);

  memset (out, 0x42, sizeof (out));
  len = 5;
  ok = base32_decode (b32in, 8, out, &len);
  ASSERT (ok);
  ASSERT (len == 5);
  ASSERT (memcmp (out, "abcdefghijklmnop", 5) == 0);

  memset (out, 0x42, sizeof (out));
  len = 6;
  ok = base32_decode (b32in, 8, out, &len);
  ASSERT (ok);
  ASSERT (len == 5);
  ASSERT (memcmp (out, "abcdefghijklmnop", 5) == 0);

  memset (out, 0x42, sizeof (out));
  len = 100;
  ok = base32_decode (b32in, strlen (b32in), out, &len);
  ASSERT (ok);
  ASSERT (len == 16);
  ASSERT (memcmp (out, "abcdefghijklmnop", 16) == 0);

  /* Allocating encode */

  len = base32_encode_alloc (in, strlen (in), &p);
  ASSERT (len == 32);
  ASSERT (strcmp (p, "MFRGGZDFMZTWQ2LKNNWG23TPOA======") == 0);
  free (p);

  len = base32_encode_alloc (in, SIZE_MAX - 5, &p);
  ASSERT (len == 0);

  /* Decode context function */
  {
    struct base32_decode_context ctx;

    base32_decode_ctx_init (&ctx);

    len = sizeof (out);
    ok = base32_decode_ctx (&ctx, b32in, strlen (b32in), out, &len);
    ASSERT (ok);
    ASSERT (len == 16);
    ASSERT (memcmp (out, "abcdefghijklmnop", len) == 0);
  }

  /* Allocating decode context function */

  ok = base32_decode_alloc_ctx (NULL, b32in, strlen (b32in), &p, &len);
  ASSERT (ok);
  ASSERT (len == 16);
  ASSERT (memcmp (out, "abcdefghijklmnop", len) == 0);
  free (p);

  {
    struct base32_decode_context ctx;
    const char *newlineb32 = "MFRG\nGZDFMZTWQ2LKNNW\nG23TPOA======";

    base32_decode_ctx_init (&ctx);

    ok = base32_decode_alloc_ctx (&ctx, newlineb32, strlen (newlineb32), &p, &len);
    ASSERT (ok);
    ASSERT (len == strlen (in));
    ASSERT (memcmp (p, in, len) == 0);
    free (p);
  }

  {
    struct base32_decode_context ctx;
    base32_decode_ctx_init (&ctx);

    ok = base32_decode_alloc_ctx (&ctx, "MFRGGZDFM\nZTWQ2LK", 17, &p, &len);
    ASSERT (ok);
    ASSERT (len == 10);
    ASSERT (memcmp (p, "abcdefghij", len) == 0);
    free (p);

    base32_decode_ctx_init (&ctx);

    ok = base32_decode_alloc_ctx (&ctx, "MF\n", 3, &p, &len);
    ASSERT (ok);
    ASSERT (len == 0);
    free (p);

    ok = base32_decode_alloc_ctx (&ctx, "RGGZDFMZ", 8, &p, &len);
    ASSERT (ok);
    ASSERT (len == 5);
    ASSERT (memcmp (p, "abcde", len) == 0);
    free (p);

    ok = base32_decode_alloc_ctx (&ctx, "TWQ2LK", 6, &p, &len);
    ASSERT (ok);
    ASSERT (len == 5);
    ASSERT (memcmp (p, "fghij", len) == 0);
    free (p);

    ok = base32_decode_alloc_ctx (&ctx, "", 0, &p, &len);
    ASSERT (ok);
    free (p);
  }

  {
    struct base32_decode_context ctx;
    const char *newlineb32 = "\n\n\n\n\n";

    base32_decode_ctx_init (&ctx);

    ok = base32_decode_alloc_ctx (&ctx, newlineb32, strlen (newlineb32), &p, &len);
    ASSERT (ok);
    ASSERT (len == 0);
    free (p);
  }

  ok = base32_decode_alloc_ctx (NULL, " ! ", 3, &p, &len);
  ASSERT (!ok);

  ok = base32_decode_alloc_ctx (NULL, "ABC\nDEF", 7, &p, &len);
  ASSERT (!ok);

  ok = base32_decode_alloc_ctx (NULL, "AA", 2, &p, &len);
  ASSERT (!ok);

  ok = base32_decode_alloc_ctx (NULL, "AA=", 3, &p, &len);
  ASSERT (!ok);

  ok = base32_decode_alloc_ctx (NULL, "AABBAAxx", 8, &p, &len);
  ASSERT (!ok);

  ok = base32_decode_alloc_ctx (NULL, "AABBAA=X", 8, &p, &len);
  ASSERT (!ok);

  ok = base32_decode_alloc_ctx (NULL, "AABBAA=X", 8, &p, &len);
  ASSERT (!ok);

  ok = base32_decode_alloc_ctx (NULL, "AABBAA=A", 8, &p, &len);
  ASSERT (!ok);

  return 0;
}
