/* idcache.c -- map user and group IDs, cached for speed

   Copyright (C) 1985, 1988-1990, 1997-1998, 2003, 2005-2007, 2009-2017 Free
   Software Foundation, Inc.

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

#include "idcache.h"
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <pwd.h>
#include <grp.h>

#include <unistd.h>

#include "flexmember.h"
#include "xalloc.h"

#ifdef __DJGPP__
static char digits[] = "0123456789";
#endif

struct userid
{
  union
    {
      uid_t u;
      gid_t g;
    } id;
  struct userid *next;
  char name[FLEXIBLE_ARRAY_MEMBER];
};

/* FIXME: provide a function to free any malloc'd storage and reset lists,
   so that an application can use code like this just before exiting:
   #if defined GCC_LINT || defined lint
     idcache_clear ();
   #endif
*/

static struct userid *user_alist;

/* Each entry on list is a user name for which the first lookup failed.  */
static struct userid *nouser_alist;

/* Use the same struct as for userids.  */
static struct userid *group_alist;

/* Each entry on list is a group name for which the first lookup failed.  */
static struct userid *nogroup_alist;

/* Translate UID to a login name, with cache, or NULL if unresolved.  */

char *
getuser (uid_t uid)
{
  struct userid *tail;
  struct userid *match = NULL;

  for (tail = user_alist; tail; tail = tail->next)
    {
      if (tail->id.u == uid)
        {
          match = tail;
          break;
        }
    }

  if (match == NULL)
    {
      struct passwd *pwent = getpwuid (uid);
      char const *name = pwent ? pwent->pw_name : "";
      match = xmalloc (FLEXSIZEOF (struct userid, name, strlen (name) + 1));
      match->id.u = uid;
      strcpy (match->name, name);

      /* Add to the head of the list, so most recently used is first.  */
      match->next = user_alist;
      user_alist = match;
    }

  return match->name[0] ? match->name : NULL;
}

/* Translate USER to a UID, with cache.
   Return NULL if there is no such user.
   (We also cache which user names have no passwd entry,
   so we don't keep looking them up.)  */

uid_t *
getuidbyname (const char *user)
{
  struct userid *tail;
  struct passwd *pwent;

  for (tail = user_alist; tail; tail = tail->next)
    /* Avoid a function call for the most common case.  */
    if (*tail->name == *user && !strcmp (tail->name, user))
      return &tail->id.u;

  for (tail = nouser_alist; tail; tail = tail->next)
    /* Avoid a function call for the most common case.  */
    if (*tail->name == *user && !strcmp (tail->name, user))
      return NULL;

  pwent = getpwnam (user);
#ifdef __DJGPP__
  /* We need to pretend to be the user USER, to make
     pwd functions know about an arbitrary user name.  */
  if (!pwent && strspn (user, digits) < strlen (user))
    {
      setenv ("USER", user, 1);
      pwent = getpwnam (user);  /* now it will succeed */
    }
#endif

  tail = xmalloc (FLEXSIZEOF (struct userid, name, strlen (user) + 1));
  strcpy (tail->name, user);

  /* Add to the head of the list, so most recently used is first.  */
  if (pwent)
    {
      tail->id.u = pwent->pw_uid;
      tail->next = user_alist;
      user_alist = tail;
      return &tail->id.u;
    }

  tail->next = nouser_alist;
  nouser_alist = tail;
  return NULL;
}

/* Translate GID to a group name, with cache, or NULL if unresolved.  */

char *
getgroup (gid_t gid)
{
  struct userid *tail;
  struct userid *match = NULL;

  for (tail = group_alist; tail; tail = tail->next)
    {
      if (tail->id.g == gid)
        {
          match = tail;
          break;
        }
    }

  if (match == NULL)
    {
      struct group *grent = getgrgid (gid);
      char const *name = grent ? grent->gr_name : "";
      match = xmalloc (FLEXSIZEOF (struct userid, name, strlen (name) + 1));
      match->id.g = gid;
      strcpy (match->name, name);

      /* Add to the head of the list, so most recently used is first.  */
      match->next = group_alist;
      group_alist = match;
    }

  return match->name[0] ? match->name : NULL;
}

/* Translate GROUP to a GID, with cache.
   Return NULL if there is no such group.
   (We also cache which group names have no group entry,
   so we don't keep looking them up.)  */

gid_t *
getgidbyname (const char *group)
{
  struct userid *tail;
  struct group *grent;

  for (tail = group_alist; tail; tail = tail->next)
    /* Avoid a function call for the most common case.  */
    if (*tail->name == *group && !strcmp (tail->name, group))
      return &tail->id.g;

  for (tail = nogroup_alist; tail; tail = tail->next)
    /* Avoid a function call for the most common case.  */
    if (*tail->name == *group && !strcmp (tail->name, group))
      return NULL;

  grent = getgrnam (group);
#ifdef __DJGPP__
  /* We need to pretend to belong to group GROUP, to make
     grp functions know about an arbitrary group name.  */
  if (!grent && strspn (group, digits) < strlen (group))
    {
      setenv ("GROUP", group, 1);
      grent = getgrnam (group); /* now it will succeed */
    }
#endif

  tail = xmalloc (FLEXSIZEOF (struct userid, name, strlen (group) + 1));
  strcpy (tail->name, group);

  /* Add to the head of the list, so most recently used is first.  */
  if (grent)
    {
      tail->id.g = grent->gr_gid;
      tail->next = group_alist;
      group_alist = tail;
      return &tail->id.g;
    }

  tail->next = nogroup_alist;
  nogroup_alist = tail;
  return NULL;
}
