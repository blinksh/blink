/*  $OpenBSD: sshbuf.c,v 1.8 2016/11/25 23:22:04 djm Exp $  */
/*
 * Copyright (c) 2011 Damien Miller
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */


#define SSHBUF_INTERNAL

#include <sys/types.h>
#include <signal.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

//#if defined(__linux)
#include <ctype.h>
//#endif

#include "ssherr.h"
#include "sshbuf.h"

#define explicit_bzero(p, plen) memset_s(p, plen, 0x0, plen)

/* #include "misc.h" */
#define ROUNDUP(x, y)   ((((x)+((y)-1))/(y))*(y))

static inline int
sshbuf_check_sanity(const struct sshbuf *buf)
{
  SSHBUF_TELL("sanity");
  if (buf == NULL ||
      (!buf->readonly && buf->d != buf->cd) ||
      buf->refcount < 1 || buf->refcount > SSHBUF_REFS_MAX ||
      buf->cd == NULL ||
      (buf->dont_free && (buf->readonly || buf->parent != NULL)) ||
      buf->max_size > SSHBUF_SIZE_MAX ||
      buf->alloc > buf->max_size ||
      buf->size > buf->alloc ||
      buf->off > buf->size) {
    /* Do not try to recover from corrupted buffer internals */
    SSHBUF_DBG(("SSH_ERR_INTERNAL_ERROR"));
    signal(SIGSEGV, SIG_DFL);
    raise(SIGSEGV);
    return SSH_ERR_INTERNAL_ERROR;
  }
  return 0;
}

static void
sshbuf_maybe_pack(struct sshbuf *buf, int force)
{
  SSHBUF_DBG(("force %d", force));
  SSHBUF_TELL("pre-pack");
  if (buf->off == 0 || buf->readonly || buf->refcount > 1)
    return;
  if (force ||
      (buf->off >= SSHBUF_PACK_MIN && buf->off >= buf->size / 2)) {
    memmove(buf->d, buf->d + buf->off, buf->size - buf->off);
    buf->size -= buf->off;
    buf->off = 0;
    SSHBUF_TELL("packed");
  }
}

struct sshbuf *
sshbuf_new(void)
{
  struct sshbuf *ret;
  
  if ((ret = calloc(sizeof(*ret), 1)) == NULL)
    return NULL;
  ret->alloc = SSHBUF_SIZE_INIT;
  ret->max_size = SSHBUF_SIZE_MAX;
  ret->readonly = 0;
  ret->refcount = 1;
  ret->parent = NULL;
  if ((ret->cd = ret->d = calloc(1, ret->alloc)) == NULL) {
    free(ret);
    return NULL;
  }
  return ret;
}

struct sshbuf *
sshbuf_from(const void *blob, size_t len)
{
  struct sshbuf *ret;
  
  if (blob == NULL || len > SSHBUF_SIZE_MAX ||
      (ret = calloc(sizeof(*ret), 1)) == NULL)
    return NULL;
  ret->alloc = ret->size = ret->max_size = len;
  ret->readonly = 1;
  ret->refcount = 1;
  ret->parent = NULL;
  ret->cd = blob;
  ret->d = NULL;
  return ret;
}

int
sshbuf_set_parent(struct sshbuf *child, struct sshbuf *parent)
{
  int r;
  
  if ((r = sshbuf_check_sanity(child)) != 0 ||
      (r = sshbuf_check_sanity(parent)) != 0)
    return r;
  child->parent = parent;
  child->parent->refcount++;
  return 0;
}

struct sshbuf *
sshbuf_fromb(struct sshbuf *buf)
{
  struct sshbuf *ret;
  
  if (sshbuf_check_sanity(buf) != 0)
    return NULL;
  if ((ret = sshbuf_from(sshbuf_ptr(buf), sshbuf_len(buf))) == NULL)
    return NULL;
  if (sshbuf_set_parent(ret, buf) != 0) {
    sshbuf_free(ret);
    return NULL;
  }
  return ret;
}

void
sshbuf_init(struct sshbuf *ret)
{
  explicit_bzero(ret, sizeof(*ret));
  ret->alloc = SSHBUF_SIZE_INIT;
  ret->max_size = SSHBUF_SIZE_MAX;
  ret->readonly = 0;
  ret->dont_free = 1;
  ret->refcount = 1;
  if ((ret->cd = ret->d = calloc(1, ret->alloc)) == NULL)
    ret->alloc = 0;
}

void
sshbuf_free(struct sshbuf *buf)
{
  int dont_free = 0;
  
  if (buf == NULL)
    return;
  /*
   * The following will leak on insane buffers, but this is the safest
   * course of action - an invalid pointer or already-freed pointer may
   * have been passed to us and continuing to scribble over memory would
   * be bad.
   */
  if (sshbuf_check_sanity(buf) != 0)
    return;
  /*
   * If we are a child, the free our parent to decrement its reference
   * count and possibly free it.
   */
  sshbuf_free(buf->parent);
  buf->parent = NULL;
  /*
   * If we are a parent with still-extant children, then don't free just
   * yet. The last child's call to sshbuf_free should decrement our
   * refcount to 0 and trigger the actual free.
   */
  buf->refcount--;
  if (buf->refcount > 0)
    return;
  dont_free = buf->dont_free;
  if (!buf->readonly) {
    explicit_bzero(buf->d, buf->alloc);
    free(buf->d);
  }
  explicit_bzero(buf, sizeof(*buf));
  if (!dont_free)
    free(buf);
}

void
sshbuf_reset(struct sshbuf *buf)
{
  u_char *d;
  
  if (buf->readonly || buf->refcount > 1) {
    /* Nonsensical. Just make buffer appear empty */
    buf->off = buf->size;
    return;
  }
  if (sshbuf_check_sanity(buf) == 0)
    explicit_bzero(buf->d, buf->alloc);
  buf->off = buf->size = 0;
  if (buf->alloc != SSHBUF_SIZE_INIT) {
    if ((d = realloc(buf->d, SSHBUF_SIZE_INIT)) != NULL) {
      buf->cd = buf->d = d;
      buf->alloc = SSHBUF_SIZE_INIT;
    }
  }
}

