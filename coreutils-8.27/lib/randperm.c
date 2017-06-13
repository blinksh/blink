/* Generate random permutations.

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

#include "hash.h"
#include "randperm.h"

#include <limits.h>
#include <stdlib.h>

#include "xalloc.h"

/* Return the ceiling of the log base 2 of N.  If N is zero, return
   an unspecified value.  */

static size_t _GL_ATTRIBUTE_CONST
ceil_lg (size_t n)
{
  size_t b = 0;
  for (n--; n != 0; n /= 2)
    b++;
  return b;
}

/* Return an upper bound on the number of random bytes needed to
   generate the first H elements of a random permutation of N
   elements.  H must not exceed N.  */

size_t
randperm_bound (size_t h, size_t n)
{
  /* Upper bound on number of bits needed to generate the first number
     of the permutation.  */
  size_t lg_n = ceil_lg (n);

  /* Upper bound on number of bits needed to generated the first H elements.  */
  size_t ar = lg_n * h;

  /* Convert the bit count to a byte count.  */
  size_t bound = (ar + CHAR_BIT - 1) / CHAR_BIT;

  return bound;
}

/* Swap elements I and J in array V.  */

static void
swap (size_t *v, size_t i, size_t j)
{
  size_t t = v[i];
  v[i] = v[j];
  v[j] = t;
}

/* Structures and functions for a sparse_map abstract data type that's
   used to effectively swap elements I and J in array V like swap(),
   but in a more memory efficient manner (when the number of permutations
   performed is significantly less than the size of the input).  */

struct sparse_ent_
{
   size_t index;
   size_t val;
};

static size_t
sparse_hash_ (void const *x, size_t table_size)
{
  struct sparse_ent_ const *ent = x;
  return ent->index % table_size;
}

static bool
sparse_cmp_ (void const *x, void const *y)
{
  struct sparse_ent_ const *ent1 = x;
  struct sparse_ent_ const *ent2 = y;
  return ent1->index == ent2->index;
}

typedef Hash_table sparse_map;

/* Initialize the structure for the sparse map,
   when a best guess as to the number of entries
   specified with SIZE_HINT.  */

static sparse_map *
sparse_new (size_t size_hint)
{
  return hash_initialize (size_hint, NULL, sparse_hash_, sparse_cmp_, free);
}

/* Swap the values for I and J.  If a value is not already present
   then assume it's equal to the index.  Update the value for
   index I in array V.  */

static void
sparse_swap (sparse_map *sv, size_t* v, size_t i, size_t j)
{
  struct sparse_ent_ *v1 = hash_delete (sv, &(struct sparse_ent_) {i,0});
  struct sparse_ent_ *v2 = hash_delete (sv, &(struct sparse_ent_) {j,0});

  /* FIXME: reduce the frequency of these mallocs.  */
  if (!v1)
    {
      v1 = xmalloc (sizeof *v1);
      v1->index = v1->val = i;
    }
  if (!v2)
    {
      v2 = xmalloc (sizeof *v2);
      v2->index = v2->val = j;
    }

  size_t t = v1->val;
  v1->val = v2->val;
  v2->val = t;
  if (!hash_insert (sv, v1))
    xalloc_die ();
  if (!hash_insert (sv, v2))
    xalloc_die ();

  v[i] = v1->val;
}

static void
sparse_free (sparse_map *sv)
{
  hash_free (sv);
}


/* From R, allocate and return a malloc'd array of the first H elements
   of a random permutation of N elements.  H must not exceed N.
   Return NULL if H is zero.  */

size_t *
randperm_new (struct randint_source *r, size_t h, size_t n)
{
  size_t *v;

  switch (h)
    {
    case 0:
      v = NULL;
      break;

    case 1:
      v = xmalloc (sizeof *v);
      v[0] = randint_choose (r, n);
      break;

    default:
      {
        /* The algorithm is essentially the same in both
           the sparse and non sparse case.  In the sparse case we use
           a hash to implement sparse storage for the set of n numbers
           we're shuffling.  When to use the sparse method was
           determined with the help of this script:

           #!/bin/sh
           for n in $(seq 2 32); do
             for h in $(seq 2 32); do
               test $h -gt $n && continue
               for s in o n; do
                 test $s = o && shuf=shuf || shuf=./shuf
                 num=$(env time -f "$s:${h},${n} = %e,%M" \
                       $shuf -i0-$((2**$n-2)) -n$((2**$h-2)) | wc -l)
                 test $num = $((2**$h-2)) || echo "$s:${h},${n} = failed" >&2
               done
             done
           done

           This showed that if sparseness = n/h, then:

           sparseness = 128 => .125 mem used, and about same speed
           sparseness =  64 => .25  mem used, but 1.5 times slower
           sparseness =  32 => .5   mem used, but 2 times slower

           Also the memory usage was only significant when n > 128Ki
        */
        bool sparse = (n >= (128 * 1024)) && (n / h >= 32);

        size_t i;
        sparse_map *sv;

        if (sparse)
          {
            sv = sparse_new (h * 2);
            if (sv == NULL)
              xalloc_die ();
            v = xnmalloc (h, sizeof *v);
          }
        else
          {
            sv = NULL; /* To placate GCC's -Wuninitialized.  */
            v = xnmalloc (n, sizeof *v);
            for (i = 0; i < n; i++)
              v[i] = i;
          }

        for (i = 0; i < h; i++)
          {
            size_t j = i + randint_choose (r, n - i);
            if (sparse)
              sparse_swap (sv, v, i, j);
            else
              swap (v, i, j);
          }

        if (sparse)
          sparse_free (sv);
        else
          v = xnrealloc (v, h, sizeof *v);
      }
      break;
    }

  return v;
}
