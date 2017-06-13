/* base32.h -- Encode binary data using printable characters.
   Copyright (C) 2004-2006, 2009-2017 Free Software Foundation, Inc.
   Adapted from Simon Josefsson's base64 code by Gijs van Tulder.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, see <http://www.gnu.org/licenses/>.  */

#ifndef BASE32_H
# define BASE32_H

/* Get size_t. */
# include <stddef.h>

/* Get bool. */
# include <stdbool.h>

/* This uses that the expression (n+(k-1))/k means the smallest
   integer >= n/k, i.e., the ceiling of n/k.  */
# define BASE32_LENGTH(inlen) ((((inlen) + 4) / 5) * 8)

struct base32_decode_context
{
  unsigned int i;
  char buf[8];
};

extern bool isbase32 (char ch) _GL_ATTRIBUTE_CONST;

extern void base32_encode (const char *restrict in, size_t inlen,
                           char *restrict out, size_t outlen);

extern size_t base32_encode_alloc (const char *in, size_t inlen, char **out);

extern void base32_decode_ctx_init (struct base32_decode_context *ctx);

extern bool base32_decode_ctx (struct base32_decode_context *ctx,
                               const char *restrict in, size_t inlen,
                               char *restrict out, size_t *outlen);

extern bool base32_decode_alloc_ctx (struct base32_decode_context *ctx,
                                     const char *in, size_t inlen,
                                     char **out, size_t *outlen);

#define base32_decode(in, inlen, out, outlen) \
        base32_decode_ctx (NULL, in, inlen, out, outlen)

#define base32_decode_alloc(in, inlen, out, outlen) \
        base32_decode_alloc_ctx (NULL, in, inlen, out, outlen)

#endif /* BASE32_H */
