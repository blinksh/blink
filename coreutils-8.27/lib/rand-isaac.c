/* Bob Jenkins's cryptographic random number generators, ISAAC and ISAAC64.

   Copyright (C) 1999-2017 Free Software Foundation, Inc.
   Copyright (C) 1997, 1998, 1999 Colin Plumb.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.

   Written by Colin Plumb and Paul Eggert.  */

/*
 * --------------------------------------------------------------------
 * We need a source of random numbers for some data.
 * Cryptographically secure is desirable, but it's not life-or-death
 * so I can be a little bit experimental in the choice of RNGs here.
 *
 * This generator is based somewhat on RC4, but has analysis
 * <http://burtleburtle.net/bob/rand/isaacafa.html>
 * pointing to it actually being better.  I like it because it's nice
 * and fast, and because the author did good work analyzing it.
 * --------------------------------------------------------------------
 */
#include "config.h"

#include "rand-isaac.h"

#include <limits.h>
#include <string.h>

/* If the platform supports unaligned access,
   then don't have -fsanitize=undefined warn about it.  */
#undef ATTRIBUTE_NO_WARN_SANITIZE_UNDEFINED
#if !(_STRING_ARCH_unaligned || _STRING_INLINE_unaligned) \
    || __GNUC__ < 4 || (__GNUC__ == 4 && __GNUC_MINOR__ < 9)
# define ATTRIBUTE_NO_WARN_SANITIZE_UNDEFINED /* empty */
#else
# define ATTRIBUTE_NO_WARN_SANITIZE_UNDEFINED \
  __attribute__ ((__no_sanitize_undefined__))
#endif

/* The minimum of two sizes A and B.  */
static inline size_t
min (size_t a, size_t b)
{
  return (a < b ? a : b);
}

/* A if 32-bit ISAAC, B if 64-bit.  This is a macro, not an inline
   function, to prevent undefined behavior if the unused argument
   shifts by more than a word width.  */
#define IF32(a, b) (ISAAC_BITS == 32 ? (a) : (b))

/* Discard bits outside the desired range.  On typical machines, any
   decent compiler should optimize this function call away to nothing.
   But machines with pad bits in integers may need to do more work.  */
static inline isaac_word
just (isaac_word a)
{
  isaac_word desired_bits = ((isaac_word) 1 << 1 << (ISAAC_BITS - 1)) - 1;
  return a & desired_bits;
}

/* The index operation.  */
static inline isaac_word
ind (isaac_word const *m, isaac_word x)
{
  if (sizeof *m * CHAR_BIT == ISAAC_BITS)
    {
      /* The typical case, where words are exactly the right size.
         Optimize this to a mask, an addition, and an indirect
         load.  */
      void const *void_m = m;
      char const *base_p = void_m;
      void const *word_p = base_p + (x & ((ISAAC_WORDS - 1) * sizeof *m));
      isaac_word const *p = word_p;
      return *p;
    }
  else
    {
      /* Atypical machines need more work.  */
      return m[(x / (ISAAC_BITS / CHAR_BIT)) & (ISAAC_WORDS - 1)];
    }
}

/* Use and update *S to generate random data to fill RESULT.  */
void ATTRIBUTE_NO_WARN_SANITIZE_UNDEFINED
isaac_refill (struct isaac_state *s, isaac_word result[ISAAC_WORDS])
{
  /* Caches of S->a and S->b.  */
  isaac_word a = s->a;
  isaac_word b = s->b + (++s->c);

  /* Pointers into state array and into result.  */
  isaac_word *m = s->m;
  isaac_word *r = result;

  enum { HALF = ISAAC_WORDS / 2 };

  /* The central step.  S->m is the whole state array, while M is a
     pointer to the current word.  OFF is the offset from M to the
     word ISAAC_WORDS/2 words away in the SM array, i.e., +/-
     ISAAC_WORDS/2.  A and B are state variables, and R the result.
     This updates A, B, M[I], and R[I].  */
  #define ISAAC_STEP(i, off, mix)                             \
    {                                                         \
      isaac_word x, y;                                        \
      a = (IF32 (a, 0) ^ (mix)) + m[off + (i)];               \
      x = m[i];                                               \
      m[i] = y = ind (s->m, x) + a + b;                       \
      r[i] = b = just (ind (s->m, y >> ISAAC_WORDS_LOG) + x); \
    }

  do
    {
      ISAAC_STEP (0, HALF, IF32 (      a  << 13, ~ (a ^ (a << 21))));
      ISAAC_STEP (1, HALF, IF32 (just (a) >>  6, a ^ (just (a) >>  5)));
      ISAAC_STEP (2, HALF, IF32 (      a  <<  2, a ^ (      a  << 12)));
      ISAAC_STEP (3, HALF, IF32 (just (a) >> 16, a ^ (just (a) >> 33)));
      r += 4;
    }
  while ((m += 4) < s->m + HALF);

  do
    {
      ISAAC_STEP (0, -HALF, IF32 (      a  << 13, ~ (a ^ (a << 21))));
      ISAAC_STEP (1, -HALF, IF32 (just (a) >>  6, a ^ (just (a) >>  5)));
      ISAAC_STEP (2, -HALF, IF32 (      a  <<  2, a ^ (      a  << 12)));
      ISAAC_STEP (3, -HALF, IF32 (just (a) >> 16, a ^ (just (a) >> 33)));
      r += 4;
    }
  while ((m += 4) < s->m + ISAAC_WORDS);

  s->a = a;
  s->b = b;
}

/*
 * The basic seed-scrambling step for initialization, based on Bob
 * Jenkins' 256-bit hash.
 */