size_t
sshbuf_max_size(const struct sshbuf *buf)
{
  return buf->max_size;
}

size_t
sshbuf_alloc(const struct sshbuf *buf)
{
  return buf->alloc;
}

const struct sshbuf *
sshbuf_parent(const struct sshbuf *buf)
{
  return buf->parent;
}

u_int
sshbuf_refcount(const struct sshbuf *buf)
{
  return buf->refcount;
}

int
sshbuf_set_max_size(struct sshbuf *buf, size_t max_size)
{
  size_t rlen;
  u_char *dp;
  int r;
  
  SSHBUF_DBG(("set max buf = %p len = %zu", buf, max_size));
  if ((r = sshbuf_check_sanity(buf)) != 0)
    return r;
  if (max_size == buf->max_size)
    return 0;
  if (buf->readonly || buf->refcount > 1)
    return SSH_ERR_BUFFER_READ_ONLY;
  if (max_size > SSHBUF_SIZE_MAX)
    return SSH_ERR_NO_BUFFER_SPACE;
  /* pack and realloc if necessary */
  sshbuf_maybe_pack(buf, max_size < buf->size);
  if (max_size < buf->alloc && max_size > buf->size) {
    if (buf->size < SSHBUF_SIZE_INIT)
      rlen = SSHBUF_SIZE_INIT;
    else
      rlen = ROUNDUP(buf->size, SSHBUF_SIZE_INC);
    if (rlen > max_size)
      rlen = max_size;
    explicit_bzero(buf->d + buf->size, buf->alloc - buf->size);
    SSHBUF_DBG(("new alloc = %zu", rlen));
    if ((dp = realloc(buf->d, rlen)) == NULL)
      return SSH_ERR_ALLOC_FAIL;
    buf->cd = buf->d = dp;
    buf->alloc = rlen;
  }
  SSHBUF_TELL("new-max");
  if (max_size < buf->alloc)
    return SSH_ERR_NO_BUFFER_SPACE;
  buf->max_size = max_size;
  return 0;
}

size_t
sshbuf_len(const struct sshbuf *buf)
{
  if (sshbuf_check_sanity(buf) != 0)
    return 0;
  return buf->size - buf->off;
}

size_t
sshbuf_avail(const struct sshbuf *buf)
{
  if (sshbuf_check_sanity(buf) != 0 || buf->readonly || buf->refcount > 1)
    return 0;
  return buf->max_size - (buf->size - buf->off);
}

const u_char *
sshbuf_ptr(const struct sshbuf *buf)
{
  if (sshbuf_check_sanity(buf) != 0)
    return NULL;
  return buf->cd + buf->off;
}

u_char *
sshbuf_mutable_ptr(const struct sshbuf *buf)
{
  if (sshbuf_check_sanity(buf) != 0 || buf->readonly || buf->refcount > 1)
    return NULL;
  return buf->d + buf->off;
}

int
sshbuf_check_reserve(const struct sshbuf *buf, size_t len)
{
  int r;
  
  if ((r = sshbuf_check_sanity(buf)) != 0)
    return r;
  if (buf->readonly || buf->refcount > 1)
    return SSH_ERR_BUFFER_READ_ONLY;
  SSHBUF_TELL("check");
  /* Check that len is reasonable and that max_size + available < len */
  if (len > buf->max_size || buf->max_size - len < buf->size - buf->off)
    return SSH_ERR_NO_BUFFER_SPACE;
  return 0;
}

int
sshbuf_allocate(struct sshbuf *buf, size_t len)
{
  size_t rlen, need;
  u_char *dp;
  int r;
  
  SSHBUF_DBG(("allocate buf = %p len = %zu", buf, len));
  if ((r = sshbuf_check_reserve(buf, len)) != 0)
    return r;
  /*
   * If the requested allocation appended would push us past max_size
   * then pack the buffer, zeroing buf->off.
   */
  sshbuf_maybe_pack(buf, buf->size + len > buf->max_size);
  SSHBUF_TELL("allocate");
  if (len + buf->size <= buf->alloc)
    return 0; /* already have it. */
  
  /*
   * Prefer to alloc in SSHBUF_SIZE_INC units, but
   * allocate less if doing so would overflow max_size.
   */
  need = len + buf->size - buf->alloc;
  rlen = ROUNDUP(buf->alloc + need, SSHBUF_SIZE_INC);
  SSHBUF_DBG(("need %zu initial rlen %zu", need, rlen));
  if (rlen > buf->max_size)
    rlen = buf->alloc + need;
  SSHBUF_DBG(("adjusted rlen %zu", rlen));
  if ((dp = realloc(buf->d, rlen)) == NULL) {
    SSHBUF_DBG(("realloc fail"));
    return SSH_ERR_ALLOC_FAIL;
  }
  buf->alloc = rlen;
  buf->cd = buf->d = dp;
  if ((r = sshbuf_check_reserve(buf, len)) < 0) {
    /* shouldn't fail */
    return r;
  }
  SSHBUF_TELL("done");
  return 0;
}

int
sshbuf_reserve(struct sshbuf *buf, size_t len, u_char **dpp)
{
  u_char *dp;
  int r;
  
  if (dpp != NULL)
    *dpp = NULL;
  
  SSHBUF_DBG(("reserve buf = %p len = %zu", buf, len));
  if ((r = sshbuf_allocate(buf, len)) != 0)
    return r;
  
  dp = buf->d + buf->size;
  buf->size += len;
  if (dpp != NULL)
    *dpp = dp;
  return 0;
}

