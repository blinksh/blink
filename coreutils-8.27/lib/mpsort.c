/* Sort a vector of pointers to data.

   Copyright (C) 2007, 2009-2017 Free Software Foundation, Inc.

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

/* Written by Paul Eggert.  */

#include "config.h"

#include "mpsort.h"

#include <string.h>

/* The type of qsort-style comparison functions.  */

typedef int (*comparison_function) (void const *, void const *);

static void mpsort_with_tmp (void const **restrict, size_t,
                             void const **restrict, comparison_function);

/* Sort a vector BASE containing N pointers, placing the sorted array
   into TMP.  Compare pointers with CMP.  N must be at least 2.  */

static void
mpsort_into_tmp (void const **restrict base, size_t n,
                 void const **restrict tmp,
                 comparison_function cmp)
{
  size_t n1 = n / 2;
  size_t n2 = n - n1;
  size_t a = 0;
  size_t alim = n1;
  size_t b = n1;
  size_t blim = n;
  void const *ba;
  void const *bb;

  mpsort_with_tmp (base + n1, n2, tmp, cmp);
  mpsort_with_tmp (base, n1, tmp, cmp);

  ba = base[a];
  bb = base[b];

  for (;;)
    if (cmp (ba, bb) <= 0)
      {
        *tmp++ = ba;
        a++;
        if (a == alim)
          {
            a = b;
            alim = blim;
            break;
          }
        ba = base[a];
      }
    else
      {
        *tmp++ = bb;
        b++;
        if (b == blim)
          break;
        bb = base[b];
      }

  memcpy (tmp, base + a, (alim - a) * sizeof *base);
}

/* Sort a vector BASE containing N pointers, in place.  Use TMP
   (containing N / 2 pointers) for temporary storage.  Compare
   pointers with CMP.  */

static void
mpsort_with_tmp (void const **restrict base, size_t n,
                 void const **restrict tmp,
                 comparison_function cmp)
{
  if (n <= 2)
    {
      if (n == 2)
        {
          void const *p0 = base[0];
          void const *p1 = base[1];
          if (! (cmp (p0, p1) <= 0))
            {
              base[0] = p1;
              base[1] = p0;
            }
        }
    }
  else
    {
      size_t n1 = n / 2;
      size_t n2 = n - n1;
      size_t i;
      size_t t = 0;
      size_t tlim = n1;
      size_t b = n1;
      size_t blim = n;
      void const *bb;
      void const *tt;

      mpsort_with_tmp (base + n1, n2, tmp, cmp);

      if (n1 < 2)
        tmp[0] = base[0];
      else
        mpsort_into_tmp (base, n1, tmp, cmp);

      tt = tmp[t];
      bb = base[b];

      for (i = 0; ; )
        if (cmp (tt, bb) <= 0)
          {
            base[i++] = tt;
            t++;
            if (t == tlim)
              break;
            tt = tmp[t];
          }
        else
          {
            base[i++] = bb;
            b++;
            if (b == blim)
              {
                memcpy (base + i, tmp + t, (tlim - t) * sizeof *base);
                break;
              }
            bb = base[b];
          }
    }
}

/* Sort a vector BASE containing N pointers, in place.  BASE must
   contain enough storage to hold N + N / 2 vectors; the trailing
   vectors are used for temporaries.  Compare pointers with CMP.  */

void
mpsort (void const **base, size_t n, comparison_function cmp)
{
  mpsort_with_tmp (base, n, base + n, cmp);
}
