/* factor -- print prime factors of n.
   Copyright (C) 1986-2017 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* Originally written by Paul Rubin <phr@ocf.berkeley.edu>.
   Adapted for GNU, fixed to factor UINT_MAX by Jim Meyering.
   Arbitrary-precision code adapted by James Youngman from Torbjörn
   Granlund's factorize.c, from GNU MP version 4.2.2.
   In 2012, the core was rewritten by Torbjörn Granlund and Niels Möller.
   Contains code from GNU MP.  */

/* Efficiently factor numbers that fit in one or two words (word = uintmax_t),
   or, with GMP, numbers of any size.

  Code organisation:

    There are several variants of many functions, for handling one word, two
    words, and GMP's mpz_t type.  If the one-word variant is called foo, the
    two-word variant will be foo2, and the one for mpz_t will be mp_foo.  In
    some cases, the plain function variants will handle both one-word and
    two-word numbers, evidenced by function arguments.

    The factoring code for two words will fall into the code for one word when
    progress allows that.

    Using GMP is optional.  Define HAVE_GMP to make this code include GMP
    factoring code.  The GMP factoring code is based on GMP's demos/factorize.c
    (last synced 2012-09-07).  The GMP-based factoring code will stay in GMP
    factoring code even if numbers get small enough for using the two-word
    code.

  Algorithm:

    (1) Perform trial division using a small primes table, but without hardware
        division since the primes table store inverses modulo the word base.
        (The GMP variant of this code doesn't make use of the precomputed
        inverses, but instead relies on GMP for fast divisibility testing.)
    (2) Check the nature of any non-factored part using Miller-Rabin for
        detecting composites, and Lucas for detecting primes.
    (3) Factor any remaining composite part using the Pollard-Brent rho
        algorithm or if USE_SQUFOF is defined to 1, try that first.
        Status of found factors are checked again using Miller-Rabin and Lucas.

    We prefer using Hensel norm in the divisions, not the more familiar
    Euclidian norm, since the former leads to much faster code.  In the
    Pollard-Brent rho code and the prime testing code, we use Montgomery's
    trick of multiplying all n-residues by the word base, allowing cheap Hensel
    reductions mod n.

  Improvements:

    * Use modular inverses also for exact division in the Lucas code, and
      elsewhere.  A problem is to locate the inverses not from an index, but
      from a prime.  We might instead compute the inverse on-the-fly.

    * Tune trial division table size (not forgetting that this is a standalone
      program where the table will be read from disk for each invocation).

    * Implement less naive powm, using k-ary exponentiation for k = 3 or
      perhaps k = 4.

    * Try to speed trial division code for single uintmax_t numbers, i.e., the
      code using DIVBLOCK.  It currently runs at 2 cycles per prime (Intel SBR,
      IBR), 3 cycles per prime (AMD Stars) and 5 cycles per prime (AMD BD) when
      using gcc 4.6 and 4.7.  Some software pipelining should help; 1, 2, and 4
      respectively cycles ought to be possible.

    * The redcify function could be vastly improved by using (plain Euclidian)
      pre-inversion (such as GMP's invert_limb) and udiv_qrnnd_preinv (from
      GMP's gmp-impl.h).  The redcify2 function could be vastly improved using
      similar methoods.  These functions currently dominate run time when using
      the -w option.
*/

/* Whether to recursively factor to prove primality,
   or run faster probabilistic tests.  */
#ifndef PROVE_PRIMALITY
# define PROVE_PRIMALITY 1
#endif

/* Faster for certain ranges but less general.  */
#ifndef USE_SQUFOF
# define USE_SQUFOF 0
#endif

/* Output SQUFOF statistics.  */
#ifndef STAT_SQUFOF
# define STAT_SQUFOF 0
#endif


#include <config.h>
#include <getopt.h>
#include <stdio.h>
#if HAVE_GMP
# include <gmp.h>
# if !HAVE_DECL_MPZ_INITS
#  include <stdarg.h>
# endif
#endif

#include <assert.h>

#include "system.h"
#include "die.h"
#include "error.h"
#include "full-write.h"
#include "quote.h"
#include "readtokens.h"
#include "xstrtol.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "factor"

#define AUTHORS \
  proper_name ("Paul Rubin"),                                           \
  proper_name_utf8 ("Torbjorn Granlund", "Torbj\303\266rn Granlund"),   \
  proper_name_utf8 ("Niels Moller", "Niels M\303\266ller")

/* Token delimiters when reading from a file.  */
#define DELIM "\n\t "

#ifndef USE_LONGLONG_H
/* With the way we use longlong.h, it's only safe to use
   when UWtype = UHWtype, as there were various cases
   (as can be seen in the history for longlong.h) where
   for example, _LP64 was required to enable W_TYPE_SIZE==64 code,
   to avoid compile time or run time issues.  */
# if LONG_MAX == INTMAX_MAX
#  define USE_LONGLONG_H 1
# endif
#endif

#if USE_LONGLONG_H

/* Make definitions for longlong.h to make it do what it can do for us */

/* bitcount for uintmax_t */
# if UINTMAX_MAX == UINT32_MAX
#  define W_TYPE_SIZE 32
# elif UINTMAX_MAX == UINT64_MAX
#  define W_TYPE_SIZE 64
# elif UINTMAX_MAX == UINT128_MAX
#  define W_TYPE_SIZE 128
# endif

# define UWtype  uintmax_t
# define UHWtype unsigned long int
# undef UDWtype
# if HAVE_ATTRIBUTE_MODE
typedef unsigned int UQItype    __attribute__ ((mode (QI)));
typedef          int SItype     __attribute__ ((mode (SI)));
typedef unsigned int USItype    __attribute__ ((mode (SI)));
typedef          int DItype     __attribute__ ((mode (DI)));
typedef unsigned int UDItype    __attribute__ ((mode (DI)));
# else
typedef unsigned char UQItype;
typedef          long SItype;
typedef unsigned long int USItype;
#  if HAVE_LONG_LONG_INT
typedef long long int DItype;
typedef unsigned long long int UDItype;
#  else /* Assume `long' gives us a wide enough type.  Needed for hppa2.0w.  */
typedef long int DItype;
typedef unsigned long int UDItype;
#  endif
# endif
# define LONGLONG_STANDALONE     /* Don't require GMP's longlong.h mdep files */
# define ASSERT(x)               /* FIXME make longlong.h really standalone */
# define __GMP_DECLSPEC          /* FIXME make longlong.h really standalone */
# define __clz_tab factor_clz_tab /* Rename to avoid glibc collision */
# ifndef __GMP_GNUC_PREREQ
#  define __GMP_GNUC_PREREQ(a,b) 1
# endif

/* These stub macros are only used in longlong.h in certain system compiler
   combinations, so ensure usage to avoid -Wunused-macros warnings.  */
# if __GMP_GNUC_PREREQ (1,1) && defined __clz_tab
ASSERT (1)
__GMP_DECLSPEC
# endif

# if _ARCH_PPC
#  define HAVE_HOST_CPU_FAMILY_powerpc 1
# endif
# include "longlong.h"
# ifdef COUNT_LEADING_ZEROS_NEED_CLZ_TAB
const unsigned char factor_clz_tab[129] =
{
  1,2,3,3,4,4,4,4,5,5,5,5,5,5,5,5,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
  8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
  8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
  9
};
# endif

#else /* not USE_LONGLONG_H */

# define W_TYPE_SIZE (8 * sizeof (uintmax_t))
# define __ll_B ((uintmax_t) 1 << (W_TYPE_SIZE / 2))
# define __ll_lowpart(t)  ((uintmax_t) (t) & (__ll_B - 1))
# define __ll_highpart(t) ((uintmax_t) (t) >> (W_TYPE_SIZE / 2))

#endif

#if !defined __clz_tab && !defined UHWtype
/* Without this seemingly useless conditional, gcc -Wunused-macros
   warns that each of the two tested macros is unused on Fedora 18.
   FIXME: this is just an ugly band-aid.  Fix it properly.  */
#endif

/* 2*3*5*7*11...*101 is 128 bits, and has 26 prime factors */
#define MAX_NFACTS 26

enum
{
  DEV_DEBUG_OPTION = CHAR_MAX + 1
};

static struct option const long_options[] =
{
  {"-debug", no_argument, NULL, DEV_DEBUG_OPTION},
  {GETOPT_HELP_OPTION_DECL},
  {GETOPT_VERSION_OPTION_DECL},
  {NULL, 0, NULL, 0}
};

struct factors
{
  uintmax_t     plarge[2]; /* Can have a single large factor */
  uintmax_t     p[MAX_NFACTS];
  unsigned char e[MAX_NFACTS];
  unsigned char nfactors;
};

#if HAVE_GMP
struct mp_factors
{
  mpz_t             *p;
  unsigned long int *e;
  unsigned long int nfactors;
};
#endif

static void factor (uintmax_t, uintmax_t, struct factors *);

#ifndef umul_ppmm
# define umul_ppmm(w1, w0, u, v)                                        \
  do {                                                                  \
    uintmax_t __x0, __x1, __x2, __x3;                                   \
    unsigned long int __ul, __vl, __uh, __vh;                           \
    uintmax_t __u = (u), __v = (v);                                     \
                                                                        \
    __ul = __ll_lowpart (__u);                                          \
    __uh = __ll_highpart (__u);                                         \
    __vl = __ll_lowpart (__v);                                          \
    __vh = __ll_highpart (__v);                                         \
                                                                        \
    __x0 = (uintmax_t) __ul * __vl;                                     \
    __x1 = (uintmax_t) __ul * __vh;                                     \
    __x2 = (uintmax_t) __uh * __vl;                                     \
    __x3 = (uintmax_t) __uh * __vh;                                     \
                                                                        \
    __x1 += __ll_highpart (__x0);/* this can't give carry */            \
    __x1 += __x2;               /* but this indeed can */               \
    if (__x1 < __x2)            /* did we get it? */                    \
      __x3 += __ll_B;           /* yes, add it in the proper pos. */    \
                                                                        \
    (w1) = __x3 + __ll_highpart (__x1);                                 \
    (w0) = (__x1 << W_TYPE_SIZE / 2) + __ll_lowpart (__x0);             \
  } while (0)
#endif

#if !defined udiv_qrnnd || defined UDIV_NEEDS_NORMALIZATION
/* Define our own, not needing normalization. This function is
   currently not performance critical, so keep it simple. Similar to
   the mod macro below. */