int
sshbuf_consume(struct sshbuf *buf, size_t len)
{
  int r;
  
  SSHBUF_DBG(("len = %zu", len));
  if ((r = sshbuf_check_sanity(buf)) != 0)
    return r;
  if (len == 0)
    return 0;
  if (len > sshbuf_len(buf))
    return SSH_ERR_MESSAGE_INCOMPLETE;
  buf->off += len;
  SSHBUF_TELL("done");
  return 0;
}

int
sshbuf_consume_end(struct sshbuf *buf, size_t len)
{
  int r;
  
  SSHBUF_DBG(("len = %zu", len));
  if ((r = sshbuf_check_sanity(buf)) != 0)
    return r;
  if (len == 0)
    return 0;
  if (len > sshbuf_len(buf))
    return SSH_ERR_MESSAGE_INCOMPLETE;
  buf->size -= len;
  SSHBUF_TELL("done");
  return 0;
}

int
sshbuf_get(struct sshbuf *buf, void *v, size_t len)
{
  const u_char *p = sshbuf_ptr(buf);
  int r;
  
  if ((r = sshbuf_consume(buf, len)) < 0)
    return r;
  if (v != NULL && len != 0)
    memcpy(v, p, len);
  return 0;
}

int
sshbuf_get_u64(struct sshbuf *buf, uint64_t *valp)
{
  const u_char *p = sshbuf_ptr(buf);
  int r;
  
  if ((r = sshbuf_consume(buf, 8)) < 0)
    return r;
  if (valp != NULL)
    *valp = PEEK_U64(p);
  return 0;
}

int
sshbuf_get_u32(struct sshbuf *buf, uint32_t *valp)
{
  const u_char *p = sshbuf_ptr(buf);
  int r;
  
  if ((r = sshbuf_consume(buf, 4)) < 0)
    return r;
  if (valp != NULL)
    *valp = PEEK_U32(p);
  return 0;
}

int
sshbuf_get_u16(struct sshbuf *buf, uint16_t *valp)
{
  const u_char *p = sshbuf_ptr(buf);
  int r;
  
  if ((r = sshbuf_consume(buf, 2)) < 0)
    return r;
  if (valp != NULL)
    *valp = PEEK_U16(p);
  return 0;
}

int
sshbuf_get_u8(struct sshbuf *buf, u_char *valp)
{
  const u_char *p = sshbuf_ptr(buf);
  int r;
  
  if ((r = sshbuf_consume(buf, 1)) < 0)
    return r;
  if (valp != NULL)
    *valp = (uint8_t)*p;
  return 0;
}

int
sshbuf_get_string(struct sshbuf *buf, u_char **valp, size_t *lenp)
{
  const u_char *val;
  size_t len;
  int r;
  
  if (valp != NULL)
    *valp = NULL;
  if (lenp != NULL)
    *lenp = 0;
  if ((r = sshbuf_get_string_direct(buf, &val, &len)) < 0)
    return r;
  if (valp != NULL) {
    if ((*valp = malloc(len + 1)) == NULL) {
      SSHBUF_DBG(("SSH_ERR_ALLOC_FAIL"));
      return SSH_ERR_ALLOC_FAIL;
    }
    if (len != 0)
      memcpy(*valp, val, len);
    (*valp)[len] = '\0';
  }
  if (lenp != NULL)
    *lenp = len;
  return 0;
}

int
sshbuf_get_string8(struct sshbuf *buf, u_char **valp, size_t *lenp)
{
  const u_char *val;
  size_t len;
  int r;
  
  if (valp != NULL)
    *valp = NULL;
  if (lenp != NULL)
    *lenp = 0;
  if ((r = sshbuf_get_string8_direct(buf, &val, &len)) < 0)
    return r;
  if (valp != NULL) {
    if ((*valp = malloc(len + 1)) == NULL) {
      SSHBUF_DBG(("SSH_ERR_ALLOC_FAIL"));
      return SSH_ERR_ALLOC_FAIL;
    }
    if (len != 0)
      memcpy(*valp, val, len);
    (*valp)[len] = '\0';
  }
  if (lenp != NULL)
    *lenp = len;
  return 0;
}

int
sshbuf_get_string8_direct(struct sshbuf *buf, const u_char **valp, size_t *lenp)
{
  size_t len;
  const u_char *p;
  int r;
  
  if (valp != NULL)
    *valp = NULL;
  if (lenp != NULL)
    *lenp = 0;
  if ((r = sshbuf_peek_string8_direct(buf, &p, &len)) < 0)
    return r;
  if (valp != NULL)
    *valp = p;
  if (lenp != NULL)
    *lenp = len;
  if (sshbuf_consume(buf, len + 1) != 0) {
    /* Shouldn't happen */
    SSHBUF_DBG(("SSH_ERR_INTERNAL_ERROR"));
    SSHBUF_ABORT();
    return SSH_ERR_INTERNAL_ERROR;
  }
  return 0;
}

int
sshbuf_peek_string8_direct(const struct sshbuf *buf, const u_char **valp,
                           size_t *lenp)
{
  uint32_t len;
  const u_char *p = sshbuf_ptr(buf);
  
  if (valp != NULL)
    *valp = NULL;
  if (lenp != NULL)
    *lenp = 0;
  if (sshbuf_len(buf) < 1) {
    SSHBUF_DBG(("SSH_ERR_MESSAGE_INCOMPLETE"));
    return SSH_ERR_MESSAGE_INCOMPLETE;
  }
  len = p[0];
  if (len > SSHBUF_SIZE_MAX - 1) {
    SSHBUF_DBG(("SSH_ERR_STRING_TOO_LARGE"));
    return SSH_ERR_STRING_TOO_LARGE;
  }
  if (sshbuf_len(buf) - 1 < len) {
    SSHBUF_DBG(("SSH_ERR_MESSAGE_INCOMPLETE"));
    return SSH_ERR_MESSAGE_INCOMPLETE;
  }
  if (valp != NULL)
    *valp = p + 1;
  if (lenp != NULL)
    *lenp = len;
  return 0;
}

