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

#ifndef _GL_RAND_ISAAC_H
#define _GL_RAND_ISAAC_H

#include <stddef.h>
#include <stdint.h>

/* Log base 2 of the number of useful bits in an ISAAC word.  It must
   be either 5 or 6.  By default, this uses a value that should be
   faster for this architecture.  */
#ifndef ISAAC_BITS_LOG
 #if SIZE_MAX >> 31 >> 31 < 3 /* SIZE_MAX < 2**64 - 1 */
  #define ISAAC_BITS_LOG 5
 #else
  #define ISAAC_BITS_LOG 6
 #endif
#endif

/* The number of bits in an ISAAC word.  */
#define ISAAC_BITS (1 << ISAAC_BITS_LOG)

#if ISAAC_BITS == 32
  typedef uint_least32_t isaac_word;
#else
  typedef uint_least64_t isaac_word;
#endif

/* Size of the state tables to use.  ISAAC_WORDS_LOG should be at least 3,
   and smaller values give less security.  */
#define ISAAC_WORDS_LOG 8
#define ISAAC_WORDS (1 << ISAAC_WORDS_LOG)
#define ISAAC_BYTES (ISAAC_WORDS * sizeof (isaac_word))

/* State variables for the random number generator.  The M member
   should be seeded with nonce data before calling isaac_seed.  The
   other members are private.  */
struct isaac_state
  {
    isaac_word m[ISAAC_WORDS];	/* Main state array */
    isaac_word a, b, c;		/* Extra variables */
  };

void isaac_seed (struct isaac_state *);
void isaac_refill (struct isaac_state *, isaac_word[ISAAC_WORDS]);

#endif
