/* userspec.c -- Parse a user and group string.
   Copyright (C) 1989-1992, 1997-1998, 2000, 2002-2017 Free Software
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

/* Written by David MacKenzie <djm@gnu.ai.mit.edu>.  */

#include "config.h"

/* Specification.  */
#include "userspec.h"

#include <stdbool.h>
#include <stdio.h>
#include <sys/types.h>
#include <pwd.h>
#include <grp.h>

#if HAVE_SYS_PARAM_H
# include <sys/param.h>
#endif

#include <limits.h>
#include <stdlib.h>
#include <string.h>

#include <unistd.h>

#include "intprops.h"
#include "inttostr.h"
#include "xalloc.h"
#include "xstrtol.h"

#include "gettext.h"
#define _(msgid) gettext (msgid)
#define N_(msgid) msgid

#ifndef HAVE_ENDGRENT
# define endgrent() ((void) 0)
#endif

#ifndef HAVE_ENDPWENT
# define endpwent() ((void) 0)
#endif

#ifndef UID_T_MAX
# define UID_T_MAX TYPE_MAXIMUM (uid_t)
#endif

#ifndef GID_T_MAX
# define GID_T_MAX TYPE_MAXIMUM (gid_t)
#endif

/* MAXUID may come from limits.h or sys/params.h.  */
#ifndef MAXUID
# define MAXUID UID_T_MAX
#endif
#ifndef MAXGID
# define MAXGID GID_T_MAX
#endif

#ifdef __DJGPP__

/* ISDIGIT differs from isdigit, as follows:
   - Its arg may be any int or unsigned int; it need not be an unsigned char
     or EOF.
   - It's typically faster.
   POSIX says that only '0' through '9' are digits.  Prefer ISDIGIT to
   isdigit unless it's important to use the locale's definition
   of "digit" even when the host does not conform to POSIX.  */
# define ISDIGIT(c) ((unsigned int) (c) - '0' <= 9)

/* Return true if STR represents an unsigned decimal integer.  */

static bool
is_number (const char *str)
{
  do
    {
      if (!ISDIGIT (*str))
        return false;
    }
  while (*++str);

  return true;
}
#endif

static char const *
parse_with_separator (char const *spec, char const *separator,
                      uid_t *uid, gid_t *gid,
                      char **username, char **groupname)
{
  static const char *E_invalid_user = N_("invalid user");
  static const char *E_invalid_group = N_("invalid group");
  static const char *E_bad_spec = N_("invalid spec");

  const char *error_msg;
  struct passwd *pwd;
  struct group *grp;
  char *u;
  char const *g;
  char *gname = NULL;
  uid_t unum = *uid;
  gid_t gnum = gid ? *gid : -1;

  error_msg = NULL;
  if (username)
    *username = NULL;
  if (groupname)
    *groupname = NULL;

  /* Set U and G to nonzero length strings corresponding to user and
     group specifiers or to NULL.  If U is not NULL, it is a newly
     allocated string.  */

  u = NULL;
  if (separator == NULL)
    {
      if (*spec)
        u = xstrdup (spec);
    }
  else
    {
      size_t ulen = separator - spec;
      if (ulen != 0)
        {
          u = xmemdup (spec, ulen + 1);
          u[ulen] = '\0';
        }
    }

  g = (separator == NULL || *(separator + 1) == '\0'
       ? NULL
       : separator + 1);

#ifdef __DJGPP__
  /* Pretend that we are the user U whose group is G.  This makes
     pwd and grp functions "know" about the UID and GID of these.  */
  if (u && !is_number (u))
    setenv ("USER", u, 1);
  if (g && !is_number (g))
    setenv ("GROUP", g, 1);
#endif

  if (u != NULL)
    {
      /* If it starts with "+", skip the look-up.  */
      pwd = (*u == '+' ? NULL : getpwnam (u));
      if (pwd == NULL)
        {
          bool use_login_group = (separator != NULL && g == NULL);
          if (use_login_group)
            {
              /* If there is no group,
                 then there may not be a trailing ":", either.  */
              error_msg = E_bad_spec;
            }
          else
            {
              unsigned long int tmp;
              if (xstrtoul (u, NULL, 10, &tmp, "") == LONGINT_OK
                  && tmp <= MAXUID && (uid_t) tmp != (uid_t) -1)
                unum = tmp;
              else
                error_msg = E_invalid_user;
            }
        }
      else
        {
          unum = pwd->pw_uid;
          if (g == NULL && separator != NULL)
            {
              /* A separator was given, but a group was not specified,
                 so get the login group.  */
              char buf[INT_BUFSIZE_BOUND (uintmax_t)];
              gnum = pwd->pw_gid;
              grp = getgrgid (gnum);
              gname = xstrdup (grp ? grp->gr_name : umaxtostr (gnum, buf));
              endgrent ();
            }
        }
      endpwent ();
    }

  if (g != NULL && error_msg == NULL)
    {
      /* Explicit group.  */
      /* If it starts with "+", skip the look-up.  */
      grp = (*g == '+' ? NULL : getgrnam (g));
      if (grp == NULL)
        {
          unsigned long int tmp;
          if (xstrtoul (g, NULL, 10, &tmp, "") == LONGINT_OK
              && tmp <= MAXGID && (gid_t) tmp != (gid_t) -1)
            gnum = tmp;
          else
            error_msg = E_invalid_group;
        }
      else
        gnum = grp->gr_gid;
      endgrent ();              /* Save a file descriptor.  */
      gname = xstrdup (g);
    }

  if (error_msg == NULL)
    {
      *uid = unum;
      if (gid)
        *gid = gnum;
      if (username)
        {
          *username = u;
          u = NULL;
        }
      if (groupname)
        {
          *groupname = gname;
          gname = NULL;
        }
    }

  free (u);
  free (gname);
  return error_msg ? _(error_msg) : NULL;
}