# undef udiv_qrnnd
# define udiv_qrnnd(q, r, n1, n0, d)                                    \
  do {                                                                  \
    uintmax_t __d1, __d0, __q, __r1, __r0;                              \
                                                                        \
    assert ((n1) < (d));                                                \
    __d1 = (d); __d0 = 0;                                               \
    __r1 = (n1); __r0 = (n0);                                           \
    __q = 0;                                                            \
    for (unsigned int __i = W_TYPE_SIZE; __i > 0; __i--)                \
      {                                                                 \
        rsh2 (__d1, __d0, __d1, __d0, 1);                               \
        __q <<= 1;                                                      \
        if (ge2 (__r1, __r0, __d1, __d0))                               \
          {                                                             \
            __q++;                                                      \
            sub_ddmmss (__r1, __r0, __r1, __r0, __d1, __d0);            \
          }                                                             \
      }                                                                 \
    (r) = __r0;                                                         \
    (q) = __q;                                                          \
  } while (0)
#endif

#if !defined add_ssaaaa
# define add_ssaaaa(sh, sl, ah, al, bh, bl)                             \
  do {                                                                  \
    uintmax_t _add_x;                                                   \
    _add_x = (al) + (bl);                                               \
    (sh) = (ah) + (bh) + (_add_x < (al));                               \
    (sl) = _add_x;                                                      \
  } while (0)
#endif

#define rsh2(rh, rl, ah, al, cnt)                                       \
  do {                                                                  \
    (rl) = ((ah) << (W_TYPE_SIZE - (cnt))) | ((al) >> (cnt));           \
    (rh) = (ah) >> (cnt);                                               \
  } while (0)

#define lsh2(rh, rl, ah, al, cnt)                                       \
  do {                                                                  \
    (rh) = ((ah) << cnt) | ((al) >> (W_TYPE_SIZE - (cnt)));             \
    (rl) = (al) << (cnt);                                               \
  } while (0)

#define ge2(ah, al, bh, bl)                                             \
  ((ah) > (bh) || ((ah) == (bh) && (al) >= (bl)))

#define gt2(ah, al, bh, bl)                                             \
  ((ah) > (bh) || ((ah) == (bh) && (al) > (bl)))

#ifndef sub_ddmmss
# define sub_ddmmss(rh, rl, ah, al, bh, bl)                             \
  do {                                                                  \
    uintmax_t _cy;                                                      \
    _cy = (al) < (bl);                                                  \
    (rl) = (al) - (bl);                                                 \
    (rh) = (ah) - (bh) - _cy;                                           \
  } while (0)
#endif

#ifndef count_leading_zeros
# define count_leading_zeros(count, x) do {                             \
    uintmax_t __clz_x = (x);                                            \
    unsigned int __clz_c;                                               \
    for (__clz_c = 0;                                                   \
         (__clz_x & ((uintmax_t) 0xff << (W_TYPE_SIZE - 8))) == 0;      \
         __clz_c += 8)                                                  \
      __clz_x <<= 8;                                                    \
    for (; (intmax_t)__clz_x >= 0; __clz_c++)                           \
      __clz_x <<= 1;                                                    \
    (count) = __clz_c;                                                  \
  } while (0)
#endif

#ifndef count_trailing_zeros
# define count_trailing_zeros(count, x) do {                            \
    uintmax_t __ctz_x = (x);                                            \
    unsigned int __ctz_c = 0;                                           \
    while ((__ctz_x & 1) == 0)                                          \
      {                                                                 \
        __ctz_x >>= 1;                                                  \
        __ctz_c++;                                                      \
      }                                                                 \
    (count) = __ctz_c;                                                  \
  } while (0)
#endif

/* Requires that a < n and b <= n */
#define submod(r,a,b,n)                                                 \
  do {                                                                  \
    uintmax_t _t = - (uintmax_t) (a < b);                               \
    (r) = ((n) & _t) + (a) - (b);                                       \
  } while (0)

#define addmod(r,a,b,n)                                                 \
  submod ((r), (a), ((n) - (b)), (n))

/* Modular two-word addition and subtraction.  For performance reasons, the
   most significant bit of n1 must be clear.  The destination variables must be
   distinct from the mod operand.  */
#define addmod2(r1, r0, a1, a0, b1, b0, n1, n0)                         \
  do {                                                                  \
    add_ssaaaa ((r1), (r0), (a1), (a0), (b1), (b0));                    \
    if (ge2 ((r1), (r0), (n1), (n0)))                                   \
      sub_ddmmss ((r1), (r0), (r1), (r0), (n1), (n0));                  \
  } while (0)
#define submod2(r1, r0, a1, a0, b1, b0, n1, n0)                         \
  do {                                                                  \
    sub_ddmmss ((r1), (r0), (a1), (a0), (b1), (b0));                    \
    if ((intmax_t) (r1) < 0)                                            \
      add_ssaaaa ((r1), (r0), (r1), (r0), (n1), (n0));                  \
  } while (0)

#define HIGHBIT_TO_MASK(x)                                              \
  (((intmax_t)-1 >> 1) < 0                                              \
   ? (uintmax_t)((intmax_t)(x) >> (W_TYPE_SIZE - 1))                    \
   : ((x) & ((uintmax_t) 1 << (W_TYPE_SIZE - 1))                        \
      ? UINTMAX_MAX : (uintmax_t) 0))

/* Compute r = a mod d, where r = <*t1,retval>, a = <a1,a0>, d = <d1,d0>.
   Requires that d1 != 0.  */
static uintmax_t
mod2 (uintmax_t *r1, uintmax_t a1, uintmax_t a0, uintmax_t d1, uintmax_t d0)
{
  int cntd, cnta;

  assert (d1 != 0);

  if (a1 == 0)
    {
      *r1 = 0;
      return a0;
    }

  count_leading_zeros (cntd, d1);
  count_leading_zeros (cnta, a1);
  int cnt = cntd - cnta;
  lsh2 (d1, d0, d1, d0, cnt);
  for (int i = 0; i < cnt; i++)
    {
      if (ge2 (a1, a0, d1, d0))
        sub_ddmmss (a1, a0, a1, a0, d1, d0);
      rsh2 (d1, d0, d1, d0, 1);
    }

  *r1 = a1;
  return a0;
}

static uintmax_t _GL_ATTRIBUTE_CONST
gcd_odd (uintmax_t a, uintmax_t b)
{
  if ( (b & 1) == 0)
    {
      uintmax_t t = b;
      b = a;
      a = t;
    }
  if (a == 0)
    return b;

  /* Take out least significant one bit, to make room for sign */
  b >>= 1;

  for (;;)
    {
      uintmax_t t;
      uintmax_t bgta;

      while ((a & 1) == 0)
        a >>= 1;
      a >>= 1;

      t = a - b;
      if (t == 0)
        return (a << 1) + 1;

      bgta = HIGHBIT_TO_MASK (t);

      /* b <-- min (a, b) */
      b += (bgta & t);

      /* a <-- |a - b| */
      a = (t ^ bgta) - bgta;
    }
}

static uintmax_t
gcd2_odd (uintmax_t *r1, uintmax_t a1, uintmax_t a0, uintmax_t b1, uintmax_t b0)
{
  assert (b0 & 1);

  if ( (a0 | a1) == 0)
    {
      *r1 = b1;
      return b0;
    }

  while ((a0 & 1) == 0)
    rsh2 (a1, a0, a1, a0, 1);

  for (;;)
    {
      if ((b1 | a1) == 0)
        {
          *r1 = 0;
          return gcd_odd (b0, a0);
        }

      if (gt2 (a1, a0, b1, b0))
        {
          sub_ddmmss (a1, a0, a1, a0, b1, b0);
          do
            rsh2 (a1, a0, a1, a0, 1);
          while ((a0 & 1) == 0);
        }
      else if (gt2 (b1, b0, a1, a0))
        {
          sub_ddmmss (b1, b0, b1, b0, a1, a0);
          do
            rsh2 (b1, b0, b1, b0, 1);
          while ((b0 & 1) == 0);
        }
      else
        break;
    }

  *r1 = a1;
  return a0;
}

static void
factor_insert_multiplicity (struct factors *factors,
                            uintmax_t prime, unsigned int m)
{
  unsigned int nfactors = factors->nfactors;
  uintmax_t *p = factors->p;
  unsigned char *e = factors->e;

  /* Locate position for insert new or increment e.  */
  int i;
  for (i = nfactors - 1; i >= 0; i--)
    {
      if (p[i] <= prime)
        break;
    }

  if (i < 0 || p[i] != prime)
    {
      for (int j = nfactors - 1; j > i; j--)
        {
          p[j + 1] = p[j];
          e[j + 1] = e[j];
        }
      p[i + 1] = prime;
      e[i + 1] = m;
      factors->nfactors = nfactors + 1;
    }
  else
    {
      e[i] += m;
    }
}

#define factor_insert(f, p) factor_insert_multiplicity (f, p, 1)

static void
factor_insert_large (struct factors *factors,
                     uintmax_t p1, uintmax_t p0)
{
  if (p1 > 0)
    {
      assert (factors->plarge[1] == 0);
      factors->plarge[0] = p0;
      factors->plarge[1] = p1;
    }
  else
    factor_insert (factors, p0);
}

#if HAVE_GMP

# if !HAVE_DECL_MPZ_INITS

#  define mpz_inits(...) mpz_va_init (mpz_init, __VA_ARGS__)
#  define mpz_clears(...) mpz_va_init (mpz_clear, __VA_ARGS__)

static void
mpz_va_init (void (*mpz_single_init)(mpz_t), ...)
{
  va_list ap;

  va_start (ap, mpz_single_init);

  mpz_t *mpz;
  while ((mpz = va_arg (ap, mpz_t *)))
    mpz_single_init (*mpz);

  va_end (ap);
}
# endif

static void mp_factor (mpz_t, struct mp_factors *);

static void
mp_factor_init (struct mp_factors *factors)
{
  factors->p = NULL;
  factors->e = NULL;
  factors->nfactors = 0;
}

static void
mp_factor_clear (struct mp_factors *factors)
{
  for (unsigned int i = 0; i < factors->nfactors; i++)
    mpz_clear (factors->p[i]);

  free (factors->p);
  free (factors->e);
}

