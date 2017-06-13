/* group-list.c --Print a list of group IDs or names.
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
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* Written by Arnold Robbins.
   Major rewrite by David MacKenzie, djm@gnu.ai.mit.edu.
   Extracted from id.c by James Youngman. */

#include <config.h>
#include <stdio.h>
#include <sys/types.h>
#include <pwd.h>
#include <grp.h>

#include "system.h"
#include "error.h"
#include "mgetgroups.h"
#include "quote.h"
#include "group-list.h"


/* Print all of the distinct groups the user is in. */
extern bool
print_group_list (const char *username,
                  uid_t ruid, gid_t rgid, gid_t egid,
                  bool use_names, char delim)
{
  bool ok = true;
  struct passwd *pwd = NULL;

  if (username)
    {
      pwd = getpwuid (ruid);
      if (pwd == NULL)
        ok = false;
    }

  if (!print_group (rgid, use_names))
    ok = false;

  if (egid != rgid)
    {
      putchar (delim);
      if (!print_group (egid, use_names))
        ok = false;
    }

  {
    gid_t *groups;
    int i;

    int n_groups = xgetgroups (username, (pwd ? pwd->pw_gid : egid), &groups);
    if (n_groups < 0)
      {
        if (username)
          {
            error (0, errno, _("failed to get groups for user %s"),
                   quote (username));
          }
        else
          {
            error (0, errno, _("failed to get groups for the current process"));
          }
        return false;
      }

    for (i = 0; i < n_groups; i++)
      if (groups[i] != rgid && groups[i] != egid)
        {
          putchar (delim);
          if (!print_group (groups[i], use_names))
            ok = false;
        }
    free (groups);
  }
  return ok;
}

/* Convert a gid_t to string.  Do not use this function directly.
   Instead, use it via the gidtostr macro.
   Beware that it returns a pointer to static storage.  */
static char *
gidtostr_ptr (gid_t const *gid)
{
  static char buf[INT_BUFSIZE_BOUND (uintmax_t)];
  return umaxtostr (*gid, buf);
}
#define gidtostr(g) gidtostr_ptr (&(g))

/* Print the name or value of group ID GID. */
extern bool
print_group (gid_t gid, bool use_name)
{
  struct group *grp = NULL;
  bool ok = true;

  if (use_name)
    {
      grp = getgrgid (gid);
      if (grp == NULL)
        {
          error (0, 0, _("cannot find name for group ID %lu"),
                 (unsigned long int) gid);
          ok = false;
        }
    }

  char *s = grp ? grp->gr_name : gidtostr (gid);
  fputs (s, stdout);
  return ok;
}