int
sshbuf_get_string_direct(struct sshbuf *buf, const u_char **valp, size_t *lenp)
{
  size_t len;
  const u_char *p;
  int r;
  
  if (valp != NULL)
    *valp = NULL;
  if (lenp != NULL)
    *lenp = 0;
  if ((r = sshbuf_peek_string_direct(buf, &p, &len)) < 0)
    return r;
  if (valp != NULL)
    *valp = p;
  if (lenp != NULL)
    *lenp = len;
  if (sshbuf_consume(buf, len + 4) != 0) {
    /* Shouldn't happen */
    SSHBUF_DBG(("SSH_ERR_INTERNAL_ERROR"));
    SSHBUF_ABORT();
    return SSH_ERR_INTERNAL_ERROR;
  }
  return 0;
}

int
sshbuf_peek_string_direct(const struct sshbuf *buf, const u_char **valp,
                          size_t *lenp)
{
  uint32_t len;
  const u_char *p = sshbuf_ptr(buf);
  
  if (valp != NULL)
    *valp = NULL;
  if (lenp != NULL)
    *lenp = 0;
  if (sshbuf_len(buf) < 4) {
    SSHBUF_DBG(("SSH_ERR_MESSAGE_INCOMPLETE"));
    return SSH_ERR_MESSAGE_INCOMPLETE;
  }
  len = PEEK_U32(p);
  if (len > SSHBUF_SIZE_MAX - 4) {
    SSHBUF_DBG(("SSH_ERR_STRING_TOO_LARGE"));
    return SSH_ERR_STRING_TOO_LARGE;
  }
  if (sshbuf_len(buf) - 4 < len) {
    SSHBUF_DBG(("SSH_ERR_MESSAGE_INCOMPLETE"));
    return SSH_ERR_MESSAGE_INCOMPLETE;
  }
  if (valp != NULL)
    *valp = p + 4;
  if (lenp != NULL)
    *lenp = len;
  return 0;
}

int
sshbuf_get_cstring(struct sshbuf *buf, char **valp, size_t *lenp)
{
  size_t len;
  const u_char *p, *z;
  int r;
  
  if (valp != NULL)
    *valp = NULL;
  if (lenp != NULL)
    *lenp = 0;
  if ((r = sshbuf_peek_string_direct(buf, &p, &len)) != 0)
    return r;
  /* Allow a \0 only at the end of the string */
  if (len > 0 &&
      (z = memchr(p , '\0', len)) != NULL && z < p + len - 1) {
    SSHBUF_DBG(("SSH_ERR_INVALID_FORMAT"));
    return SSH_ERR_INVALID_FORMAT;
  }
  if ((r = sshbuf_skip_string(buf)) != 0)
    return -1;
  if (valp != NULL) {
    if ((*valp = malloc(len + 1)) == NULL) {
      SSHBUF_DBG(("SSH_ERR_ALLOC_FAIL"));
      return SSH_ERR_ALLOC_FAIL;
    }
    if (len != 0)
      memcpy(*valp, p, len);
    (*valp)[len] = '\0';
  }
  if (lenp != NULL)
    *lenp = (size_t)len;
  return 0;
}

int
sshbuf_get_cstring8(struct sshbuf *buf, char **valp, size_t *lenp)
{
  size_t len;
  const u_char *p, *z;
  int r;
  
  if (valp != NULL)
    *valp = NULL;
  if (lenp != NULL)
    *lenp = 0;
  if ((r = sshbuf_peek_string8_direct(buf, &p, &len)) != 0)
    return r;
  /* Allow a \0 only at the end of the string */
  if (len > 0 &&
      (z = memchr(p , '\0', len)) != NULL && z < p + len - 1) {
    SSHBUF_DBG(("SSH_ERR_INVALID_FORMAT"));
    return SSH_ERR_INVALID_FORMAT;
  }
  if ((r = sshbuf_skip_string8(buf)) != 0)
    return -1;
  if (valp != NULL) {
    if ((*valp = malloc(len + 1)) == NULL) {
      SSHBUF_DBG(("SSH_ERR_ALLOC_FAIL"));
      return SSH_ERR_ALLOC_FAIL;
    }
    if (len != 0)
      memcpy(*valp, p, len);
    (*valp)[len] = '\0';
  }
  if (lenp != NULL)
    *lenp = (size_t)len;
  return 0;
}

int
sshbuf_get_stringb(struct sshbuf *buf, struct sshbuf *v)
{
  uint32_t len;
  u_char *p;
  int r;
  
  /*
   * Use sshbuf_peek_string_direct() to figure out if there is
   * a complete string in 'buf' and copy the string directly
   * into 'v'.
   */
  if ((r = sshbuf_peek_string_direct(buf, NULL, NULL)) != 0 ||
      (r = sshbuf_get_u32(buf, &len)) != 0 ||
      (r = sshbuf_reserve(v, len, &p)) != 0 ||
      (r = sshbuf_get(buf, p, len)) != 0)
    return r;
  return 0;
}

int
sshbuf_get_stringb8(struct sshbuf *buf, struct sshbuf *v)
{
  uint8_t len;
  u_char *p;
  int r;
  
  /*
   * Use sshbuf_peek_string_direct() to figure out if there is
   * a complete string in 'buf' and copy the string directly
   * into 'v'.
   */
  if ((r = sshbuf_peek_string8_direct(buf, NULL, NULL)) != 0 ||
      (r = sshbuf_get_u8(buf, &len)) != 0 ||
      (r = sshbuf_reserve(v, len, &p)) != 0 ||
      (r = sshbuf_get(buf, p, len)) != 0)
    return r;
  return 0;
}