static void
mp_factor_insert (struct mp_factors *factors, mpz_t prime)
{
  unsigned long int nfactors = factors->nfactors;
  mpz_t         *p  = factors->p;
  unsigned long int *e  = factors->e;
  long i;

  /* Locate position for insert new or increment e.  */
  for (i = nfactors - 1; i >= 0; i--)
    {
      if (mpz_cmp (p[i], prime) <= 0)
        break;
    }

  if (i < 0 || mpz_cmp (p[i], prime) != 0)
    {
      p = xrealloc (p, (nfactors + 1) * sizeof p[0]);
      e = xrealloc (e, (nfactors + 1) * sizeof e[0]);

      mpz_init (p[nfactors]);
      for (long j = nfactors - 1; j > i; j--)
        {
          mpz_set (p[j + 1], p[j]);
          e[j + 1] = e[j];
        }
      mpz_set (p[i + 1], prime);
      e[i + 1] = 1;

      factors->p = p;
      factors->e = e;
      factors->nfactors = nfactors + 1;
    }
  else
    {
      e[i] += 1;
    }
}

static void
mp_factor_insert_ui (struct mp_factors *factors, unsigned long int prime)
{
  mpz_t pz;

  mpz_init_set_ui (pz, prime);
  mp_factor_insert (factors, pz);
  mpz_clear (pz);
}
#endif /* HAVE_GMP */


/* Number of bits in an uintmax_t.  */
enum { W = sizeof (uintmax_t) * CHAR_BIT };

/* Verify that uintmax_t does not have holes in its representation.  */
verify (UINTMAX_MAX >> (W - 1) == 1);

#define P(a,b,c,d) a,
static const unsigned char primes_diff[] = {
#include "primes.h"
0,0,0,0,0,0,0                           /* 7 sentinels for 8-way loop */
};
#undef P

#define PRIMES_PTAB_ENTRIES \
  (sizeof (primes_diff) / sizeof (primes_diff[0]) - 8 + 1)

#define P(a,b,c,d) b,
static const unsigned char primes_diff8[] = {
#include "primes.h"
0,0,0,0,0,0,0                           /* 7 sentinels for 8-way loop */
};
#undef P

struct primes_dtab
{
  uintmax_t binv, lim;
};

#define P(a,b,c,d) {c,d},
static const struct primes_dtab primes_dtab[] = {
#include "primes.h"
{1,0},{1,0},{1,0},{1,0},{1,0},{1,0},{1,0} /* 7 sentinels for 8-way loop */
};
#undef P

/* Verify that uintmax_t is not wider than
   the integers used to generate primes.h.  */
verify (W <= WIDE_UINT_BITS);

/* debugging for developers.  Enables devmsg().
   This flag is used only in the GMP code.  */
static bool dev_debug = false;

/* Prove primality or run probabilistic tests.  */
static bool flag_prove_primality = PROVE_PRIMALITY;

/* Number of Miller-Rabin tests to run when not proving primality. */
#define MR_REPS 25

static void
factor_insert_refind (struct factors *factors, uintmax_t p, unsigned int i,
                      unsigned int off)
{
  for (unsigned int j = 0; j < off; j++)
    p += primes_diff[i + j];
  factor_insert (factors, p);
}

/* Trial division with odd primes uses the following trick.

   Let p be an odd prime, and B = 2^{W_TYPE_SIZE}. For simplicity,
   consider the case t < B (this is the second loop below).

   From our tables we get

     binv = p^{-1} (mod B)
     lim = floor ( (B-1) / p ).

   First assume that t is a multiple of p, t = q * p. Then 0 <= q <= lim
   (and all quotients in this range occur for some t).

   Then t = q * p is true also (mod B), and p is invertible we get

     q = t * binv (mod B).

   Next, assume that t is *not* divisible by p. Since multiplication
   by binv (mod B) is a one-to-one mapping,

     t * binv (mod B) > lim,

   because all the smaller values are already taken.

   This can be summed up by saying that the function

     q(t) = binv * t (mod B)

   is a permutation of the range 0 <= t < B, with the curious property
   that it maps the multiples of p onto the range 0 <= q <= lim, in
   order, and the non-multiples of p onto the range lim < q < B.
 */

static uintmax_t
factor_using_division (uintmax_t *t1p, uintmax_t t1, uintmax_t t0,
                       struct factors *factors)
{
  if (t0 % 2 == 0)
    {
      unsigned int cnt;

      if (t0 == 0)
        {
          count_trailing_zeros (cnt, t1);
          t0 = t1 >> cnt;
          t1 = 0;
          cnt += W_TYPE_SIZE;
        }
      else
        {
          count_trailing_zeros (cnt, t0);
          rsh2 (t1, t0, t1, t0, cnt);
        }

      factor_insert_multiplicity (factors, 2, cnt);
    }

  uintmax_t p = 3;
  unsigned int i;
  for (i = 0; t1 > 0 && i < PRIMES_PTAB_ENTRIES; i++)
    {
      for (;;)
        {
          uintmax_t q1, q0, hi, lo _GL_UNUSED;

          q0 = t0 * primes_dtab[i].binv;
          umul_ppmm (hi, lo, q0, p);
          if (hi > t1)
            break;
          hi = t1 - hi;
          q1 = hi * primes_dtab[i].binv;
          if (LIKELY (q1 > primes_dtab[i].lim))
            break;
          t1 = q1; t0 = q0;
          factor_insert (factors, p);
        }
      p += primes_diff[i + 1];
    }
  if (t1p)
    *t1p = t1;

#define DIVBLOCK(I)                                                     \
  do {                                                                  \
    for (;;)                                                            \
      {                                                                 \
        q = t0 * pd[I].binv;                                            \
        if (LIKELY (q > pd[I].lim))                                     \
          break;                                                        \
        t0 = q;                                                         \
        factor_insert_refind (factors, p, i + 1, I);                    \
      }                                                                 \
  } while (0)

  for (; i < PRIMES_PTAB_ENTRIES; i += 8)
    {
      uintmax_t q;
      const struct primes_dtab *pd = &primes_dtab[i];
      DIVBLOCK (0);
      DIVBLOCK (1);
      DIVBLOCK (2);
      DIVBLOCK (3);
      DIVBLOCK (4);
      DIVBLOCK (5);
      DIVBLOCK (6);
      DIVBLOCK (7);

      p += primes_diff8[i];
      if (p * p > t0)
        break;
    }

  return t0;
}

#if HAVE_GMP
static void
mp_factor_using_division (mpz_t t, struct mp_factors *factors)
{
  mpz_t q;
  unsigned long int p;

  devmsg ("[trial division] ");

  mpz_init (q);

  p = mpz_scan1 (t, 0);
  mpz_div_2exp (t, t, p);
  while (p)
    {
      mp_factor_insert_ui (factors, 2);
      --p;
    }

  p = 3;
  for (unsigned int i = 1; i <= PRIMES_PTAB_ENTRIES;)
    {
      if (! mpz_divisible_ui_p (t, p))
        {
          p += primes_diff[i++];
          if (mpz_cmp_ui (t, p * p) < 0)
            break;
        }
      else
        {
          mpz_tdiv_q_ui (t, t, p);
          mp_factor_insert_ui (factors, p);
        }
    }

  mpz_clear (q);
}
#endif

/* Entry i contains (2i+1)^(-1) mod 2^8.  */
static const unsigned char  binvert_table[128] =
{
  0x01, 0xAB, 0xCD, 0xB7, 0x39, 0xA3, 0xC5, 0xEF,
  0xF1, 0x1B, 0x3D, 0xA7, 0x29, 0x13, 0x35, 0xDF,
  0xE1, 0x8B, 0xAD, 0x97, 0x19, 0x83, 0xA5, 0xCF,
  0xD1, 0xFB, 0x1D, 0x87, 0x09, 0xF3, 0x15, 0xBF,
  0xC1, 0x6B, 0x8D, 0x77, 0xF9, 0x63, 0x85, 0xAF,
  0xB1, 0xDB, 0xFD, 0x67, 0xE9, 0xD3, 0xF5, 0x9F,
  0xA1, 0x4B, 0x6D, 0x57, 0xD9, 0x43, 0x65, 0x8F,
  0x91, 0xBB, 0xDD, 0x47, 0xC9, 0xB3, 0xD5, 0x7F,
  0x81, 0x2B, 0x4D, 0x37, 0xB9, 0x23, 0x45, 0x6F,
  0x71, 0x9B, 0xBD, 0x27, 0xA9, 0x93, 0xB5, 0x5F,
  0x61, 0x0B, 0x2D, 0x17, 0x99, 0x03, 0x25, 0x4F,
  0x51, 0x7B, 0x9D, 0x07, 0x89, 0x73, 0x95, 0x3F,
  0x41, 0xEB, 0x0D, 0xF7, 0x79, 0xE3, 0x05, 0x2F,
  0x31, 0x5B, 0x7D, 0xE7, 0x69, 0x53, 0x75, 0x1F,
  0x21, 0xCB, 0xED, 0xD7, 0x59, 0xC3, 0xE5, 0x0F,
  0x11, 0x3B, 0x5D, 0xC7, 0x49, 0x33, 0x55, 0xFF
};

/* Compute n^(-1) mod B, using a Newton iteration.  */
#define binv(inv,n)                                                     \
  do {                                                                  \
    uintmax_t  __n = (n);                                               \
    uintmax_t  __inv;                                                   \
                                                                        \
    __inv = binvert_table[(__n / 2) & 0x7F]; /*  8 */                   \
    if (W_TYPE_SIZE > 8)   __inv = 2 * __inv - __inv * __inv * __n;     \
    if (W_TYPE_SIZE > 16)  __inv = 2 * __inv - __inv * __inv * __n;     \
    if (W_TYPE_SIZE > 32)  __inv = 2 * __inv - __inv * __inv * __n;     \
                                                                        \
    if (W_TYPE_SIZE > 64)                                               \
      {                                                                 \
        int  __invbits = 64;                                            \
        do {                                                            \
          __inv = 2 * __inv - __inv * __inv * __n;                      \
          __invbits *= 2;                                               \
        } while (__invbits < W_TYPE_SIZE);                              \
      }                                                                 \
                                                                        \
    (inv) = __inv;                                                      \
  } while (0)

