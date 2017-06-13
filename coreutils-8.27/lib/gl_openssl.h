/* Wrap openssl crypto hash routines in gnulib interface.  -*- coding: utf-8 -*-

   Copyright (C) 2013-2017 Free Software Foundation, Inc.

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

/* Written by Pádraig Brady */

#ifndef GL_OPENSSL_NAME
# error "Please define GL_OPENSSL_NAME to 1,5,256 etc."
#endif

#ifndef _GL_INLINE_HEADER_BEGIN
# error "Please include config.h first."
#endif
_GL_INLINE_HEADER_BEGIN
#ifndef GL_OPENSSL_INLINE
# define GL_OPENSSL_INLINE _GL_INLINE
#endif

/* Concatenate two preprocessor tokens.  */
#define _GLCRYPTO_CONCAT_(prefix, suffix) prefix##suffix
#define _GLCRYPTO_CONCAT(prefix, suffix) _GLCRYPTO_CONCAT_ (prefix, suffix)

#if GL_OPENSSL_NAME == 5
# define OPENSSL_ALG md5
#else
# define OPENSSL_ALG _GLCRYPTO_CONCAT (sha, GL_OPENSSL_NAME)
#endif

/* Context type mappings.  */
#if BASE_OPENSSL_TYPE != GL_OPENSSL_NAME
# undef BASE_OPENSSL_TYPE
# if GL_OPENSSL_NAME == 224
#  define BASE_OPENSSL_TYPE 256
# elif GL_OPENSSL_NAME == 384
#  define BASE_OPENSSL_TYPE 512
# endif
# define md5_CTX MD5_CTX
# define sha1_CTX SHA_CTX
# define sha224_CTX SHA256_CTX
# define sha224_ctx sha256_ctx
# define sha256_CTX SHA256_CTX
# define sha384_CTX SHA512_CTX
# define sha384_ctx sha512_ctx
# define sha512_CTX SHA512_CTX
# undef _gl_CTX
# undef _gl_ctx
# define _gl_CTX _GLCRYPTO_CONCAT (OPENSSL_ALG, _CTX) /* openssl type.  */
# define _gl_ctx _GLCRYPTO_CONCAT (OPENSSL_ALG, _ctx) /* gnulib type.  */

struct _gl_ctx { _gl_CTX CTX; };
#endif

/* Function name mappings.  */
#define md5_prefix MD5
#define sha1_prefix SHA1
#define sha224_prefix SHA224
#define sha256_prefix SHA256
#define sha384_prefix SHA384
#define sha512_prefix SHA512
#define _GLCRYPTO_PREFIX _GLCRYPTO_CONCAT (OPENSSL_ALG, _prefix)
#define OPENSSL_FN(suffix) _GLCRYPTO_CONCAT (_GLCRYPTO_PREFIX, suffix)
#define GL_CRYPTO_FN(suffix) _GLCRYPTO_CONCAT (OPENSSL_ALG, suffix)

GL_OPENSSL_INLINE void
GL_CRYPTO_FN (_init_ctx) (struct _gl_ctx *ctx)
{ (void) OPENSSL_FN (_Init) ((_gl_CTX *) ctx); }

/* These were never exposed by gnulib.  */
#if ! (GL_OPENSSL_NAME == 224 || GL_OPENSSL_NAME == 384)
GL_OPENSSL_INLINE void
GL_CRYPTO_FN (_process_bytes) (const void *buf, size_t len, struct _gl_ctx *ctx)
{ OPENSSL_FN (_Update) ((_gl_CTX *) ctx, buf, len); }

GL_OPENSSL_INLINE void
GL_CRYPTO_FN (_process_block) (const void *buf, size_t len, struct _gl_ctx *ctx)
{ GL_CRYPTO_FN (_process_bytes) (buf, len, ctx); }
#endif

GL_OPENSSL_INLINE void *
GL_CRYPTO_FN (_finish_ctx) (struct _gl_ctx *ctx, void *res)
{ OPENSSL_FN (_Final) ((unsigned char *) res, (_gl_CTX *) ctx); return res; }

GL_OPENSSL_INLINE void *
GL_CRYPTO_FN (_buffer) (const char *buf, size_t len, void *res)
{ return OPENSSL_FN () ((const unsigned char *) buf, len, (unsigned char *) res); }

GL_OPENSSL_INLINE void *
GL_CRYPTO_FN (_read_ctx) (const struct _gl_ctx *ctx, void *res)
{
  /* Assume any unprocessed bytes in ctx are not to be ignored.  */
  _gl_CTX tmp_ctx = *(_gl_CTX *) ctx;
  OPENSSL_FN (_Final) ((unsigned char *) res, &tmp_ctx);
  return res;
}

/* Undef so we can include multiple times.  */
#undef GL_CRYPTO_FN
#undef OPENSSL_FN
#undef _GLCRYPTO_PREFIX
#undef OPENSSL_ALG
#undef GL_OPENSSL_NAME

_GL_INLINE_HEADER_END