/* Extract from SPEC, which has the form "[user][:.][group]",
   a USERNAME, UID U, GROUPNAME, and GID G.
   If the GID parameter is NULL the entire SPEC is treated as a user.
   If the USERNAME and GROUPNAME parameters are NULL they're ignored.
   Either user or group, or both, must be present.
   If the group is omitted but the separator is given,
   use the given user's login group.
   If SPEC contains a ':', then use that as the separator, ignoring
   any '.'s.  If there is no ':', but there is a '.', then first look
   up the entire SPEC as a login name.  If that look-up fails, then
   try again interpreting the '.'  as a separator.

   USERNAME and GROUPNAME will be in newly malloc'd memory.
   Either one might be NULL instead, indicating that it was not
   given and the corresponding numeric ID was left unchanged.

   Return NULL if successful, a static error message string if not.  */

char const *
parse_user_spec (char const *spec, uid_t *uid, gid_t *gid,
                 char **username, char **groupname)
{
  char const *colon = gid ? strchr (spec, ':') : NULL;
  char const *error_msg =
    parse_with_separator (spec, colon, uid, gid, username, groupname);

  if (gid && !colon && error_msg)
    {
      /* If there's no colon but there is a dot, and if looking up the
         whole spec failed (i.e., the spec is not an owner name that
         includes a dot), then try again, but interpret the dot as a
         separator.  This is a compatible extension to POSIX, since
         the POSIX-required behavior is always tried first.  */

      char const *dot = strchr (spec, '.');
      if (dot
          && ! parse_with_separator (spec, dot, uid, gid, username, groupname))
        error_msg = NULL;
    }

  return error_msg;
}

#ifdef TEST

# define NULL_CHECK(s) ((s) == NULL ? "(null)" : (s))

int
main (int argc, char **argv)
{
  int i;

  for (i = 1; i < argc; i++)
    {
      const char *e;
      char *username, *groupname;
      uid_t uid;
      gid_t gid;
      char *tmp;

      tmp = strdup (argv[i]);
      e = parse_user_spec (tmp, &uid, &gid, &username, &groupname);
      free (tmp);
      printf ("%s: %lu %lu %s %s %s\n",
              argv[i],
              (unsigned long int) uid,
              (unsigned long int) gid,
              NULL_CHECK (username),
              NULL_CHECK (groupname),
              NULL_CHECK (e));
    }

  exit (0);
}

#endif

/*
Local Variables:
indent-tabs-mode: nil
End:
*/