/* q = u / d, assuming d|u.  */
#define divexact_21(q1, q0, u1, u0, d)                                  \
  do {                                                                  \
    uintmax_t _di, _q0;                                                 \
    binv (_di, (d));                                                    \
    _q0 = (u0) * _di;                                                   \
    if ((u1) >= (d))                                                    \
      {                                                                 \
        uintmax_t _p1, _p0 _GL_UNUSED;                            \
        umul_ppmm (_p1, _p0, _q0, d);                                   \
        (q1) = ((u1) - _p1) * _di;                                      \
        (q0) = _q0;                                                     \
      }                                                                 \
    else                                                                \
      {                                                                 \
        (q0) = _q0;                                                     \
        (q1) = 0;                                                       \
      }                                                                 \
  } while (0)

/* x B (mod n). */
#define redcify(r_prim, r, n)                                           \
  do {                                                                  \
    uintmax_t _redcify_q _GL_UNUSED;                              \
    udiv_qrnnd (_redcify_q, r_prim, r, 0, n);                           \
  } while (0)

/* x B^2 (mod n). Requires x > 0, n1 < B/2 */
#define redcify2(r1, r0, x, n1, n0)                                     \
  do {                                                                  \
    uintmax_t _r1, _r0, _i;                                             \
    if ((x) < (n1))                                                     \
      {                                                                 \
        _r1 = (x); _r0 = 0;                                             \
        _i = W_TYPE_SIZE;                                               \
      }                                                                 \
    else                                                                \
      {                                                                 \
        _r1 = 0; _r0 = (x);                                             \
        _i = 2*W_TYPE_SIZE;                                             \
      }                                                                 \
    while (_i-- > 0)                                                    \
      {                                                                 \
        lsh2 (_r1, _r0, _r1, _r0, 1);                                   \
        if (ge2 (_r1, _r0, (n1), (n0)))                                 \
          sub_ddmmss (_r1, _r0, _r1, _r0, (n1), (n0));                  \
      }                                                                 \
    (r1) = _r1;                                                         \
    (r0) = _r0;                                                         \
  } while (0)

/* Modular two-word multiplication, r = a * b mod m, with mi = m^(-1) mod B.
   Both a and b must be in redc form, the result will be in redc form too. */
static inline uintmax_t
mulredc (uintmax_t a, uintmax_t b, uintmax_t m, uintmax_t mi)
{
  uintmax_t rh, rl, q, th, tl _GL_UNUSED, xh;

  umul_ppmm (rh, rl, a, b);
  q = rl * mi;
  umul_ppmm (th, tl, q, m);
  xh = rh - th;
  if (rh < th)
    xh += m;

  return xh;
}

/* Modular two-word multiplication, r = a * b mod m, with mi = m^(-1) mod B.
   Both a and b must be in redc form, the result will be in redc form too.
   For performance reasons, the most significant bit of m must be clear. */
static uintmax_t
mulredc2 (uintmax_t *r1p,
          uintmax_t a1, uintmax_t a0, uintmax_t b1, uintmax_t b0,
          uintmax_t m1, uintmax_t m0, uintmax_t mi)
{
  uintmax_t r1, r0, q, p1, p0 _GL_UNUSED, t1, t0, s1, s0;
  mi = -mi;
  assert ( (a1 >> (W_TYPE_SIZE - 1)) == 0);
  assert ( (b1 >> (W_TYPE_SIZE - 1)) == 0);
  assert ( (m1 >> (W_TYPE_SIZE - 1)) == 0);

  /* First compute a0 * <b1, b0> B^{-1}
        +-----+
        |a0 b0|
     +--+--+--+
     |a0 b1|
     +--+--+--+
        |q0 m0|
     +--+--+--+
     |q0 m1|
    -+--+--+--+
     |r1|r0| 0|
     +--+--+--+
  */
  umul_ppmm (t1, t0, a0, b0);
  umul_ppmm (r1, r0, a0, b1);
  q = mi * t0;
  umul_ppmm (p1, p0, q, m0);
  umul_ppmm (s1, s0, q, m1);
  r0 += (t0 != 0); /* Carry */
  add_ssaaaa (r1, r0, r1, r0, 0, p1);
  add_ssaaaa (r1, r0, r1, r0, 0, t1);
  add_ssaaaa (r1, r0, r1, r0, s1, s0);

  /* Next, (a1 * <b1, b0> + <r1, r0> B^{-1}
        +-----+
        |a1 b0|
        +--+--+
        |r1|r0|
     +--+--+--+
     |a1 b1|
     +--+--+--+
        |q1 m0|
     +--+--+--+
     |q1 m1|
    -+--+--+--+
     |r1|r0| 0|
     +--+--+--+
  */
  umul_ppmm (t1, t0, a1, b0);
  umul_ppmm (s1, s0, a1, b1);
  add_ssaaaa (t1, t0, t1, t0, 0, r0);
  q = mi * t0;
  add_ssaaaa (r1, r0, s1, s0, 0, r1);
  umul_ppmm (p1, p0, q, m0);
  umul_ppmm (s1, s0, q, m1);
  r0 += (t0 != 0); /* Carry */
  add_ssaaaa (r1, r0, r1, r0, 0, p1);
  add_ssaaaa (r1, r0, r1, r0, 0, t1);
  add_ssaaaa (r1, r0, r1, r0, s1, s0);

  if (ge2 (r1, r0, m1, m0))
    sub_ddmmss (r1, r0, r1, r0, m1, m0);

  *r1p = r1;
  return r0;
}

static uintmax_t _GL_ATTRIBUTE_CONST
powm (uintmax_t b, uintmax_t e, uintmax_t n, uintmax_t ni, uintmax_t one)
{
  uintmax_t y = one;

  if (e & 1)
    y = b;

  while (e != 0)
    {
      b = mulredc (b, b, n, ni);
      e >>= 1;

      if (e & 1)
        y = mulredc (y, b, n, ni);
    }

  return y;
}

static uintmax_t
powm2 (uintmax_t *r1m,
       const uintmax_t *bp, const uintmax_t *ep, const uintmax_t *np,
       uintmax_t ni, const uintmax_t *one)
{
  uintmax_t r1, r0, b1, b0, n1, n0;
  unsigned int i;
  uintmax_t e;

  b0 = bp[0];
  b1 = bp[1];
  n0 = np[0];
  n1 = np[1];

  r0 = one[0];
  r1 = one[1];

  for (e = ep[0], i = W_TYPE_SIZE; i > 0; i--, e >>= 1)
    {
      if (e & 1)
        {
          r0 = mulredc2 (r1m, r1, r0, b1, b0, n1, n0, ni);
          r1 = *r1m;
        }
      b0 = mulredc2 (r1m, b1, b0, b1, b0, n1, n0, ni);
      b1 = *r1m;
    }
  for (e = ep[1]; e > 0; e >>= 1)
    {
      if (e & 1)
        {
          r0 = mulredc2 (r1m, r1, r0, b1, b0, n1, n0, ni);
          r1 = *r1m;
        }
      b0 = mulredc2 (r1m, b1, b0, b1, b0, n1, n0, ni);
      b1 = *r1m;
    }
  *r1m = r1;
  return r0;
}

static bool _GL_ATTRIBUTE_CONST
millerrabin (uintmax_t n, uintmax_t ni, uintmax_t b, uintmax_t q,
             unsigned int k, uintmax_t one)
{
  uintmax_t y = powm (b, q, n, ni, one);

  uintmax_t nm1 = n - one;      /* -1, but in redc representation. */

  if (y == one || y == nm1)
    return true;

  for (unsigned int i = 1; i < k; i++)
    {
      y = mulredc (y, y, n, ni);

      if (y == nm1)
        return true;
      if (y == one)
        return false;
    }
  return false;
}

static bool
millerrabin2 (const uintmax_t *np, uintmax_t ni, const uintmax_t *bp,
              const uintmax_t *qp, unsigned int k, const uintmax_t *one)
{
  uintmax_t y1, y0, nm1_1, nm1_0, r1m;

  y0 = powm2 (&r1m, bp, qp, np, ni, one);
  y1 = r1m;

  if (y0 == one[0] && y1 == one[1])
    return true;

  sub_ddmmss (nm1_1, nm1_0, np[1], np[0], one[1], one[0]);

  if (y0 == nm1_0 && y1 == nm1_1)
    return true;

  for (unsigned int i = 1; i < k; i++)
    {
      y0 = mulredc2 (&r1m, y1, y0, y1, y0, np[1], np[0], ni);
      y1 = r1m;

      if (y0 == nm1_0 && y1 == nm1_1)
        return true;
      if (y0 == one[0] && y1 == one[1])
        return false;
    }
  return false;
}

#if HAVE_GMP
static bool
mp_millerrabin (mpz_srcptr n, mpz_srcptr nm1, mpz_ptr x, mpz_ptr y,
                mpz_srcptr q, unsigned long int k)
{
  mpz_powm (y, x, q, n);

  if (mpz_cmp_ui (y, 1) == 0 || mpz_cmp (y, nm1) == 0)
    return true;

  for (unsigned long int i = 1; i < k; i++)
    {
      mpz_powm_ui (y, y, 2, n);
      if (mpz_cmp (y, nm1) == 0)
        return true;
      if (mpz_cmp_ui (y, 1) == 0)
        return false;
    }
  return false;
}
#endif

/* Lucas' prime test.  The number of iterations vary greatly, up to a few dozen
   have been observed.  The average seem to be about 2.  */
static bool
prime_p (uintmax_t n)
{
  int k;
  bool is_prime;
  uintmax_t a_prim, one, ni;
  struct factors factors;

  if (n <= 1)
    return false;

  /* We have already casted out small primes. */
  if (n < (uintmax_t) FIRST_OMITTED_PRIME * FIRST_OMITTED_PRIME)
    return true;

  /* Precomputation for Miller-Rabin.  */
  uintmax_t q = n - 1;
  for (k = 0; (q & 1) == 0; k++)
    q >>= 1;

  uintmax_t a = 2;
  binv (ni, n);                 /* ni <- 1/n mod B */
  redcify (one, 1, n);
  addmod (a_prim, one, one, n); /* i.e., redcify a = 2 */

  /* Perform a Miller-Rabin test, finds most composites quickly.  */
  if (!millerrabin (n, ni, a_prim, q, k, one))
    return false;

  if (flag_prove_primality)
    {
      /* Factor n-1 for Lucas.  */
      factor (0, n - 1, &factors);
    }

  /* Loop until Lucas proves our number prime, or Miller-Rabin proves our
     number composite.  */
  for (unsigned int r = 0; r < PRIMES_PTAB_ENTRIES; r++)
    {
      if (flag_prove_primality)
        {
          is_prime = true;
          for (unsigned int i = 0; i < factors.nfactors && is_prime; i++)
            {
              is_prime
                = powm (a_prim, (n - 1) / factors.p[i], n, ni, one) != one;
            }
        }
      else
        {
          /* After enough Miller-Rabin runs, be content. */
          is_prime = (r == MR_REPS - 1);
        }

      if (is_prime)
        return true;

      a += primes_diff[r];      /* Establish new base.  */

      /* The following is equivalent to redcify (a_prim, a, n).  It runs faster
         on most processors, since it avoids udiv_qrnnd.  If we go down the
         udiv_qrnnd_preinv path, this code should be replaced.  */
      {
        uintmax_t s1, s0;
        umul_ppmm (s1, s0, one, a);
        if (LIKELY (s1 == 0))
          a_prim = s0 % n;
        else
          {
            uintmax_t dummy _GL_UNUSED;
            udiv_qrnnd (dummy, a_prim, s1, s0, n);
          }
      }

      if (!millerrabin (n, ni, a_prim, q, k, one))
        return false;
    }

  error (0, 0, _("Lucas prime test failure.  This should not happen"));
  abort ();
}

