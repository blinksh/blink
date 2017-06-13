/* cp-hash.c  -- file copying (hash search routines)
   Copyright (C) 1989-2017 Free Software Foundation, Inc.

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

   Written by Torbjorn Granlund, Sweden (tege@sics.se).
   Rewritten to use lib/hash.c by Jim Meyering.  */

#include <config.h>

#include <sys/types.h>
#include "system.h"

#include "hash.h"
#include "cp-hash.h"

/* Use ST_DEV and ST_INO as the key, FILENAME as the value.
   These are used e.g., in copy.c to associate the destination name with
   the source device/inode pair so that if we encounter a matching dev/ino
   pair in the source tree we can arrange to create a hard link between
   the corresponding names in the destination tree.  */
struct Src_to_dest
{
  ino_t st_ino;
  dev_t st_dev;
  /* Destination file name (of non-directory or pre-existing directory)
     corresponding to the dev/ino of a copied file, or the destination file
     name corresponding to a dev/ino pair for a newly-created directory. */
  char *name;
};

/* This table maps source dev/ino to destination file name.
   We use it to preserve hard links when copying.  */
static Hash_table *src_to_dest;

/* Initial size of the above hash table.  */
#define INITIAL_TABLE_SIZE 103

static size_t
src_to_dest_hash (void const *x, size_t table_size)
{
  struct Src_to_dest const *p = x;

  /* Ignoring the device number here should be fine.  */
  /* The cast to uintmax_t prevents negative remainders
     if st_ino is negative.  */
  return (uintmax_t) p->st_ino % table_size;
}

/* Compare two Src_to_dest entries.
   Return true if their keys are judged 'equal'.  */
static bool
src_to_dest_compare (void const *x, void const *y)
{
  struct Src_to_dest const *a = x;
  struct Src_to_dest const *b = y;
  return SAME_INODE (*a, *b) ? true : false;
}

static void
src_to_dest_free (void *x)
{
  struct Src_to_dest *a = x;
  free (a->name);
  free (x);
}

/* Remove the entry matching INO/DEV from the table
   that maps source ino/dev to destination file name.  */
extern void
forget_created (ino_t ino, dev_t dev)
{
  struct Src_to_dest probe;
  struct Src_to_dest *ent;

  probe.st_ino = ino;
  probe.st_dev = dev;
  probe.name = NULL;

  ent = hash_delete (src_to_dest, &probe);
  if (ent)
    src_to_dest_free (ent);
}

/* If INO/DEV correspond to an already-copied source file, return the
   name of the corresponding destination file.  Otherwise, return NULL.  */

extern char *
src_to_dest_lookup (ino_t ino, dev_t dev)
{
  struct Src_to_dest ent;
  struct Src_to_dest const *e;
  ent.st_ino = ino;
  ent.st_dev = dev;
  e = hash_lookup (src_to_dest, &ent);
  return e ? e->name : NULL;
}

/* Add file NAME, copied from inode number INO and device number DEV,
   to the list of files we have copied.
   Return NULL if inserted, otherwise non-NULL. */

extern char *
remember_copied (const char *name, ino_t ino, dev_t dev)
{
  struct Src_to_dest *ent;
  struct Src_to_dest *ent_from_table;

  ent = xmalloc (sizeof *ent);
  ent->name = xstrdup (name);
  ent->st_ino = ino;
  ent->st_dev = dev;

  ent_from_table = hash_insert (src_to_dest, ent);
  if (ent_from_table == NULL)
    {
      /* Insertion failed due to lack of memory.  */
      xalloc_die ();
    }

  /* Determine whether there was already an entry in the table
     with a matching key.  If so, free ENT (it wasn't inserted) and
     return the 'name' from the table entry.  */
  if (ent_from_table != ent)
    {
      src_to_dest_free (ent);
      return (char *) ent_from_table->name;
    }

  /* New key;  insertion succeeded.  */
  return NULL;
}

/* Initialize the hash table.  */
extern void
hash_init (void)
{
  src_to_dest = hash_initialize (INITIAL_TABLE_SIZE, NULL,
                                 src_to_dest_hash,
                                 src_to_dest_compare,
                                 src_to_dest_free);
  if (src_to_dest == NULL)
    xalloc_die ();
}

/* Reset the hash structure in the global variable 'htab' to
   contain no entries.  */

extern void
forget_all (void)
{
  hash_free (src_to_dest);
}