int
sshbuf_put(struct sshbuf *buf, const void *v, size_t len)
{
  u_char *p;
  int r;
  
  if ((r = sshbuf_reserve(buf, len, &p)) < 0)
    return r;
  if (len != 0)
    memcpy(p, v, len);
  return 0;
}

int
sshbuf_putb(struct sshbuf *buf, const struct sshbuf *v)
{
  return sshbuf_put(buf, sshbuf_ptr(v), sshbuf_len(v));
}

int
sshbuf_putf(struct sshbuf *buf, const char *fmt, ...)
{
  va_list ap;
  int r;
  
  va_start(ap, fmt);
  r = sshbuf_putfv(buf, fmt, ap);
  va_end(ap);
  return r;
}

int
sshbuf_putfv(struct sshbuf *buf, const char *fmt, va_list ap)
{
  va_list ap2;
  int r, len;
  u_char *p;
  
  va_copy(ap2, ap);
  if ((len = vsnprintf(NULL, 0, fmt, ap2)) < 0) {
    r = SSH_ERR_INVALID_ARGUMENT;
    goto out;
  }
  if (len == 0) {
    r = 0;
    goto out; /* Nothing to do */
  }
  va_end(ap2);
  va_copy(ap2, ap);
  if ((r = sshbuf_reserve(buf, (size_t)len + 1, &p)) < 0)
    goto out;
  if ((r = vsnprintf((char *)p, len + 1, fmt, ap2)) != len) {
    r = SSH_ERR_INTERNAL_ERROR;
    goto out; /* Shouldn't happen */
  }
  /* Consume terminating \0 */
  if ((r = sshbuf_consume_end(buf, 1)) != 0)
    goto out;
  r = 0;
out:
  va_end(ap2);
  return r;
}

int
sshbuf_put_u64(struct sshbuf *buf, uint64_t val)
{
  u_char *p;
  int r;
  
  if ((r = sshbuf_reserve(buf, 8, &p)) < 0)
    return r;
  POKE_U64(p, val);
  return 0;
}

int
sshbuf_put_u32(struct sshbuf *buf, uint32_t val)
{
  u_char *p;
  int r;
  
  if ((r = sshbuf_reserve(buf, 4, &p)) < 0)
    return r;
  POKE_U32(p, val);
  return 0;
}

int
sshbuf_put_u16(struct sshbuf *buf, uint16_t val)
{
  u_char *p;
  int r;
  
  if ((r = sshbuf_reserve(buf, 2, &p)) < 0)
    return r;
  POKE_U16(p, val);
  return 0;
}

int
sshbuf_put_u8(struct sshbuf *buf, u_char val)
{
  u_char *p;
  int r;
  
  if ((r = sshbuf_reserve(buf, 1, &p)) < 0)
    return r;
  p[0] = val;
  return 0;
}

int
sshbuf_put_string(struct sshbuf *buf, const void *v, size_t len)
{
  u_char *d;
  int r;
  
  if (len > SSHBUF_SIZE_MAX - 4) {
    SSHBUF_DBG(("SSH_ERR_NO_BUFFER_SPACE"));
    return SSH_ERR_NO_BUFFER_SPACE;
  }
  if ((r = sshbuf_reserve(buf, len + 4, &d)) < 0)
    return r;
  POKE_U32(d, len);
  if (len != 0)
    memcpy(d + 4, v, len);
  return 0;
}

int
sshbuf_put_string8(struct sshbuf *buf, const void *v, size_t len)
{
  u_char *d;
  int r;
  
  if (len > 0xFF - 1) {
    SSHBUF_DBG(("SSH_ERR_NO_BUFFER_SPACE"));
    return SSH_ERR_NO_BUFFER_SPACE;
  }
  if ((r = sshbuf_reserve(buf, len + 1, &d)) < 0)
    return r;
  d[0] = len;
  if (len != 0)
    memcpy(d + 1, v, len);
  return 0;
}

int
sshbuf_put_cstring(struct sshbuf *buf, const char *v)
{
  return sshbuf_put_string(buf, (u_char *)v, v == NULL ? 0 : strlen(v));
}

int
sshbuf_put_cstring8(struct sshbuf *buf, const char *v)
{
  return sshbuf_put_string8(buf, (u_char *)v, v == NULL ? 0 : strlen(v));
}

int
sshbuf_put_stringb(struct sshbuf *buf, const struct sshbuf *v)
{
  return sshbuf_put_string(buf, sshbuf_ptr(v), sshbuf_len(v));
}

int
sshbuf_put_stringb8(struct sshbuf *buf, const struct sshbuf *v)
{
  return sshbuf_put_string8(buf, sshbuf_ptr(v), sshbuf_len(v));
}

int
sshbuf_froms(struct sshbuf *buf, struct sshbuf **bufp)
{
  const u_char *p;
  size_t len;
  struct sshbuf *ret;
  int r;
  
  if (buf == NULL || bufp == NULL)
    return SSH_ERR_INVALID_ARGUMENT;
  *bufp = NULL;
  if ((r = sshbuf_peek_string_direct(buf, &p, &len)) != 0)
    return r;
  if ((ret = sshbuf_from(p, len)) == NULL)
    return SSH_ERR_ALLOC_FAIL;
  if ((r = sshbuf_consume(buf, len + 4)) != 0 ||  /* Shouldn't happen */
      (r = sshbuf_set_parent(ret, buf)) != 0) {
    sshbuf_free(ret);
    return r;
  }
  *bufp = ret;
  return 0;
}