static bool
prime2_p (uintmax_t n1, uintmax_t n0)
{
  uintmax_t q[2], nm1[2];
  uintmax_t a_prim[2];
  uintmax_t one[2];
  uintmax_t na[2];
  uintmax_t ni;
  unsigned int k;
  struct factors factors;

  if (n1 == 0)
    return prime_p (n0);

  nm1[1] = n1 - (n0 == 0);
  nm1[0] = n0 - 1;
  if (nm1[0] == 0)
    {
      count_trailing_zeros (k, nm1[1]);

      q[0] = nm1[1] >> k;
      q[1] = 0;
      k += W_TYPE_SIZE;
    }
  else
    {
      count_trailing_zeros (k, nm1[0]);
      rsh2 (q[1], q[0], nm1[1], nm1[0], k);
    }

  uintmax_t a = 2;
  binv (ni, n0);
  redcify2 (one[1], one[0], 1, n1, n0);
  addmod2 (a_prim[1], a_prim[0], one[1], one[0], one[1], one[0], n1, n0);

  /* FIXME: Use scalars or pointers in arguments? Some consistency needed. */
  na[0] = n0;
  na[1] = n1;

  if (!millerrabin2 (na, ni, a_prim, q, k, one))
    return false;

  if (flag_prove_primality)
    {
      /* Factor n-1 for Lucas.  */
      factor (nm1[1], nm1[0], &factors);
    }

  /* Loop until Lucas proves our number prime, or Miller-Rabin proves our
     number composite.  */
  for (unsigned int r = 0; r < PRIMES_PTAB_ENTRIES; r++)
    {
      bool is_prime;
      uintmax_t e[2], y[2];

      if (flag_prove_primality)
        {
          is_prime = true;
          if (factors.plarge[1])
            {
              uintmax_t pi;
              binv (pi, factors.plarge[0]);
              e[0] = pi * nm1[0];
              e[1] = 0;
              y[0] = powm2 (&y[1], a_prim, e, na, ni, one);
              is_prime = (y[0] != one[0] || y[1] != one[1]);
            }
          for (unsigned int i = 0; i < factors.nfactors && is_prime; i++)
            {
              /* FIXME: We always have the factor 2. Do we really need to
                 handle it here? We have done the same powering as part
                 of millerrabin. */
              if (factors.p[i] == 2)
                rsh2 (e[1], e[0], nm1[1], nm1[0], 1);
              else
                divexact_21 (e[1], e[0], nm1[1], nm1[0], factors.p[i]);
              y[0] = powm2 (&y[1], a_prim, e, na, ni, one);
              is_prime = (y[0] != one[0] || y[1] != one[1]);
            }
        }
      else
        {
          /* After enough Miller-Rabin runs, be content. */
          is_prime = (r == MR_REPS - 1);
        }

      if (is_prime)
        return true;

      a += primes_diff[r];      /* Establish new base.  */
      redcify2 (a_prim[1], a_prim[0], a, n1, n0);

      if (!millerrabin2 (na, ni, a_prim, q, k, one))
        return false;
    }

  error (0, 0, _("Lucas prime test failure.  This should not happen"));
  abort ();
}

#if HAVE_GMP
static bool
mp_prime_p (mpz_t n)
{
  bool is_prime;
  mpz_t q, a, nm1, tmp;
  struct mp_factors factors;

  if (mpz_cmp_ui (n, 1) <= 0)
    return false;

  /* We have already casted out small primes. */
  if (mpz_cmp_ui (n, (long) FIRST_OMITTED_PRIME * FIRST_OMITTED_PRIME) < 0)
    return true;

  mpz_inits (q, a, nm1, tmp, NULL);

  /* Precomputation for Miller-Rabin.  */
  mpz_sub_ui (nm1, n, 1);

  /* Find q and k, where q is odd and n = 1 + 2**k * q.  */
  unsigned long int k = mpz_scan1 (nm1, 0);
  mpz_tdiv_q_2exp (q, nm1, k);

  mpz_set_ui (a, 2);

  /* Perform a Miller-Rabin test, finds most composites quickly.  */
  if (!mp_millerrabin (n, nm1, a, tmp, q, k))
    {
      is_prime = false;
      goto ret2;
    }

  if (flag_prove_primality)
    {
      /* Factor n-1 for Lucas.  */
      mpz_set (tmp, nm1);
      mp_factor (tmp, &factors);
    }

  /* Loop until Lucas proves our number prime, or Miller-Rabin proves our
     number composite.  */
  for (unsigned int r = 0; r < PRIMES_PTAB_ENTRIES; r++)
    {
      if (flag_prove_primality)
        {
          is_prime = true;
          for (unsigned long int i = 0; i < factors.nfactors && is_prime; i++)
            {
              mpz_divexact (tmp, nm1, factors.p[i]);
              mpz_powm (tmp, a, tmp, n);
              is_prime = mpz_cmp_ui (tmp, 1) != 0;
            }
        }
      else
        {
          /* After enough Miller-Rabin runs, be content. */
          is_prime = (r == MR_REPS - 1);
        }

      if (is_prime)
        goto ret1;

      mpz_add_ui (a, a, primes_diff[r]);        /* Establish new base.  */

      if (!mp_millerrabin (n, nm1, a, tmp, q, k))
        {
          is_prime = false;
          goto ret1;
        }
    }

  error (0, 0, _("Lucas prime test failure.  This should not happen"));
  abort ();

 ret1:
  if (flag_prove_primality)
    mp_factor_clear (&factors);
 ret2:
  mpz_clears (q, a, nm1, tmp, NULL);

  return is_prime;
}
#endif

static void
factor_using_pollard_rho (uintmax_t n, unsigned long int a,
                          struct factors *factors)
{
  uintmax_t x, z, y, P, t, ni, g;

  unsigned long int k = 1;
  unsigned long int l = 1;

  redcify (P, 1, n);
  addmod (x, P, P, n);          /* i.e., redcify(2) */
  y = z = x;

  while (n != 1)
    {
      assert (a < n);

      binv (ni, n);             /* FIXME: when could we use old 'ni' value? */

      for (;;)
        {
          do
            {
              x = mulredc (x, x, n, ni);
              addmod (x, x, a, n);

              submod (t, z, x, n);
              P = mulredc (P, t, n, ni);

              if (k % 32 == 1)
                {
                  if (gcd_odd (P, n) != 1)
                    goto factor_found;
                  y = x;
                }
            }
          while (--k != 0);

          z = x;
          k = l;
          l = 2 * l;
          for (unsigned long int i = 0; i < k; i++)
            {
              x = mulredc (x, x, n, ni);
              addmod (x, x, a, n);
            }
          y = x;
        }

    factor_found:
      do
        {
          y = mulredc (y, y, n, ni);
          addmod (y, y, a, n);

          submod (t, z, y, n);
          g = gcd_odd (t, n);
        }
      while (g == 1);

      if (n == g)
        {
          /* Found n itself as factor.  Restart with different params.  */
          factor_using_pollard_rho (n, a + 1, factors);
          return;
        }

      n = n / g;

      if (!prime_p (g))
        factor_using_pollard_rho (g, a + 1, factors);
      else
        factor_insert (factors, g);

      if (prime_p (n))
        {
          factor_insert (factors, n);
          break;
        }

      x = x % n;
      z = z % n;
      y = y % n;
    }
}

static void
factor_using_pollard_rho2 (uintmax_t n1, uintmax_t n0, unsigned long int a,
                           struct factors *factors)
{
  uintmax_t x1, x0, z1, z0, y1, y0, P1, P0, t1, t0, ni, g1, g0, r1m;

  unsigned long int k = 1;
  unsigned long int l = 1;

  redcify2 (P1, P0, 1, n1, n0);
  addmod2 (x1, x0, P1, P0, P1, P0, n1, n0); /* i.e., redcify(2) */
  y1 = z1 = x1;
  y0 = z0 = x0;

