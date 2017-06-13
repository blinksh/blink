/* Test userspec.c
   Copyright (C) 2009-2017 Free Software Foundation, Inc.

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

/* Written by Jim Meyering.  */

#include <config.h>

#include "userspec.h"

#include <stdio.h>
#include <assert.h>
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>
#include <sys/types.h>
#include <pwd.h>
#include <grp.h>

#include "xalloc.h"

#define ARRAY_CARDINALITY(Array) (sizeof (Array) / sizeof *(Array))

struct test
{
  const char *in;
  uid_t uid;
  gid_t gid;
  const char *user_name;
  const char *group_name;
  const char *result;
};

static struct test T[] =
  {
    { "",                       -1, -1, "",   "",   NULL},
    { ":",                      -1, -1, "",   "",   NULL},
    { "+0:+0",                   0,  0, "",   "",   NULL},
    { ":+1",                    -1,  1, "",   "",   NULL},
    { "+1",                      1, -1, "",   "",   NULL},
    { ":+0",                    -1,  0, "",   "",   NULL},
    { "+22:+42",                22, 42, "",   "",   NULL},
    /* (uint32_t)-1 should be invalid everywhere */
    { "+4294967295:+4294967295", 0,  0, NULL, NULL, "invalid user"},
    /* likewise, but with only the group being invalid */
    { "+0:+4294967295",          0,  0, NULL, NULL, "invalid group"},
    { ":+4294967295",            0,  0, NULL, NULL, "invalid group"},
    /* and only the user being invalid */
    { "+4294967295:+0",          0,  0, NULL, NULL, "invalid user"},
    /* and using 2^32 */
    { "+4294967296:+4294967296", 0,  0, NULL, NULL, "invalid user"},
    { "+0:+4294967296",          0,  0, NULL, NULL, "invalid group"},
    { ":+4294967296",            0,  0, NULL, NULL, "invalid group"},
    { "+4294967296:+0",          0,  0, NULL, NULL, "invalid user"},
    /* numeric user and no group is invalid */
    { "+4294967295:",            0,  0, NULL, NULL, "invalid spec"},
    { "+4294967296:",            0,  0, NULL, NULL, "invalid spec"},
    { "+1:",                     0,  0, NULL, NULL, "invalid spec"},
    { "+0:",                     0,  0, NULL, NULL, "invalid spec"},

    /* "username:" must expand to UID:GID where GID is username's login group */
    /* Add an entry like the following to the table, if possible.
    { "U_NAME:",              UID,GID, U_NAME, G_NAME, NULL}, */
    { NULL,                     0,  0, NULL, NULL, ""},  /* place-holder */

    { NULL,                     0,  0, NULL, NULL, ""}
  };

#define STREQ(a, b) (strcmp (a, b) == 0)

static char const *
maybe_null (char const *s)
{
  return s ? s : "NULL";
}

static bool
same_diag (char const *s, char const *t)
{
  if (s == NULL && t == NULL)
    return true;
  if (s == NULL || t == NULL)
    return false;
  return STREQ (s, t);
}

int
main (void)
{
  unsigned int i;
  int fail = 0;

  /* Find a UID that has both a user name and login group name,
     but skip UID 0.  */
  {
    uid_t uid;
    for (uid = 1200; 0 < uid; uid--)
      {
        struct group *gr;
        struct passwd *pw = getpwuid (uid);
        unsigned int j;
        size_t len;
        if (!pw || !pw->pw_name || !(gr = getgrgid (pw->pw_gid)) || !gr->gr_name)
          continue;
        j = ARRAY_CARDINALITY (T) - 2;
        assert (T[j].in == NULL);
        assert (T[j+1].in == NULL);
        len = strlen (pw->pw_name);

        /* Store "username:" in T[j].in.  */
        {
          char *t = xmalloc (len + 1 + 1);
          memcpy (t, pw->pw_name, len);
          t[len] = ':';
          t[len+1] = '\0';
          T[j].in = t;
        }

        T[j].uid = uid;
        T[j].gid = gr->gr_gid;
        T[j].user_name = xstrdup (pw->pw_name);
        T[j].group_name = xstrdup (gr->gr_name);
        T[j].result = NULL;
        break;
      }
  }

  for (i = 0; T[i].in; i++)
    {
      uid_t uid = (uid_t) -1;
      gid_t gid = (gid_t) -1;
      char *user_name;
      char *group_name;
      char const *diag = parse_user_spec (T[i].in, &uid, &gid,
                                          &user_name, &group_name);
      free (user_name);
      free (group_name);
      if (!same_diag (diag, T[i].result))
        {
          printf ("%s return value mismatch: got %s, expected %s\n",
                  T[i].in, maybe_null (diag), maybe_null (T[i].result));
          fail = 1;
          continue;
        }

      if (diag)
        continue;

      if (uid != T[i].uid || gid != T[i].gid)
        {
          printf ("%s mismatch (-: expected uid,gid; +:actual)\n"
                  "-%3lu,%3lu\n+%3lu,%3lu\n",
                  T[i].in,
                  (unsigned long int) T[i].uid,
                  (unsigned long int) T[i].gid,
                  (unsigned long int) uid,
                  (unsigned long int) gid);
          fail = 1;
        }

      if (!diag && !T[i].result)
        continue;

      printf ("%s diagnostic mismatch (-: expected uid,gid; +:actual)\n"
              "-%s\n+%s\n", T[i].in, T[i].result, diag);
      fail = 1;
    }

  /* Ensure NULL parameters are ignored.  */
  {
    uid_t uid = (uid_t) -1;
    char const *diag = parse_user_spec ("", &uid, NULL, NULL, NULL);
    if (diag)
      {
        printf ("unexpected error: %s\n", diag);
        fail = 1;
      }
  }

  return fail;
}

/*
Local Variables:
indent-tabs-mode: nil
End:
*/
