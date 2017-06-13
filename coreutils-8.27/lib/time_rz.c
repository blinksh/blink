/* Time zone functions such as tzalloc and localtime_rz

   Copyright 2015-2017 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License along
   with this program; if not, see <http://www.gnu.org/licenses/>.  */

/* Written by Paul Eggert.  */

/* Although this module is not thread-safe, any races should be fairly
   rare and reasonably benign.  For complete thread-safety, use a C
   library with a working timezone_t type, so that this module is not
   needed.  */

#include "config.h"

#include "time.h"

#include <errno.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include "flexmember.h"
#include "time-internal.h"

#if !HAVE_TZSET
static void tzset (void) { }
#endif

/* The approximate size to use for small allocation requests.  This is
   the largest "small" request for the GNU C library malloc.  */
enum { DEFAULT_MXFAST = 64 * sizeof (size_t) / 4 };

/* Minimum size of the ABBRS member of struct abbr.  ABBRS is larger
   only in the unlikely case where an abbreviation longer than this is
   used.  */
enum { ABBR_SIZE_MIN = DEFAULT_MXFAST - offsetof (struct tm_zone, abbrs) };

/* Magic cookie timezone_t value, for local time.  It differs from
   NULL and from all other timezone_t values.  Only the address
   matters; the pointer is never dereferenced.  */
static timezone_t const local_tz = (timezone_t) 1;

#if HAVE_TM_ZONE || HAVE_TZNAME

/* Return true if the values A and B differ according to the rules for
   tm_isdst: A and B differ if one is zero and the other positive.  */
static bool
isdst_differ (int a, int b)
{
  return !a != !b && 0 <= a && 0 <= b;
}

/* Return true if A and B are equal.  */
static int
equal_tm (const struct tm *a, const struct tm *b)
{
  return ! ((a->tm_sec ^ b->tm_sec)
            | (a->tm_min ^ b->tm_min)
            | (a->tm_hour ^ b->tm_hour)
            | (a->tm_mday ^ b->tm_mday)
            | (a->tm_mon ^ b->tm_mon)
            | (a->tm_year ^ b->tm_year)
            | isdst_differ (a->tm_isdst, b->tm_isdst));
}

#endif

/* Copy to ABBRS the abbreviation at ABBR with size ABBR_SIZE (this
   includes its trailing null byte).  Append an extra null byte to
   mark the end of ABBRS.  */
static void
extend_abbrs (char *abbrs, char const *abbr, size_t abbr_size)
{
  memcpy (abbrs, abbr, abbr_size);
  abbrs[abbr_size] = '\0';
}

/* Return a newly allocated time zone for NAME, or NULL on failure.
   A null NAME stands for wall clock time (which is like unset TZ).  */
timezone_t
tzalloc (char const *name)
{
  size_t name_size = name ? strlen (name) + 1 : 0;
  size_t abbr_size = name_size < ABBR_SIZE_MIN ? ABBR_SIZE_MIN : name_size + 1;
  timezone_t tz = malloc (FLEXSIZEOF (struct tm_zone, abbrs, abbr_size));
  if (tz)
    {
      tz->next = NULL;
#if HAVE_TZNAME && !HAVE_TM_ZONE
      tz->tzname_copy[0] = tz->tzname_copy[1] = NULL;
#endif
      tz->tz_is_set = !!name;
      tz->abbrs[0] = '\0';
      if (name)
        extend_abbrs (tz->abbrs, name, name_size);
    }
  return tz;
}

/* Save into TZ any nontrivial time zone abbreviation used by TM, and
   update *TM (if HAVE_TM_ZONE) or *TZ (if !HAVE_TM_ZONE &&
   HAVE_TZNAME) if they use the abbreviation.  Return true if
   successful, false (setting errno) otherwise.  */
