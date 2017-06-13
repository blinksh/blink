/* Map an ino_t inode number to a small integer.

   Copyright 2009-2017 Free Software Foundation, Inc.

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

/* written by Paul Eggert and Jim Meyering */

#include "config.h"
#include "ino-map.h"

#include "hash.h"
#include "verify.h"

#include <limits.h>
#include <stdlib.h>

/* A pair that maps an inode number to a mapped inode number; the
   latter is a small unique ID for the former.  */
struct ino_map_ent
{
  ino_t ino;
  size_t mapped_ino;
};

/* A table that manages and indexes these pairs.  */
struct ino_map
{
  /* A table of KEY,VAL pairs, where KEY is the raw ino_t value and
     VAL is the small number that it maps to.  */
  struct hash_table *map;

  /* The next mapped inode number to hand out.  */
  size_t next_mapped_ino;

  /* Cache of the most recently allocated and otherwise-unused storage
     for probing the table.  */
  struct ino_map_ent *probe;
};

/* Hash an inode map entry.  */
static size_t
ino_hash (void const *x, size_t table_size)
{
  struct ino_map_ent const *p = x;
  ino_t ino = p->ino;

  /* When INO is wider than size_t, exclusive-OR the words of INO into H.
     This avoids loss of info, without applying % to the wider type,
     which could be quite slow on some systems.  */
  size_t h = ino;
  unsigned int i;
  unsigned int n_words = sizeof ino / sizeof h + (sizeof ino % sizeof h != 0);
  for (i = 1; i < n_words; i++)
    h ^= ino >> CHAR_BIT * sizeof h * i;

  return h % table_size;
}

/* Return true if two inode map entries are the same.  */
static bool
ino_compare (void const *x, void const *y)
{
  struct ino_map_ent const *a = x;
  struct ino_map_ent const *b = y;
  return a->ino == b->ino;
}

/* Allocate an inode map that will hand out integers starting with
   NEXT_MAPPED_INO.  Return NULL if memory is exhausted.  */
struct ino_map *
ino_map_alloc (size_t next_mapped_ino)
{
  struct ino_map *im = malloc (sizeof *im);

  if (im)
    {
      enum { INITIAL_INO_MAP_TABLE_SIZE = 1021 };
      im->map = hash_initialize (INITIAL_INO_MAP_TABLE_SIZE, NULL,
                                 ino_hash, ino_compare, free);
      if (! im->map)
        {
          free (im);
          return NULL;
        }
      im->next_mapped_ino = next_mapped_ino;
      im->probe = NULL;
    }

  return im;
}

/* Free an inode map.  */
void
ino_map_free (struct ino_map *map)
{
  hash_free (map->map);
  free (map->probe);
  free (map);
}


/* Insert into MAP the inode number INO if it's not there already,
   and return its nonnegative mapped inode number.
   If INO is already in MAP, return the existing mapped inode number.
   Return INO_MAP_INSERT_FAILURE on memory or counter exhaustion.  */
size_t
ino_map_insert (struct ino_map *im, ino_t ino)
{
  struct ino_map_ent *ent;

  /* Find space for the probe, reusing the cache if available.  */
  struct ino_map_ent *probe = im->probe;
  if (probe)
    {
      /* If repeating a recent query, return the cached result.   */
      if (probe->ino == ino)
        return probe->mapped_ino;
    }
  else
    {
      im->probe = probe = malloc (sizeof *probe);
      if (! probe)
        return INO_MAP_INSERT_FAILURE;
    }

  probe->ino = ino;
  ent = hash_insert (im->map, probe);
  if (! ent)
    return INO_MAP_INSERT_FAILURE;

  if (ent != probe)
    {
      /* Use the existing entry.  */
      probe->mapped_ino = ent->mapped_ino;
    }
  else
    {
      /* If adding 1 to map->next_mapped_ino would cause it to
         overflow to zero, then it must equal INO_MAP_INSERT_FAILURE,
         which is the value that should be returned in that case.
         Verify that this works.  */
      verify (INO_MAP_INSERT_FAILURE + 1 == 0);

      /* Prepare to allocate a new probe next time; this one is in use.  */
      im->probe = NULL;

      /* INO is new; allocate a mapped inode number for it.  */
      probe->mapped_ino = im->next_mapped_ino++;
    }

  return probe->mapped_ino;
}