  while (n1 != 0 || n0 != 1)
    {
      binv (ni, n0);

      for (;;)
        {
          do
            {
              x0 = mulredc2 (&r1m, x1, x0, x1, x0, n1, n0, ni);
              x1 = r1m;
              addmod2 (x1, x0, x1, x0, 0, (uintmax_t) a, n1, n0);

              submod2 (t1, t0, z1, z0, x1, x0, n1, n0);
              P0 = mulredc2 (&r1m, P1, P0, t1, t0, n1, n0, ni);
              P1 = r1m;

              if (k % 32 == 1)
                {
                  g0 = gcd2_odd (&g1, P1, P0, n1, n0);
                  if (g1 != 0 || g0 != 1)
                    goto factor_found;
                  y1 = x1; y0 = x0;
                }
            }
          while (--k != 0);

          z1 = x1; z0 = x0;
          k = l;
          l = 2 * l;
          for (unsigned long int i = 0; i < k; i++)
            {
              x0 = mulredc2 (&r1m, x1, x0, x1, x0, n1, n0, ni);
              x1 = r1m;
              addmod2 (x1, x0, x1, x0, 0, (uintmax_t) a, n1, n0);
            }
          y1 = x1; y0 = x0;
        }

    factor_found:
      do
        {
          y0 = mulredc2 (&r1m, y1, y0, y1, y0, n1, n0, ni);
          y1 = r1m;
          addmod2 (y1, y0, y1, y0, 0, (uintmax_t) a, n1, n0);

          submod2 (t1, t0, z1, z0, y1, y0, n1, n0);
          g0 = gcd2_odd (&g1, t1, t0, n1, n0);
        }
      while (g1 == 0 && g0 == 1);

      if (g1 == 0)
        {
          /* The found factor is one word, and > 1. */
          divexact_21 (n1, n0, n1, n0, g0);     /* n = n / g */

          if (!prime_p (g0))
            factor_using_pollard_rho (g0, a + 1, factors);
          else
            factor_insert (factors, g0);
        }
      else
        {
          /* The found factor is two words.  This is highly unlikely, thus hard
             to trigger.  Please be careful before you change this code!  */
          uintmax_t ginv;

          if (n1 == g1 && n0 == g0)
            {
              /* Found n itself as factor.  Restart with different params.  */
              factor_using_pollard_rho2 (n1, n0, a + 1, factors);
              return;
            }

          binv (ginv, g0);      /* Compute n = n / g.  Since the result will */
          n0 = ginv * n0;       /* fit one word, we can compute the quotient */
          n1 = 0;               /* modulo B, ignoring the high divisor word. */

          if (!prime2_p (g1, g0))
            factor_using_pollard_rho2 (g1, g0, a + 1, factors);
          else
            factor_insert_large (factors, g1, g0);
        }

      if (n1 == 0)
        {
          if (prime_p (n0))
            {
              factor_insert (factors, n0);
              break;
            }

          factor_using_pollard_rho (n0, a, factors);
          return;
        }

      if (prime2_p (n1, n0))
        {
          factor_insert_large (factors, n1, n0);
          break;
        }

      x0 = mod2 (&x1, x1, x0, n1, n0);
      z0 = mod2 (&z1, z1, z0, n1, n0);
      y0 = mod2 (&y1, y1, y0, n1, n0);
    }
}

#if HAVE_GMP
static void
mp_factor_using_pollard_rho (mpz_t n, unsigned long int a,
                             struct mp_factors *factors)
{
  mpz_t x, z, y, P;
  mpz_t t, t2;

  devmsg ("[pollard-rho (%lu)] ", a);

  mpz_inits (t, t2, NULL);
  mpz_init_set_si (y, 2);
  mpz_init_set_si (x, 2);
  mpz_init_set_si (z, 2);
  mpz_init_set_ui (P, 1);

  unsigned long long int k = 1;
  unsigned long long int l = 1;

  while (mpz_cmp_ui (n, 1) != 0)
    {
      for (;;)
        {
          do
            {
              mpz_mul (t, x, x);
              mpz_mod (x, t, n);
              mpz_add_ui (x, x, a);

              mpz_sub (t, z, x);
              mpz_mul (t2, P, t);
              mpz_mod (P, t2, n);

              if (k % 32 == 1)
                {
                  mpz_gcd (t, P, n);
                  if (mpz_cmp_ui (t, 1) != 0)
                    goto factor_found;
                  mpz_set (y, x);
                }
            }
          while (--k != 0);

          mpz_set (z, x);
          k = l;
          l = 2 * l;
          for (unsigned long long int i = 0; i < k; i++)
            {
              mpz_mul (t, x, x);
              mpz_mod (x, t, n);
              mpz_add_ui (x, x, a);
            }
          mpz_set (y, x);
        }

    factor_found:
      do
        {
          mpz_mul (t, y, y);
          mpz_mod (y, t, n);
          mpz_add_ui (y, y, a);

          mpz_sub (t, z, y);
          mpz_gcd (t, t, n);
        }
      while (mpz_cmp_ui (t, 1) == 0);

      mpz_divexact (n, n, t);   /* divide by t, before t is overwritten */

      if (!mp_prime_p (t))
        {
          devmsg ("[composite factor--restarting pollard-rho] ");
          mp_factor_using_pollard_rho (t, a + 1, factors);
        }
      else
        {
          mp_factor_insert (factors, t);
        }

      if (mp_prime_p (n))
        {
          mp_factor_insert (factors, n);
          break;
        }

      mpz_mod (x, x, n);
      mpz_mod (z, z, n);
      mpz_mod (y, y, n);
    }

  mpz_clears (P, t2, t, z, x, y, NULL);
}
#endif

#if USE_SQUFOF
/* FIXME: Maybe better to use an iteration converging to 1/sqrt(n)?  If
   algorithm is replaced, consider also returning the remainder. */
static uintmax_t _GL_ATTRIBUTE_CONST
isqrt (uintmax_t n)
{
  uintmax_t x;
  unsigned c;
  if (n == 0)
    return 0;

  count_leading_zeros (c, n);

  /* Make x > sqrt(n). This will be invariant through the loop. */
  x = (uintmax_t) 1 << ((W_TYPE_SIZE + 1 - c) / 2);

  for (;;)
    {
      uintmax_t y = (x + n/x) / 2;
      if (y >= x)
        return x;

      x = y;
    }
}

static uintmax_t _GL_ATTRIBUTE_CONST
isqrt2 (uintmax_t nh, uintmax_t nl)
{
  unsigned int shift;
  uintmax_t x;

  /* Ensures the remainder fits in an uintmax_t. */
  assert (nh < ((uintmax_t) 1 << (W_TYPE_SIZE - 2)));

  if (nh == 0)
    return isqrt (nl);

  count_leading_zeros (shift, nh);
  shift &= ~1;

  /* Make x > sqrt(n) */
  x = isqrt ( (nh << shift) + (nl >> (W_TYPE_SIZE - shift))) + 1;
  x <<= (W_TYPE_SIZE - shift) / 2;

  /* Do we need more than one iteration? */
  for (;;)
    {
      uintmax_t r _GL_UNUSED;
      uintmax_t q, y;
      udiv_qrnnd (q, r, nh, nl, x);
      y = (x + q) / 2;

      if (y >= x)
        {
          uintmax_t hi, lo;
          umul_ppmm (hi, lo, x + 1, x + 1);
          assert (gt2 (hi, lo, nh, nl));

          umul_ppmm (hi, lo, x, x);
          assert (ge2 (nh, nl, hi, lo));
          sub_ddmmss (hi, lo, nh, nl, hi, lo);
          assert (hi == 0);

          return x;
        }

      x = y;
    }
}

/* MAGIC[N] has a bit i set iff i is a quadratic residue mod N. */
# define MAGIC64 0x0202021202030213ULL
# define MAGIC63 0x0402483012450293ULL
# define MAGIC65 0x218a019866014613ULL
# define MAGIC11 0x23b

/* Return the square root if the input is a square, otherwise 0. */
static uintmax_t _GL_ATTRIBUTE_CONST
is_square (uintmax_t x)
{
  /* Uses the tests suggested by Cohen. Excludes 99% of the non-squares before
     computing the square root. */
  if (((MAGIC64 >> (x & 63)) & 1)
      && ((MAGIC63 >> (x % 63)) & 1)
      /* Both 0 and 64 are squares mod (65) */
      && ((MAGIC65 >> ((x % 65) & 63)) & 1)
      && ((MAGIC11 >> (x % 11) & 1)))
    {
      uintmax_t r = isqrt (x);
      if (r*r == x)
        return r;
    }
  return 0;
}

/* invtab[i] = floor(0x10000 / (0x100 + i) */
static const unsigned short invtab[0x81] =
  {
    0x200,
    0x1fc, 0x1f8, 0x1f4, 0x1f0, 0x1ec, 0x1e9, 0x1e5, 0x1e1,
    0x1de, 0x1da, 0x1d7, 0x1d4, 0x1d0, 0x1cd, 0x1ca, 0x1c7,
    0x1c3, 0x1c0, 0x1bd, 0x1ba, 0x1b7, 0x1b4, 0x1b2, 0x1af,
    0x1ac, 0x1a9, 0x1a6, 0x1a4, 0x1a1, 0x19e, 0x19c, 0x199,
    0x197, 0x194, 0x192, 0x18f, 0x18d, 0x18a, 0x188, 0x186,
    0x183, 0x181, 0x17f, 0x17d, 0x17a, 0x178, 0x176, 0x174,
    0x172, 0x170, 0x16e, 0x16c, 0x16a, 0x168, 0x166, 0x164,
    0x162, 0x160, 0x15e, 0x15c, 0x15a, 0x158, 0x157, 0x155,
    0x153, 0x151, 0x150, 0x14e, 0x14c, 0x14a, 0x149, 0x147,
    0x146, 0x144, 0x142, 0x141, 0x13f, 0x13e, 0x13c, 0x13b,
    0x139, 0x138, 0x136, 0x135, 0x133, 0x132, 0x130, 0x12f,
    0x12e, 0x12c, 0x12b, 0x129, 0x128, 0x127, 0x125, 0x124,
    0x123, 0x121, 0x120, 0x11f, 0x11e, 0x11c, 0x11b, 0x11a,
    0x119, 0x118, 0x116, 0x115, 0x114, 0x113, 0x112, 0x111,
    0x10f, 0x10e, 0x10d, 0x10c, 0x10b, 0x10a, 0x109, 0x108,
    0x107, 0x106, 0x105, 0x104, 0x103, 0x102, 0x101, 0x100,
  };

/* Compute q = [u/d], r = u mod d.  Avoids slow hardware division for the case
   that q < 0x40; here it instead uses a table of (Euclidian) inverses.  */
# define div_smallq(q, r, u, d)                                          \
  do {                                                                  \
    if ((u) / 0x40 < (d))                                               \
      {                                                                 \
        int _cnt;                                                       \
        uintmax_t _dinv, _mask, _q, _r;                                 \
        count_leading_zeros (_cnt, (d));                                \
        _r = (u);                                                       \
        if (UNLIKELY (_cnt > (W_TYPE_SIZE - 8)))                        \
          {                                                             \
            _dinv = invtab[((d) << (_cnt + 8 - W_TYPE_SIZE)) - 0x80];   \
            _q = _dinv * _r >> (8 + W_TYPE_SIZE - _cnt);                \
          }                                                             \
        else                                                            \
          {                                                             \
            _dinv = invtab[((d) >> (W_TYPE_SIZE - 8 - _cnt)) - 0x7f];   \
            _q = _dinv * (_r >> (W_TYPE_SIZE - 3 - _cnt)) >> 11;        \
          }                                                             \
        _r -= _q*(d);                                                   \
                                                                        \
        _mask = -(uintmax_t) (_r >= (d));                               \
        (r) = _r - (_mask & (d));                                       \
        (q) = _q - _mask;                                               \
        assert ( (q) * (d) + (r) == u);                                 \
      }                                                                 \
    else                                                                \
      {                                                                 \
        uintmax_t _q = (u) / (d);                                       \
        (r) = (u) - _q * (d);                                           \
        (q) = _q;                                                       \
      }                                                                 \
  } while (0)

