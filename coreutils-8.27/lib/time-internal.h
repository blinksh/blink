/* Time internal interface

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

/* A time zone rule.  */
struct tm_zone
{
  /* More abbreviations, should they be needed.  Their TZ_IS_SET
     members are zero.  */
  struct tm_zone *next;

#if HAVE_TZNAME && !HAVE_TM_ZONE
  /* Copies of recent strings taken from tzname[0] and tzname[1].
     The copies are in ABBRS, so that they survive tzset.  Null if unknown.  */
  char *tzname_copy[2];
#endif

  /* If nonzero, the rule represents the TZ environment variable set
     to the first "abbreviation" (this may be the empty string).
     Otherwise, it represents an unset TZ.  */
  char tz_is_set;

  /* A sequence of null-terminated strings packed next to each other.
     The strings are followed by an extra null byte.  If TZ_IS_SET,
     there must be at least one string and the first string (which is
     actually a TZ environment value) may be empty.  Otherwise all
     strings must be nonempty.

     Abbreviations are stored here because otherwise the values of
     tm_zone and/or tzname would be dead after changing TZ and calling
     tzset.  Abbreviations never move once allocated, and are live
     until tzfree is called.  */
  char abbrs[FLEXIBLE_ARRAY_MEMBER];
};
