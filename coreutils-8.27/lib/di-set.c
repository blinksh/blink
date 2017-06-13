/* Set operations for device-inode pairs stored in a space-efficient manner.

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
#include "di-set.h"

#include "hash.h"
#include "ino-map.h"

#include <limits.h>
#include <stdlib.h>

/* The hash package hashes "void *", but this package wants to hash
   integers.  Use integers that are as large as possible, but no
   larger than void *, so that they can be cast to void * and back
   without losing information.  */
typedef size_t hashint;
#define HASHINT_MAX ((hashint) -1)

/* Integers represent inode numbers.  Integers in the range
   1..(LARGE_INO_MIN-1) represent inode numbers directly.  (The hash
   package does not work with null pointers, so inode 0 cannot be used
   as a key.)  To find the representations of other inode numbers, map
   them through INO_MAP.  */
#define LARGE_INO_MIN (HASHINT_MAX / 2)

/* Set operations for device-inode pairs stored in a space-efficient
   manner.  Use a two-level hash table.  The top level hashes by
   device number, as there are typically a small number of devices.
   The lower level hashes by mapped inode numbers.  In the typical
   case where the inode number is positive and small, the inode number
   maps to itself, masquerading as a void * value; otherwise, its
   value is the result of hashing the inode value through INO_MAP.  */

/* A pair that maps a device number to a set of inode numbers.  */
struct di_ent
{
  dev_t dev;
  struct hash_table *ino_set;
};

/* A two-level hash table that manages and indexes these pairs.  */
struct di_set
{
  /* Map device numbers to sets of inode number representatives.  */
  struct hash_table *dev_map;

  /* If nonnull, map large inode numbers to their small
     representatives.  If null, there are no large inode numbers in
     this set.  */
  struct ino_map *ino_map;

  /* Cache of the most recently allocated and otherwise-unused storage
     for probing this table.  */
  struct di_ent *probe;
};

/* Hash a device-inode-set entry.  */
static size_t
di_ent_hash (void const *x, size_t table_size)
{
  struct di_ent const *p = x;
  dev_t dev = p->dev;

  /* When DEV is wider than size_t, exclusive-OR the words of DEV into H.
     This avoids loss of info, without applying % to the wider type,
     which could be quite slow on some systems.  */
  size_t h = dev;
  unsigned int i;
  unsigned int n_words = sizeof dev / sizeof h + (sizeof dev % sizeof h != 0);
  for (i = 1; i < n_words; i++)
    h ^= dev >> CHAR_BIT * sizeof h * i;

  return h % table_size;
}

/* Return true if two device-inode-set entries are the same.  */
static bool
di_ent_compare (void const *x, void const *y)
{
  struct di_ent const *a = x;
  struct di_ent const *b = y;
  return a->dev == b->dev;
}

/* Free a device-inode-set entry.  */
static void
di_ent_free (void *v)
{
  struct di_ent *a = v;
  hash_free (a->ino_set);
  free (a);
}

/* Create a set of device-inode pairs.  Return NULL on allocation failure.  */
struct di_set *
di_set_alloc (void)
{
  struct di_set *dis = malloc (sizeof *dis);
  if (dis)
    {
      enum { INITIAL_DEV_MAP_SIZE = 11 };
      dis->dev_map = hash_initialize (INITIAL_DEV_MAP_SIZE, NULL,
                                      di_ent_hash, di_ent_compare,
                                      di_ent_free);
      if (! dis->dev_map)
        {
          free (dis);
          return NULL;
        }
      dis->ino_map = NULL;
      dis->probe = NULL;
    }

  return dis;
}

/* Free a set of device-inode pairs.  */
void
di_set_free (struct di_set *dis)
{
  hash_free (dis->dev_map);
  free (dis->ino_map);
  free (dis->probe);
  free (dis);
}

/* Hash an encoded inode number I.  */
static size_t
di_ino_hash (void const *i, size_t table_size)
{
  return (hashint) i % table_size;
}

/* Using the DIS table, map a device to a hash table that represents
   a set of inode numbers.  Return NULL on error.  */
static struct hash_table *
map_device (struct di_set *dis, dev_t dev)
{
  /* Find space for the probe, reusing the cache if available.  */
  struct di_ent *ent;
  struct di_ent *probe = dis->probe;
  if (probe)
    {
      /* If repeating a recent query, return the cached result.   */
      if (probe->dev == dev)
        return probe->ino_set;
    }
  else
    {
      dis->probe = probe = malloc (sizeof *probe);
      if (! probe)
        return NULL;
    }

  /* Probe for the device.  */
  probe->dev = dev;
  ent = hash_insert (dis->dev_map, probe);
  if (! ent)
    return NULL;

  if (ent != probe)
    {
      /* Use the existing entry.  */
      probe->ino_set = ent->ino_set;
    }
  else
    {
      enum { INITIAL_INO_SET_SIZE = 1021 };

      /* Prepare to allocate a new probe next time; this one is in use.  */
      dis->probe = NULL;

      /* DEV is new; allocate an inode set for it.  */
      probe->ino_set = hash_initialize (INITIAL_INO_SET_SIZE, NULL,
                                        di_ino_hash, NULL, NULL);
    }

  return probe->ino_set;
}

/* Using the DIS table, map an inode number to a mapped value.
   Return INO_MAP_INSERT_FAILURE on error.  */
static hashint
map_inode_number (struct di_set *dis, ino_t ino)
{
  if (0 < ino && ino < LARGE_INO_MIN)
    return ino;

  if (! dis->ino_map)
    {
      dis->ino_map = ino_map_alloc (LARGE_INO_MIN);
      if (! dis->ino_map)
        return INO_MAP_INSERT_FAILURE;
    }

  return ino_map_insert (dis->ino_map, ino);
}

/* Attempt to insert the DEV,INO pair into the set DIS.
   If it matches a pair already in DIS, keep that pair and return 0.
   Otherwise, if insertion is successful, return 1.
   Upon any failure return -1.  */
int
di_set_insert (struct di_set *dis, dev_t dev, ino_t ino)
{
  hashint i;

  /* Map the device number to a set of inodes.  */
  struct hash_table *ino_set = map_device (dis, dev);
  if (! ino_set)
    return -1;

  /* Map the inode number to a small representative I.  */
  i = map_inode_number (dis, ino);
  if (i == INO_MAP_INSERT_FAILURE)
    return -1;

  /* Put I into the inode set.  */
  return hash_insert_if_absent (ino_set, (void const *) i, NULL);
}

/* Look up the DEV,INO pair in the set DIS.
   If found, return 1; if not found, return 0.
   Upon any failure return -1.  */
int
di_set_lookup (struct di_set *dis, dev_t dev, ino_t ino)
{
  hashint i;

  /* Map the device number to a set of inodes.  */
  struct hash_table *ino_set = map_device (dis, dev);
  if (! ino_set)
    return -1;

  /* Map the inode number to a small representative I.  */
  i = map_inode_number (dis, ino);
  if (i == INO_MAP_INSERT_FAILURE)
    return -1;

  /* Perform the look-up.  */
  return !!hash_lookup (ino_set, (void const *) i);
}