/* Notes: Example N = 22117019. After first phase we find Q1 = 6314, Q
   = 3025, P = 1737, representing F_{18} = (-6314, 2* 1737, 3025),
   with 3025 = 55^2.

   Constructing the square root, we get Q1 = 55, Q = 8653, P = 4652,
   representing G_0 = (-55, 2*4652, 8653).

   In the notation of the paper:

   S_{-1} = 55, S_0 = 8653, R_0 = 4652

   Put

     t_0 = floor([q_0 + R_0] / S0) = 1
     R_1 = t_0 * S_0 - R_0 = 4001
     S_1 = S_{-1} +t_0 (R_0 - R_1) = 706
*/

/* Multipliers, in order of efficiency:
   0.7268  3*5*7*11 = 1155 = 3 (mod 4)
   0.7317  3*5*7    =  105 = 1
   0.7820  3*5*11   =  165 = 1
   0.7872  3*5      =   15 = 3
   0.8101  3*7*11   =  231 = 3
   0.8155  3*7      =   21 = 1
   0.8284  5*7*11   =  385 = 1
   0.8339  5*7      =   35 = 3
   0.8716  3*11     =   33 = 1
   0.8774  3        =    3 = 3
   0.8913  5*11     =   55 = 3
   0.8972  5        =    5 = 1
   0.9233  7*11     =   77 = 1
   0.9295  7        =    7 = 3
   0.9934  11       =   11 = 3
*/
# define QUEUE_SIZE 50
#endif

#if STAT_SQUFOF
# define Q_FREQ_SIZE 50
/* Element 0 keeps the total */
static unsigned int q_freq[Q_FREQ_SIZE + 1];
# define MIN(a,b) ((a) < (b) ? (a) : (b))
#endif

#if USE_SQUFOF
/* Return true on success.  Expected to fail only for numbers
   >= 2^{2*W_TYPE_SIZE - 2}, or close to that limit. */
static bool
factor_using_squfof (uintmax_t n1, uintmax_t n0, struct factors *factors)
{
  /* Uses algorithm and notation from

     SQUARE FORM FACTORIZATION
     JASON E. GOWER AND SAMUEL S. WAGSTAFF, JR.

     http://homes.cerias.purdue.edu/~ssw/squfof.pdf
   */

  static const unsigned int multipliers_1[] =
    { /* = 1 (mod 4) */
      105, 165, 21, 385, 33, 5, 77, 1, 0
    };
  static const unsigned int multipliers_3[] =
    { /* = 3 (mod 4) */
      1155, 15, 231, 35, 3, 55, 7, 11, 0
    };

  const unsigned int *m;

  struct { uintmax_t Q; uintmax_t P; } queue[QUEUE_SIZE];

  if (n1 >= ((uintmax_t) 1 << (W_TYPE_SIZE - 2)))
    return false;

  uintmax_t sqrt_n = isqrt2 (n1, n0);

  if (n0 == sqrt_n * sqrt_n)
    {
      uintmax_t p1, p0;

      umul_ppmm (p1, p0, sqrt_n, sqrt_n);
      assert (p0 == n0);

      if (n1 == p1)
        {
          if (prime_p (sqrt_n))
            factor_insert_multiplicity (factors, sqrt_n, 2);
          else
            {
              struct factors f;

              f.nfactors = 0;
              if (!factor_using_squfof (0, sqrt_n, &f))
                {
                  /* Try pollard rho instead */
                  factor_using_pollard_rho (sqrt_n, 1, &f);
                }
              /* Duplicate the new factors */
              for (unsigned int i = 0; i < f.nfactors; i++)
                factor_insert_multiplicity (factors, f.p[i], 2*f.e[i]);
            }
          return true;
        }
    }

  /* Select multipliers so we always get n * mu = 3 (mod 4) */
  for (m = (n0 % 4 == 1) ? multipliers_3 : multipliers_1;
       *m; m++)
    {
      uintmax_t S, Dh, Dl, Q1, Q, P, L, L1, B;
      unsigned int i;
      unsigned int mu = *m;
      unsigned int qpos = 0;

      assert (mu * n0 % 4 == 3);

      /* In the notation of the paper, with mu * n == 3 (mod 4), we
         get \Delta = 4 mu * n, and the paper's \mu is 2 mu. As far as
         I understand it, the necessary bound is 4 \mu^3 < n, or 32
         mu^3 < n.

         However, this seems insufficient: With n = 37243139 and mu =
         105, we get a trivial factor, from the square 38809 = 197^2,
         without any corresponding Q earlier in the iteration.

         Requiring 64 mu^3 < n seems sufficient. */
      if (n1 == 0)
        {
          if ((uintmax_t) mu*mu*mu >= n0 / 64)
            continue;
        }
      else
        {
          if (n1 > ((uintmax_t) 1 << (W_TYPE_SIZE - 2)) / mu)
            continue;
        }
      umul_ppmm (Dh, Dl, n0, mu);
      Dh += n1 * mu;

      assert (Dl % 4 != 1);
      assert (Dh < (uintmax_t) 1 << (W_TYPE_SIZE - 2));

      S = isqrt2 (Dh, Dl);

      Q1 = 1;
      P = S;

      /* Square root remainder fits in one word, so ignore high part. */
      Q = Dl - P*P;
      /* FIXME: When can this differ from floor(sqrt(2 sqrt(D)))? */
      L = isqrt (2*S);
      B = 2*L;
      L1 = mu * 2 * L;

      /* The form is (+/- Q1, 2P, -/+ Q), of discriminant 4 (P^2 + Q Q1) =
         4 D. */

      for (i = 0; i <= B; i++)
        {
          uintmax_t q, P1, t, rem;

          div_smallq (q, rem, S+P, Q);
          P1 = S - rem; /* P1 = q*Q - P */

          IF_LINT (assert (q > 0 && Q > 0));

# if STAT_SQUFOF
          q_freq[0]++;
          q_freq[MIN (q, Q_FREQ_SIZE)]++;
# endif

          if (Q <= L1)
            {
              uintmax_t g = Q;

              if ( (Q & 1) == 0)
                g /= 2;

              g /= gcd_odd (g, mu);

              if (g <= L)
                {
                  if (qpos >= QUEUE_SIZE)
                    die (EXIT_FAILURE, 0, _("squfof queue overflow"));
                  queue[qpos].Q = g;
                  queue[qpos].P = P % g;
                  qpos++;
                }
            }

          /* I think the difference can be either sign, but mod
             2^W_TYPE_SIZE arithmetic should be fine. */
          t = Q1 + q * (P - P1);
          Q1 = Q;
          Q = t;
          P = P1;

          if ( (i & 1) == 0)
            {
              uintmax_t r = is_square (Q);
              if (r)
                {
                  for (unsigned int j = 0; j < qpos; j++)
                    {
                      if (queue[j].Q == r)
                        {
                          if (r == 1)
                            /* Traversed entire cycle. */
                            goto next_multiplier;

                          /* Need the absolute value for divisibility test. */
                          if (P >= queue[j].P)
                            t = P - queue[j].P;
                          else
                            t = queue[j].P - P;
                          if (t % r == 0)
                            {
                              /* Delete entries up to and including entry
                                 j, which matched. */
                              memmove (queue, queue + j + 1,
                                       (qpos - j - 1) * sizeof (queue[0]));
                              qpos -= (j + 1);
                            }
                          goto next_i;
                        }
                    }

                  /* We have found a square form, which should give a
                     factor. */
                  Q1 = r;
                  assert (S >= P); /* What signs are possible? */
                  P += r * ((S - P) / r);

                  /* Note: Paper says (N - P*P) / Q1, that seems incorrect
                     for the case D = 2N. */
                  /* Compute Q = (D - P*P) / Q1, but we need double
                     precision. */
                  uintmax_t hi, lo;
                  umul_ppmm (hi, lo, P, P);
                  sub_ddmmss (hi, lo, Dh, Dl, hi, lo);
                  udiv_qrnnd (Q, rem, hi, lo, Q1);
                  assert (rem == 0);

                  for (;;)
                    {
                      /* Note: There appears to by a typo in the paper,
                         Step 4a in the algorithm description says q <--
                         floor([S+P]/\hat Q), but looking at the equations
                         in Sec. 3.1, it should be q <-- floor([S+P] / Q).
                         (In this code, \hat Q is Q1). */
                      div_smallq (q, rem, S+P, Q);
                      P1 = S - rem;     /* P1 = q*Q - P */

# if STAT_SQUFOF
                      q_freq[0]++;
                      q_freq[MIN (q, Q_FREQ_SIZE)]++;
# endif
                      if (P == P1)
                        break;
                      t = Q1 + q * (P - P1);
                      Q1 = Q;
                      Q = t;
                      P = P1;
                    }

                  if ( (Q & 1) == 0)
                    Q /= 2;
                  Q /= gcd_odd (Q, mu);

                  assert (Q > 1 && (n1 || Q < n0));

                  if (prime_p (Q))
                    factor_insert (factors, Q);
                  else if (!factor_using_squfof (0, Q, factors))
                    factor_using_pollard_rho (Q, 2, factors);

                  divexact_21 (n1, n0, n1, n0, Q);

                  if (prime2_p (n1, n0))
                    factor_insert_large (factors, n1, n0);
                  else
                    {
                      if (!factor_using_squfof (n1, n0, factors))
                        {
                          if (n1 == 0)
                            factor_using_pollard_rho (n0, 1, factors);
                          else
                            factor_using_pollard_rho2 (n1, n0, 1, factors);
                        }
                    }

                  return true;
                }
            }
        next_i:;
        }
    next_multiplier:;
    }
  return false;
}
#endif

/* Compute the prime factors of the 128-bit number (T1,T0), and put the
   results in FACTORS.  */