int
sshbuf_put_bignum2_bytes(struct sshbuf *buf, const void *v, size_t len)
{
  u_char *d;
  const u_char *s = (const u_char *)v;
  int r, prepend;
  
  if (len > SSHBUF_SIZE_MAX - 5) {
    SSHBUF_DBG(("SSH_ERR_NO_BUFFER_SPACE"));
    return SSH_ERR_NO_BUFFER_SPACE;
  }
  /* Skip leading zero bytes */
  for (; len > 0 && *s == 0; len--, s++)
    ;
  /*
   * If most significant bit is set then prepend a zero byte to
   * avoid interpretation as a negative number.
   */
  prepend = len > 0 && (s[0] & 0x80) != 0;
  if ((r = sshbuf_reserve(buf, len + 4 + prepend, &d)) < 0)
    return r;
  POKE_U32(d, len + prepend);
  if (prepend)
    d[4] = 0;
  if (len != 0)
    memcpy(d + 4 + prepend, s, len);
  return 0;
}

int
sshbuf_get_bignum2_bytes_direct(struct sshbuf *buf,
                                const u_char **valp, size_t *lenp)
{
  const u_char *d;
  size_t len, olen;
  int r;
  
  if ((r = sshbuf_peek_string_direct(buf, &d, &olen)) < 0)
    return r;
  len = olen;
  /* Refuse negative (MSB set) bignums */
  if ((len != 0 && (*d & 0x80) != 0))
    return SSH_ERR_BIGNUM_IS_NEGATIVE;
  /* Refuse overlong bignums, allow prepended \0 to avoid MSB set */
  if (len > SSHBUF_MAX_BIGNUM + 1 ||
      (len == SSHBUF_MAX_BIGNUM + 1 && *d != 0))
    return SSH_ERR_BIGNUM_TOO_LARGE;
  /* Trim leading zeros */
  while (len > 0 && *d == 0x00) {
    d++;
    len--;
  }
  if (valp != NULL)
    *valp = d;
  if (lenp != NULL)
    *lenp = len;
  if (sshbuf_consume(buf, olen + 4) != 0) {
    /* Shouldn't happen */
    SSHBUF_DBG(("SSH_ERR_INTERNAL_ERROR"));
    SSHBUF_ABORT();
    return SSH_ERR_INTERNAL_ERROR;
  }
  return 0;
}


int
sshbuf_get_bignum2(struct sshbuf *buf, BIGNUM *v)
{
  const u_char *d;
  size_t len;
  int r;
  
  if ((r = sshbuf_get_bignum2_bytes_direct(buf, &d, &len)) != 0)
    return r;
  if (v != NULL && BN_bin2bn(d, len, v) == NULL)
    return SSH_ERR_ALLOC_FAIL;
  return 0;
}

int
sshbuf_get_bignum1(struct sshbuf *buf, BIGNUM *v)
{
  const u_char *d = sshbuf_ptr(buf);
  uint16_t len_bits;
  size_t len_bytes;
  
  /* Length in bits */
  if (sshbuf_len(buf) < 2)
    return SSH_ERR_MESSAGE_INCOMPLETE;
  len_bits = PEEK_U16(d);
  len_bytes = (len_bits + 7) >> 3;
  if (len_bytes > SSHBUF_MAX_BIGNUM)
    return SSH_ERR_BIGNUM_TOO_LARGE;
  if (sshbuf_len(buf) < 2 + len_bytes)
    return SSH_ERR_MESSAGE_INCOMPLETE;
  if (v != NULL && BN_bin2bn(d + 2, len_bytes, v) == NULL)
    return SSH_ERR_ALLOC_FAIL;
  if (sshbuf_consume(buf, 2 + len_bytes) != 0) {
    SSHBUF_DBG(("SSH_ERR_INTERNAL_ERROR"));
    SSHBUF_ABORT();
    return SSH_ERR_INTERNAL_ERROR;
  }
  return 0;
}

static int
get_ec(const u_char *d, size_t len, EC_POINT *v, const EC_GROUP *g)
{
  /* Refuse overlong bignums */
  if (len == 0 || len > SSHBUF_MAX_ECPOINT)
    return SSH_ERR_ECPOINT_TOO_LARGE;
  
  if (*d != POINT_CONVERSION_UNCOMPRESSED &&
      (*d & ~0x1) != POINT_CONVERSION_COMPRESSED) {
    return SSH_ERR_INVALID_FORMAT;
  }
  
  if (v != NULL && EC_POINT_oct2point(g, v, d, len, NULL) != 1)
    return SSH_ERR_INVALID_FORMAT; /* XXX assumption */
  return 0;
}

int
sshbuf_get_ec(struct sshbuf *buf, EC_POINT *v, const EC_GROUP *g)
{
  const u_char *d;
  size_t len;
  int r;
  
  if ((r = sshbuf_peek_string_direct(buf, &d, &len)) < 0)
    return r;
  if ((r = get_ec(d, len, v, g)) != 0)
    return r;
  /* Skip string */
  if (sshbuf_get_string_direct(buf, NULL, NULL) != 0) {
    /* Shouldn't happen */
    SSHBUF_DBG(("SSH_ERR_INTERNAL_ERROR"));
    SSHBUF_ABORT();
    return SSH_ERR_INTERNAL_ERROR;
  }
  return 0;
}

int
sshbuf_get_eckey(struct sshbuf *buf, EC_KEY *v)
{
  EC_POINT *pt = EC_POINT_new(EC_KEY_get0_group(v));
  int r;
  const u_char *d;
  size_t len;
  
  if (pt == NULL) {
    SSHBUF_DBG(("SSH_ERR_ALLOC_FAIL"));
    return SSH_ERR_ALLOC_FAIL;
  }
  if ((r = sshbuf_peek_string_direct(buf, &d, &len)) < 0) {
    EC_POINT_free(pt);
    return r;
  }
  if ((r = get_ec(d, len, pt, EC_KEY_get0_group(v))) != 0) {
    EC_POINT_free(pt);
    return r;
  }
  if (EC_KEY_set_public_key(v, pt) != 1) {
    EC_POINT_free(pt);
    return SSH_ERR_ALLOC_FAIL; /* XXX assumption */
  }
  EC_POINT_free(pt);
  /* Skip string */
  if (sshbuf_get_string_direct(buf, NULL, NULL) != 0) {
    /* Shouldn't happen */
    SSHBUF_DBG(("SSH_ERR_INTERNAL_ERROR"));
    SSHBUF_ABORT();
    return SSH_ERR_INTERNAL_ERROR;
  }
  return 0;
}