static bool
save_abbr (timezone_t tz, struct tm *tm)
{
#if HAVE_TM_ZONE || HAVE_TZNAME
  char const *zone = NULL;
  char *zone_copy = (char *) "";

# if HAVE_TZNAME
  int tzname_index = -1;
# endif

# if HAVE_TM_ZONE
  zone = tm->tm_zone;
# endif

# if HAVE_TZNAME
  if (! (zone && *zone) && 0 <= tm->tm_isdst)
    {
      tzname_index = tm->tm_isdst != 0;
      zone = tzname[tzname_index];
    }
# endif

  /* No need to replace null zones, or zones within the struct tm.  */
  if (!zone || ((char *) tm <= zone && zone < (char *) (tm + 1)))
    return true;

  if (*zone)
    {
      zone_copy = tz->abbrs;

      while (strcmp (zone_copy, zone) != 0)
        {
          if (! (*zone_copy || (zone_copy == tz->abbrs && tz->tz_is_set)))
            {
              size_t zone_size = strlen (zone) + 1;
              if (zone_size < tz->abbrs + ABBR_SIZE_MIN - zone_copy)
                extend_abbrs (zone_copy, zone, zone_size);
              else
                {
                  tz = tz->next = tzalloc (zone);
                  if (!tz)
                    return false;
                  tz->tz_is_set = 0;
                  zone_copy = tz->abbrs;
                }
              break;
            }

          zone_copy += strlen (zone_copy) + 1;
          if (!*zone_copy && tz->next)
            {
              tz = tz->next;
              zone_copy = tz->abbrs;
            }
        }
    }

  /* Replace the zone name so that its lifetime matches that of TZ.  */
# if HAVE_TM_ZONE
  tm->tm_zone = zone_copy;
# else
  if (0 <= tzname_index)
    tz->tzname_copy[tzname_index] = zone_copy;
# endif
#endif

  return true;
}

/* Free a time zone.  */
void
tzfree (timezone_t tz)
{
  if (tz != local_tz)
    while (tz)
      {
        timezone_t next = tz->next;
        free (tz);
        tz = next;
      }
}

/* Get and set the TZ environment variable.  These functions can be
   overridden by programs like Emacs that manage their own environment.  */

#ifndef getenv_TZ
static char *
getenv_TZ (void)
{
  return getenv ("TZ");
}
#endif

#ifndef setenv_TZ
static int
setenv_TZ (char const *tz)
{
  return tz ? setenv ("TZ", tz, 1) : unsetenv ("TZ");
}
#endif

/* Change the environment to match the specified timezone_t value.
   Return true if successful, false (setting errno) otherwise.  */
static bool
change_env (timezone_t tz)
{
  if (setenv_TZ (tz->tz_is_set ? tz->abbrs : NULL) != 0)
    return false;
  tzset ();
  return true;
}

/* Temporarily set the time zone to TZ, which must not be null.
   Return LOCAL_TZ if the time zone setting is already correct.
   Otherwise return a newly allocated time zone representing the old
   setting, or NULL (setting errno) on failure.  */
static timezone_t
set_tz (timezone_t tz)
{
  char *env_tz = getenv_TZ ();
  if (env_tz
      ? tz->tz_is_set && strcmp (tz->abbrs, env_tz) == 0
      : !tz->tz_is_set)
    return local_tz;
  else
    {
      timezone_t old_tz = tzalloc (env_tz);
      if (!old_tz)
        return old_tz;
      if (! change_env (tz))
        {
          int saved_errno = errno;
          tzfree (old_tz);
          errno = saved_errno;
          return NULL;
        }
      return old_tz;
    }
}

/* Restore an old setting returned by set_tz.  It must not be null.
   Return true (preserving errno) if successful, false (setting errno)
   otherwise.  */
static bool
revert_tz (timezone_t tz)
{
  if (tz == local_tz)
    return true;
  else
    {
      int saved_errno = errno;
      bool ok = change_env (tz);
      if (!ok)
        saved_errno = errno;
      tzfree (tz);
      errno = saved_errno;
      return ok;
    }
}

/* Use time zone TZ to compute localtime_r (T, TM).  */
struct tm *
localtime_rz (timezone_t tz, time_t const *t, struct tm *tm)
{
  if (!tz)
    return gmtime_r (t, tm);
  else
    {
      timezone_t old_tz = set_tz (tz);
      if (old_tz)
        {
          bool abbr_saved = localtime_r (t, tm) && save_abbr (tz, tm);
          if (revert_tz (old_tz) && abbr_saved)
            return tm;
        }
      return NULL;
    }
}

/* Use time zone TZ to compute mktime (TM).  */
time_t
mktime_z (timezone_t tz, struct tm *tm)
{
  if (!tz)
    return timegm (tm);
  else
    {
      timezone_t old_tz = set_tz (tz);
      if (old_tz)
        {
          time_t t = mktime (tm);
#if HAVE_TM_ZONE || HAVE_TZNAME
          time_t badtime = -1;
          struct tm tm_1;
          if ((t != badtime
               || (localtime_r (&t, &tm_1) && equal_tm (tm, &tm_1)))
              && !save_abbr (tz, tm))
            t = badtime;
#endif
          if (revert_tz (old_tz))
            return t;
        }
      return -1;
    }
}
