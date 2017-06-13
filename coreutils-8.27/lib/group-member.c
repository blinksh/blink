/* group-member.c -- determine whether group id is in calling user's group list

   Copyright (C) 1994, 1997-1998, 2003, 2005-2006, 2009-2017 Free Software
   Foundation, Inc.

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

#include "config.h"

/* Specification.  */
#include <unistd.h>

#include <stdio.h>
#include <sys/types.h>
#include <stdlib.h>

#include "xalloc-oversized.h"

/* Most processes have no more than this many groups, and for these
   processes we can avoid using malloc.  */
enum { GROUPBUF_SIZE = 100 };

struct group_info
  {
    gid_t *group;
    gid_t groupbuf[GROUPBUF_SIZE];
  };

static void
free_group_info (struct group_info const *g)
{
  if (g->group != g->groupbuf)
    free (g->group);
}

static int
get_group_info (struct group_info *gi)
{
  int n_groups = getgroups (GROUPBUF_SIZE, gi->groupbuf);
  gi->group = gi->groupbuf;

  if (n_groups < 0)
    {
      int n_group_slots = getgroups (0, NULL);
      if (0 <= n_group_slots
          && ! xalloc_oversized (n_group_slots, sizeof *gi->group))
        {
          gi->group = malloc (n_group_slots * sizeof *gi->group);
          if (gi->group)
            n_groups = getgroups (n_group_slots, gi->group);
        }
    }

  /* In case of error, the user loses.  */
  return n_groups;
}

/* Return non-zero if GID is one that we have in our groups list.
   Note that the groups list is not guaranteed to contain the current
   or effective group ID, so they should generally be checked
   separately.  */

int
group_member (gid_t gid)
{
  int i;
  int found;
  struct group_info gi;
  int n_groups = get_group_info (&gi);

  /* Search through the list looking for GID. */
  found = 0;
  for (i = 0; i < n_groups; i++)
    {
      if (gid == gi.group[i])
        {
          found = 1;
          break;
        }
    }

  free_group_info (&gi);

  return found;
}

#ifdef TEST

int
main (int argc, char **argv)
{
  int i;

  for (i = 1; i < argc; i++)
    {
      gid_t gid;

      gid = atoi (argv[i]);
      printf ("%d: %s\n", gid, group_member (gid) ? "yes" : "no");
    }
  exit (0);
}

#endif /* TEST */