int
sshbuf_get_eckey8(struct sshbuf *buf, EC_KEY *v)
{
  EC_POINT *pt = EC_POINT_new(EC_KEY_get0_group(v));
  int r;
  const u_char *d;
  size_t len;
  
  if (pt == NULL) {
    SSHBUF_DBG(("SSH_ERR_ALLOC_FAIL"));
    return SSH_ERR_ALLOC_FAIL;
  }
  if ((r = sshbuf_peek_string8_direct(buf, &d, &len)) < 0) {
    EC_POINT_free(pt);
    return r;
  }
  if ((r = get_ec(d, len, pt, EC_KEY_get0_group(v))) != 0) {
    EC_POINT_free(pt);
    return r;
  }
  if (EC_KEY_set_public_key(v, pt) != 1) {
    EC_POINT_free(pt);
    return SSH_ERR_ALLOC_FAIL; /* XXX assumption */
  }
  EC_POINT_free(pt);
  /* Skip string */
  if (sshbuf_get_string8_direct(buf, NULL, NULL) != 0) {
    /* Shouldn't happen */
    SSHBUF_DBG(("SSH_ERR_INTERNAL_ERROR"));
    SSHBUF_ABORT();
    return SSH_ERR_INTERNAL_ERROR;
  }
  return 0;
}

int
sshbuf_put_bignum2(struct sshbuf *buf, const BIGNUM *v)
{
  u_char d[SSHBUF_MAX_BIGNUM + 1];
  int len = BN_num_bytes(v), prepend = 0, r;
  
  if (len < 0 || len > SSHBUF_MAX_BIGNUM)
    return SSH_ERR_INVALID_ARGUMENT;
  *d = '\0';
  if (BN_bn2bin(v, d + 1) != len)
    return SSH_ERR_INTERNAL_ERROR; /* Shouldn't happen */
  /* If MSB is set, prepend a \0 */
  if (len > 0 && (d[1] & 0x80) != 0)
    prepend = 1;
  if ((r = sshbuf_put_string(buf, d + 1 - prepend, len + prepend)) < 0) {
    explicit_bzero(d, sizeof(d));
    return r;
  }
  explicit_bzero(d, sizeof(d));
  return 0;
}

int
sshbuf_put_bignum1(struct sshbuf *buf, const BIGNUM *v)
{
  int r, len_bits = BN_num_bits(v);
  size_t len_bytes = (len_bits + 7) / 8;
  u_char d[SSHBUF_MAX_BIGNUM], *dp;
  
  if (len_bits < 0 || len_bytes > SSHBUF_MAX_BIGNUM)
    return SSH_ERR_INVALID_ARGUMENT;
  if (BN_bn2bin(v, d) != (int)len_bytes)
    return SSH_ERR_INTERNAL_ERROR; /* Shouldn't happen */
  if ((r = sshbuf_reserve(buf, len_bytes + 2, &dp)) < 0) {
    explicit_bzero(d, sizeof(d));
    return r;
  }
  POKE_U16(dp, len_bits);
  if (len_bytes != 0)
    memcpy(dp + 2, d, len_bytes);
  explicit_bzero(d, sizeof(d));
  return 0;
}

int
sshbuf_put_ec(struct sshbuf *buf, const EC_POINT *v, const EC_GROUP *g)
{
  u_char d[SSHBUF_MAX_ECPOINT];
  BN_CTX *bn_ctx;
  size_t len;
  int ret;
  
  if ((bn_ctx = BN_CTX_new()) == NULL)
    return SSH_ERR_ALLOC_FAIL;
  if ((len = EC_POINT_point2oct(g, v, POINT_CONVERSION_UNCOMPRESSED,
                                NULL, 0, bn_ctx)) > SSHBUF_MAX_ECPOINT) {
    BN_CTX_free(bn_ctx);
    return SSH_ERR_INVALID_ARGUMENT;
  }
  if (EC_POINT_point2oct(g, v, POINT_CONVERSION_UNCOMPRESSED,
                         d, len, bn_ctx) != len) {
    BN_CTX_free(bn_ctx);
    return SSH_ERR_INTERNAL_ERROR; /* Shouldn't happen */
  }
  BN_CTX_free(bn_ctx);
  ret = sshbuf_put_string(buf, d, len);
  explicit_bzero(d, len);
  return ret;
}

int
sshbuf_put_ec8(struct sshbuf *buf, const EC_POINT *v, const EC_GROUP *g)
{
  u_char d[SSHBUF_MAX_ECPOINT];
  BN_CTX *bn_ctx;
  size_t len;
  int ret;
  
  if ((bn_ctx = BN_CTX_new()) == NULL)
    return SSH_ERR_ALLOC_FAIL;
  if ((len = EC_POINT_point2oct(g, v, POINT_CONVERSION_COMPRESSED,
                                NULL, 0, bn_ctx)) > SSHBUF_MAX_ECPOINT) {
    BN_CTX_free(bn_ctx);
    return SSH_ERR_INVALID_ARGUMENT;
  }
  if (EC_POINT_point2oct(g, v, POINT_CONVERSION_COMPRESSED,
                         d, len, bn_ctx) != len) {
    BN_CTX_free(bn_ctx);
    return SSH_ERR_INTERNAL_ERROR; /* Shouldn't happen */
  }
  BN_CTX_free(bn_ctx);
  ret = sshbuf_put_string8(buf, d, len);
  explicit_bzero(d, len);
  return ret;
}