#if ISAAC_BITS == 32
 #define mix(a, b, c, d, e, f, g, h)       \
    {                                      \
              a ^=       b  << 11; d += a; \
      b += c; b ^= just (c) >>  2; e += b; \
      c += d; c ^=       d  <<  8; f += c; \
      d += e; d ^= just (e) >> 16; g += d; \
      e += f; e ^=       f  << 10; h += e; \
      f += g; f ^= just (g) >>  4; a += f; \
      g += h; g ^=       h  <<  8; b += g; \
      h += a; h ^= just (a) >>  9; c += h; \
      a += b;                              \
    }
#else
 #define mix(a, b, c, d, e, f, g, h)       \
    {                                      \
      a -= e; f ^= just (h) >>  9; h += a; \
      b -= f; g ^=       a  <<  9; a += b; \
      c -= g; h ^= just (b) >> 23; b += c; \
      d -= h; a ^=       c  << 15; c += d; \
      e -= a; b ^= just (d) >> 14; d += e; \
      f -= b; c ^=       e  << 20; e += f; \
      g -= c; d ^= just (f) >> 17; f += g; \
      h -= d; e ^=       g  << 14; g += h; \
    }
#endif


/* The basic ISAAC initialization pass.  */
#define ISAAC_MIX(s, a, b, c, d, e, f, g, h, seed) \
  {                                                \
    int i;                                         \
                                                   \
    for (i = 0; i < ISAAC_WORDS; i += 8)           \
      {                                            \
        a += seed[i];                              \
        b += seed[i + 1];                          \
        c += seed[i + 2];                          \
        d += seed[i + 3];                          \
        e += seed[i + 4];                          \
        f += seed[i + 5];                          \
        g += seed[i + 6];                          \
        h += seed[i + 7];                          \
        mix (a, b, c, d, e, f, g, h);              \
        s->m[i] = a;                               \
        s->m[i + 1] = b;                           \
        s->m[i + 2] = c;                           \
        s->m[i + 3] = d;                           \
        s->m[i + 4] = e;                           \
        s->m[i + 5] = f;                           \
        s->m[i + 6] = g;                           \
        s->m[i + 7] = h;                           \
      }                                            \
  }

#if 0 /* Provided for reference only; not used in this code */
/*
 * Initialize the ISAAC RNG with the given seed material.
 * Its size MUST be a multiple of ISAAC_BYTES, and may be
 * stored in the s->m array.
 *
 * This is a generalization of the original ISAAC initialization code
 * to support larger seed sizes.  For seed sizes of 0 and ISAAC_BYTES,
 * it is identical.
 */
static void
isaac_init (struct isaac_state *s, isaac_word const *seed, size_t seedsize)
{
  isaac_word a, b, c, d, e, f, g, h;

  a = b = c = d = e = f = g = h =          /* the golden ratio */
    IF32 (UINT32_C (0x9e3779b9), UINT64_C (0x9e3779b97f4a7c13));
  for (int i = 0; i < 4; i++)              /* scramble it */
    mix (a, b, c, d, e, f, g, h);
  s->a = s->b = s->c = 0;

  if (seedsize)
    {
      /* First pass (as in reference ISAAC code) */
      ISAAC_MIX (s, a, b, c, d, e, f, g, h, seed);
      /* Second and subsequent passes (extension to ISAAC) */
      while (seedsize -= ISAAC_BYTES)
        {
          seed += ISAAC_WORDS;
          for (i = 0; i < ISAAC_WORDS; i++)
            s->m[i] += seed[i];
          ISAAC_MIX (s, a, b, c, d, e, f, g, h, s->m);
        }
    }
  else
    {
      /* The no seed case (as in reference ISAAC code) */
      for (i = 0; i < ISAAC_WORDS; i++)
        s->m[i] = 0;
    }

  /* Final pass */
  ISAAC_MIX (s, a, b, c, d, e, f, g, h, s->m);
}
#endif

/* Initialize *S to a somewhat-random value, derived from a seed
   stored in S->m.  */
void
isaac_seed (struct isaac_state *s)
{
  isaac_word a = IF32 (UINT32_C (0x1367df5a), UINT64_C (0x647c4677a2884b7c));
  isaac_word b = IF32 (UINT32_C (0x95d90059), UINT64_C (0xb9f8b322c73ac862));
  isaac_word c = IF32 (UINT32_C (0xc3163e4b), UINT64_C (0x8c0ea5053d4712a0));
  isaac_word d = IF32 (UINT32_C (0x0f421ad8), UINT64_C (0xb29b2e824a595524));
  isaac_word e = IF32 (UINT32_C (0xd92a4a78), UINT64_C (0x82f053db8355e0ce));
  isaac_word f = IF32 (UINT32_C (0xa51a3c49), UINT64_C (0x48fe4a0fa5a09315));
  isaac_word g = IF32 (UINT32_C (0xc4efea1b), UINT64_C (0xae985bf2cbfc89ed));
  isaac_word h = IF32 (UINT32_C (0x30609119), UINT64_C (0x98f5704f6c44c0ab));

#if 0
  /* The initialization of a through h is a precomputed form of: */
  a = b = c = d = e = f = g = h =          /* the golden ratio */
    IF32 (UINT32_C (0x9e3779b9), UINT64_C (0x9e3779b97f4a7c13));
  for (int i = 0; i < 4; i++)              /* scramble it */
    mix (a, b, c, d, e, f, g, h);
#endif

  /* Mix S->m so that every part of the seed affects every part of the
     state.  */
  ISAAC_MIX (s, a, b, c, d, e, f, g, h, s->m);
  ISAAC_MIX (s, a, b, c, d, e, f, g, h, s->m);

  s->a = s->b = s->c = 0;
}
