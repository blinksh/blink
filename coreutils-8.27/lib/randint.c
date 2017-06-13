/* Generate random integers.

   Copyright (C) 2006-2017 Free Software Foundation, Inc.

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

/* Written by Paul Eggert.  */

#include "config.h"

#include "randint.h"

#include <errno.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>


#if TEST
# include <inttypes.h>
# include <stdio.h>

int
main (int argc, char **argv)
{
  randint i;
  randint n = strtoumax (argv[1], NULL, 10);
  randint choices = strtoumax (argv[2], NULL, 10);
  char const *name = argv[3];
  struct randint_source *ints = randint_all_new (name, SIZE_MAX);

  for (i = 0; i < n; i++)
    printf ("%"PRIuMAX"\n", randint_choose (ints, choices));

  return (randint_all_free (ints) == 0 ? EXIT_SUCCESS : EXIT_FAILURE);
}
#endif


#include "xalloc.h"

/* A source of random data for generating random integers.  */
struct randint_source
{
  /* The source of random bytes.  */
  struct randread_source *source;

  /* RANDNUM is a buffered random integer, whose information has not
     yet been delivered to the caller.  It is uniformly distributed in
     the range 0 <= RANDNUM <= RANDMAX.  If RANDMAX is zero, then
     RANDNUM must be zero (and in some sense it is not really
     "random").  */
  randint randnum;
  randint randmax;
};

/* Create a new randint_source from SOURCE.  */

struct randint_source *
randint_new (struct randread_source *source)
{
  struct randint_source *s = xmalloc (sizeof *s);
  s->source = source;
  s->randnum = s->randmax = 0;
  return s;
}

/* Create a new randint_source by creating a randread_source from
   NAME and ESTIMATED_BYTES.  Return NULL (setting errno) if
   unsuccessful.  */

struct randint_source *
randint_all_new (char const *name, size_t bytes_bound)
{
  struct randread_source *source = randread_new (name, bytes_bound);
  return (source ? randint_new (source) : NULL);
}

/* Return the random data source of *S.  */

struct randread_source *
randint_get_source (struct randint_source const *s)
{
  return s->source;
}

/* HUGE_BYTES is true on hosts hosts where randint and unsigned char
   have the same width and where shifting by the word size therefore
   has undefined behavior.  */
enum { HUGE_BYTES = RANDINT_MAX == UCHAR_MAX };

/* Return X shifted left by CHAR_BIT bits.  */
static inline randint shift_left (randint x)
{
  return HUGE_BYTES ? 0 : x << CHAR_BIT;
}

/* Return X shifted right by CHAR_BIT bits.  */
static inline randint
shift_right (randint x)
{
  return HUGE_BYTES ? 0 : x >> CHAR_BIT;
}


/* Consume random data from *S to generate a random number in the range
   0 .. GENMAX.  */

randint
randint_genmax (struct randint_source *s, randint genmax)
{
  struct randread_source *source = s->source;
  randint randnum = s->randnum;
  randint randmax = s->randmax;
  randint choices = genmax + 1;

  while (1)
    {
      if (randmax < genmax)
        {
          /* Calculate how many input bytes will be needed, and read
             the bytes.  */

          size_t i = 0;
          randint rmax = randmax;
          unsigned char buf[sizeof randnum];

          do
            {
              rmax = shift_left (rmax) + UCHAR_MAX;
              i++;
            }
          while (rmax < genmax);

          randread (source, buf, i);

          /* Increase RANDMAX by appending random bytes to RANDNUM and
             UCHAR_MAX to RANDMAX until RANDMAX is no less than
             GENMAX.  This may lose up to CHAR_BIT bits of information
             if shift_right (RANDINT_MAX) < GENMAX, but it is not
             worth the programming hassle of saving these bits since
             GENMAX is rarely that large in practice.  */

          i = 0;

          do
            {
              randnum = shift_left (randnum) + buf[i];
              randmax = shift_left (randmax) + UCHAR_MAX;
              i++;
            }
          while (randmax < genmax);
        }

      if (randmax == genmax)
        {
          s->randnum = s->randmax = 0;
          return randnum;
        }
      else
        {
          /* GENMAX < RANDMAX, so attempt to generate a random number
             by taking RANDNUM modulo GENMAX+1.  This will choose
             fairly so long as RANDNUM falls within an integral
             multiple of GENMAX+1; otherwise, LAST_USABLE_CHOICE < RANDNUM,
             so discard this attempt and try again.

             Since GENMAX cannot be RANDINT_MAX, CHOICES cannot be
             zero and there is no need to worry about dividing by
             zero.  */

          randint excess_choices = randmax - genmax;
          randint unusable_choices = excess_choices % choices;
          randint last_usable_choice = randmax - unusable_choices;
          randint reduced_randnum = randnum % choices;

          if (randnum <= last_usable_choice)
            {
              s->randnum = randnum / choices;
              s->randmax = excess_choices / choices;
              return reduced_randnum;
            }

          /* Retry, but retain the randomness from the fact that RANDNUM fell
             into the range LAST_USABLE_CHOICE+1 .. RANDMAX.  */
          randnum = reduced_randnum;
          randmax = unusable_choices - 1;
        }
    }
}

/* Clear *S so that it no longer contains undelivered random data.  */

void
randint_free (struct randint_source *s)
{
  memset (s, 0, sizeof *s);
  free (s);
}

/* Likewise, but also clear the underlying randread object.  Return
   0 if successful, -1 (setting errno) otherwise.  */

int
randint_all_free (struct randint_source *s)
{
  int r = randread_free (s->source);
  int e = errno;
  randint_free (s);
  errno = e;
  return r;
}