static void
factor (uintmax_t t1, uintmax_t t0, struct factors *factors)
{
  factors->nfactors = 0;
  factors->plarge[1] = 0;

  if (t1 == 0 && t0 < 2)
    return;

  t0 = factor_using_division (&t1, t1, t0, factors);

  if (t1 == 0 && t0 < 2)
    return;

  if (prime2_p (t1, t0))
    factor_insert_large (factors, t1, t0);
  else
    {
#if USE_SQUFOF
      if (factor_using_squfof (t1, t0, factors))
        return;
#endif

      if (t1 == 0)
        factor_using_pollard_rho (t0, 1, factors);
      else
        factor_using_pollard_rho2 (t1, t0, 1, factors);
    }
}

#if HAVE_GMP
/* Use Pollard-rho to compute the prime factors of
   arbitrary-precision T, and put the results in FACTORS.  */
static void
mp_factor (mpz_t t, struct mp_factors *factors)
{
  mp_factor_init (factors);

  if (mpz_sgn (t) != 0)
    {
      mp_factor_using_division (t, factors);

      if (mpz_cmp_ui (t, 1) != 0)
        {
          devmsg ("[is number prime?] ");
          if (mp_prime_p (t))
            mp_factor_insert (factors, t);
          else
            mp_factor_using_pollard_rho (t, 1, factors);
        }
    }
}
#endif

static strtol_error
strto2uintmax (uintmax_t *hip, uintmax_t *lop, const char *s)
{
  unsigned int lo_carry;
  uintmax_t hi = 0, lo = 0;

  strtol_error err = LONGINT_INVALID;

  /* Skip initial spaces and '+'.  */
  for (;;)
    {
      char c = *s;
      if (c == ' ')
        s++;
      else if (c == '+')
        {
          s++;
          break;
        }
      else
        break;
    }

  /* Initial scan for invalid digits.  */
  const char *p = s;
  for (;;)
    {
      unsigned int c = *p++;
      if (c == 0)
        break;

      if (UNLIKELY (!ISDIGIT (c)))
        {
          err = LONGINT_INVALID;
          break;
        }

      err = LONGINT_OK;           /* we've seen at least one valid digit */
    }

  for (;err == LONGINT_OK;)
    {
      unsigned int c = *s++;
      if (c == 0)
        break;

      c -= '0';

      if (UNLIKELY (hi > ~(uintmax_t)0 / 10))
        {
          err = LONGINT_OVERFLOW;
          break;
        }
      hi = 10 * hi;

      lo_carry = (lo >> (W_TYPE_SIZE - 3)) + (lo >> (W_TYPE_SIZE - 1));
      lo_carry += 10 * lo < 2 * lo;

      lo = 10 * lo;
      lo += c;

      lo_carry += lo < c;
      hi += lo_carry;
      if (UNLIKELY (hi < lo_carry))
        {
          err = LONGINT_OVERFLOW;
          break;
        }
    }

  *hip = hi;
  *lop = lo;

  return err;
}

/* Structure and routines for buffering and outputting full lines,
   to support parallel operation efficiently.  */
static struct lbuf_
{
  char *buf;
  char *end;
} lbuf;

/* 512 is chosen to give good performance,
   and also is the max guaranteed size that
   consumers can read atomically through pipes.
   Also it's big enough to cater for max line length
   even with 128 bit uintmax_t.  */
#define FACTOR_PIPE_BUF 512

static void
lbuf_alloc (void)
{
  if (lbuf.buf)
    return;

  /* Double to ensure enough space for
     previous numbers + next number.  */
  lbuf.buf = xmalloc (FACTOR_PIPE_BUF * 2);
  lbuf.end = lbuf.buf;
}

/* Write complete LBUF to standard output.  */
static void
lbuf_flush (void)
{
  size_t size = lbuf.end - lbuf.buf;
  if (full_write (STDOUT_FILENO, lbuf.buf, size) != size)
    die (EXIT_FAILURE, errno, "%s", _("write error"));
  lbuf.end = lbuf.buf;
}

/* Add a character C to LBUF and if it's a newline
   and enough bytes are already buffered,
   then write atomically to standard output.  */
static void
lbuf_putc (char c)
{
  *lbuf.end++ = c;

  if (c == '\n')
    {
      size_t buffered = lbuf.end - lbuf.buf;

      /* Provide immediate output for interactive input.  */
      static int line_buffered = -1;
      if (line_buffered == -1)
        line_buffered = isatty (STDIN_FILENO);
      if (line_buffered)
        lbuf_flush ();
      else if (buffered >= FACTOR_PIPE_BUF)
        {
          /* Write output in <= PIPE_BUF chunks
             so consumers can read atomically.  */
          char const *tend = lbuf.end;

          /* Since a umaxint_t's factors must fit in 512
             we're guaranteed to find a newline here.  */
          char *tlend = lbuf.buf + FACTOR_PIPE_BUF;
          while (*--tlend != '\n');
          tlend++;

          lbuf.end = tlend;
          lbuf_flush ();

          /* Buffer the remainder.  */
          memcpy (lbuf.buf, tlend, tend - tlend);
          lbuf.end = lbuf.buf + (tend - tlend);
        }
    }
}

/* Buffer an int to the internal LBUF.  */
static void
lbuf_putint (uintmax_t i, size_t min_width)
{
  char buf[INT_BUFSIZE_BOUND (uintmax_t)];
  char const *umaxstr = umaxtostr (i, buf);
  size_t width = sizeof (buf) - (umaxstr - buf) - 1;
  size_t z = width;

  for (; z < min_width; z++)
    *lbuf.end++ = '0';

  memcpy (lbuf.end, umaxstr, width);
  lbuf.end += width;
}

static void
print_uintmaxes (uintmax_t t1, uintmax_t t0)
{
  uintmax_t q, r;

  if (t1 == 0)
    lbuf_putint (t0, 0);
  else
    {
      /* Use very plain code here since it seems hard to write fast code
         without assuming a specific word size.  */
      q = t1 / 1000000000;
      r = t1 % 1000000000;
      udiv_qrnnd (t0, r, r, t0, 1000000000);
      print_uintmaxes (q, t0);
      lbuf_putint (r, 9);
    }
}

/* Single-precision factoring */
static void
print_factors_single (uintmax_t t1, uintmax_t t0)
{
  struct factors factors;

  print_uintmaxes (t1, t0);
  lbuf_putc (':');

  factor (t1, t0, &factors);

  for (unsigned int j = 0; j < factors.nfactors; j++)
    for (unsigned int k = 0; k < factors.e[j]; k++)
      {
        lbuf_putc (' ');
        print_uintmaxes (0, factors.p[j]);
      }

  if (factors.plarge[1])
    {
      lbuf_putc (' ');
      print_uintmaxes (factors.plarge[1], factors.plarge[0]);
    }

  lbuf_putc ('\n');
}

/* Emit the factors of the indicated number.  If we have the option of using
   either algorithm, we select on the basis of the length of the number.
   For longer numbers, we prefer the MP algorithm even if the native algorithm
   has enough digits, because the algorithm is better.  The turnover point
   depends on the value.  */
static bool
print_factors (const char *input)
{
  uintmax_t t1, t0;

  /* Try converting the number to one or two words.  If it fails, use GMP or
     print an error message.  The 2nd condition checks that the most
     significant bit of the two-word number is clear, in a typesize neutral
     way.  */
  strtol_error err = strto2uintmax (&t1, &t0, input);

  switch (err)
    {
    case LONGINT_OK:
      if (((t1 << 1) >> 1) == t1)
        {
          devmsg ("[using single-precision arithmetic] ");
          print_factors_single (t1, t0);
          return true;
        }
      break;

    case LONGINT_OVERFLOW:
      /* Try GMP.  */
      break;

    default:
      error (0, 0, _("%s is not a valid positive integer"), quote (input));
      return false;
    }

#if HAVE_GMP
  devmsg ("[using arbitrary-precision arithmetic] ");
  mpz_t t;
  struct mp_factors factors;

  mpz_init_set_str (t, input, 10);

  gmp_printf ("%Zd:", t);
  mp_factor (t, &factors);

  for (unsigned int j = 0; j < factors.nfactors; j++)
    for (unsigned int k = 0; k < factors.e[j]; k++)
      gmp_printf (" %Zd", factors.p[j]);

  mp_factor_clear (&factors);
  mpz_clear (t);
  putchar ('\n');
  fflush (stdout);
  return true;
#else
  error (0, 0, _("%s is too large"), quote (input));
  return false;
#endif
}

void
usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("\
Usage: %s [NUMBER]...\n\
  or:  %s OPTION\n\
"),
              program_name, program_name);
      fputs (_("\
Print the prime factors of each specified integer NUMBER.  If none\n\
are specified on the command line, read them from standard input.\n\
\n\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}

static bool
do_stdin (void)
{
  bool ok = true;
  token_buffer tokenbuffer;

  init_tokenbuffer (&tokenbuffer);

  while (true)
    {
      size_t token_length = readtoken (stdin, DELIM, sizeof (DELIM) - 1,
                                       &tokenbuffer);
      if (token_length == (size_t) -1)
        break;
      ok &= print_factors (tokenbuffer.buffer);
    }
  free (tokenbuffer.buffer);

  return ok;
}

int
main (int argc, char **argv)
{
  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  lbuf_alloc ();
  atexit (close_stdout);
  atexit (lbuf_flush);

  int c;
  while ((c = getopt_long (argc, argv, "", long_options, NULL)) != -1)
    {
      switch (c)
        {
        case DEV_DEBUG_OPTION:
          dev_debug = true;
          break;

        case_GETOPT_HELP_CHAR;

        case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);

        default:
          usage (EXIT_FAILURE);
        }
    }

#if STAT_SQUFOF
  memset (q_freq, 0, sizeof (q_freq));
#endif

  bool ok;
  if (argc <= optind)
    ok = do_stdin ();
  else
    {
      ok = true;
      for (int i = optind; i < argc; i++)
        if (! print_factors (argv[i]))
          ok = false;
    }

#if STAT_SQUFOF
  if (q_freq[0] > 0)
    {
      double acc_f;
      printf ("q  freq.  cum. freq.(total: %d)\n", q_freq[0]);
      for (unsigned int i = 1, acc_f = 0.0; i <= Q_FREQ_SIZE; i++)
        {
          double f = (double) q_freq[i] / q_freq[0];
          acc_f += f;
          printf ("%s%d %.2f%% %.2f%%\n", i == Q_FREQ_SIZE ? ">=" : "", i,
                  100.0 * f, 100.0 * acc_f);
        }
    }
#endif

  return ok ? EXIT_SUCCESS : EXIT_FAILURE;
}