int
sshbuf_put_eckey(struct sshbuf *buf, const EC_KEY *v)
{
  return sshbuf_put_ec(buf, EC_KEY_get0_public_key(v),
                       EC_KEY_get0_group(v));
}

int
sshbuf_put_eckey8(struct sshbuf *buf, const EC_KEY *v)
{
  return sshbuf_put_ec8(buf, EC_KEY_get0_public_key(v),
                        EC_KEY_get0_group(v));
}


void
sshbuf_dump_data(const void *s, size_t len, FILE *f)
{
  size_t i, j;
  const u_char *p = (const u_char *)s;
  
  for (i = 0; i < len; i += 16) {
    fprintf(f, "%.4zu: ", i);
    for (j = i; j < i + 16; j++) {
      if (j < len)
        fprintf(f, "%02x ", p[j]);
      else
        fprintf(f, "   ");
    }
    fprintf(f, " ");
    for (j = i; j < i + 16; j++) {
      if (j < len) {
        if  (isascii(p[j]) && isprint(p[j]))
          fprintf(f, "%c", p[j]);
        else
          fprintf(f, ".");
      }
    }
    fprintf(f, "\n");
  }
}

void
sshbuf_dump(struct sshbuf *buf, FILE *f)
{
  fprintf(f, "buffer %p len = %zu\n", (void *)buf, sshbuf_len(buf));
  sshbuf_dump_data(sshbuf_ptr(buf), sshbuf_len(buf), f);
}

char *
sshbuf_dtob16(struct sshbuf *buf)
{
  size_t i, j, len = sshbuf_len(buf);
  const u_char *p = sshbuf_ptr(buf);
  char *ret;
  const char hex[] = "0123456789abcdef";
  
  if (len == 0)
    return strdup("");
  if (SIZE_MAX / 2 <= len || (ret = malloc(len * 2 + 1)) == NULL)
    return NULL;
  for (i = j = 0; i < len; i++) {
    ret[j++] = hex[(p[i] >> 4) & 0xf];
    ret[j++] = hex[p[i] & 0xf];
  }
  ret[j] = '\0';
  return ret;
}

char *
sshbuf_dtob64(struct sshbuf *buf)
{
  size_t len = sshbuf_len(buf), plen;
  const u_char *p = sshbuf_ptr(buf);
  char *ret;
  int r;
  
  if (len == 0)
    return strdup("");
  plen = ((len + 2) / 3) * 4 + 1;
  if (SIZE_MAX / 2 <= len || (ret = malloc(plen)) == NULL)
    return NULL;
  if ((r = b64_ntop(p, len, ret, plen)) == -1) {
    explicit_bzero(ret, plen);
    free(ret);
    return NULL;
  }
  return ret;
}

int
sshbuf_b64tod(struct sshbuf *buf, const char *b64)
{
  size_t plen = strlen(b64);
  int nlen, r;
  u_char *p;
  
  if (plen == 0)
    return 0;
  if ((p = malloc(plen)) == NULL)
    return SSH_ERR_ALLOC_FAIL;
  if ((nlen = b64_pton(b64, p, plen)) < 0) {
    explicit_bzero(p, plen);
    free(p);
    return SSH_ERR_INVALID_FORMAT;
  }
  if ((r = sshbuf_put(buf, p, nlen)) < 0) {
    explicit_bzero(p, plen);
    free(p);
    return r;
  }
  explicit_bzero(p, plen);
  free(p);
  return 0;
}

char *
sshbuf_dup_string(struct sshbuf *buf)
{
  const u_char *p = NULL, *s = sshbuf_ptr(buf);
  size_t l = sshbuf_len(buf);
  char *r;
  
  if (s == NULL || l > SIZE_MAX)
    return NULL;
  /* accept a nul only as the last character in the buffer */
  if (l > 0 && (p = memchr(s, '\0', l)) != NULL) {
    if (p != s + l - 1)
      return NULL;
    l--; /* the nul is put back below */
  }
  if ((r = malloc(l + 1)) == NULL)
    return NULL;
  if (l > 0)
    memcpy(r, s, l);
  r[l] = '\0';
  return r;
}

#define MUL_NO_OVERFLOW  ((size_t)1 << (sizeof(size_t) * 4))
#include <errno.h>

void *
recallocarray(void *ptr, size_t oldnmemb, size_t newnmemb, size_t size)
{
  size_t oldsize, newsize;
  void *newptr;
  
  if (ptr == NULL)
    return calloc(newnmemb, size);
  
  if ((newnmemb >= MUL_NO_OVERFLOW || size >= MUL_NO_OVERFLOW) &&
      newnmemb > 0 && SIZE_MAX / newnmemb < size) {
    errno = ENOMEM;
    return NULL;
  }
  newsize = newnmemb * size;
  
  if ((oldnmemb >= MUL_NO_OVERFLOW || size >= MUL_NO_OVERFLOW) &&
      oldnmemb > 0 && SIZE_MAX / oldnmemb < size) {
    errno = EINVAL;
    return NULL;
  }
  oldsize = oldnmemb * size;
  
  /*
   * Don't bother too much if we're shrinking just a bit,
   * we do not shrink for series of small steps, oh well.
   */
  if (newsize <= oldsize) {
    size_t d = oldsize - newsize;
    
    if (d < oldsize / 2 && d < (size_t)getpagesize()) {
      memset((char *)ptr + newsize, 0, d);
      return ptr;
    }
  }
  
  newptr = malloc(newsize);
  if (newptr == NULL)
    return NULL;
  
  if (newsize > oldsize) {
    memcpy(newptr, ptr, oldsize);
    memset((char *)newptr + oldsize, 0, newsize - oldsize);
  } else
    memcpy(newptr, ptr, newsize);
  
  explicit_bzero(ptr, oldsize);
  free(ptr);
  
  return newptr;
}
