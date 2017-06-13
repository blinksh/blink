/*
   Copyright (C) 1995 Ian Jackson <iwj10@cus.cam.ac.uk>
   Copyright (C) 2001 Anthony Towns <aj@azure.humbug.org.au>
   Copyright (C) 2008-2017 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>. */

#include "config.h"
#include "filevercmp.h"

#include <sys/types.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <c-ctype.h>
#include <limits.h>

/* Match a file suffix defined by this regular expression:
   /(\.[A-Za-z~][A-Za-z0-9~]*)*$/
   Scan the string *STR and return a pointer to the matching suffix, or
   NULL if not found.  Upon return, *STR points to terminating NUL.  */
static const char *
match_suffix (const char **str)
{
  const char *match = NULL;
  bool read_alpha = false;
  while (**str)
    {
      if (read_alpha)
        {
          read_alpha = false;
          if (!c_isalpha (**str) && '~' != **str)
            match = NULL;
        }
      else if ('.' == **str)
        {
          read_alpha = true;
          if (!match)
            match = *str;
        }
      else if (!c_isalnum (**str) && '~' != **str)
        match = NULL;
      (*str)++;
    }
  return match;
}

/* verrevcmp helper function */
static int
order (unsigned char c)
{
  if (c_isdigit (c))
    return 0;
  else if (c_isalpha (c))
    return c;
  else if (c == '~')
    return -1;
  else
    return (int) c + UCHAR_MAX + 1;
}

/* slightly modified verrevcmp function from dpkg
   S1, S2 - compared string
   S1_LEN, S2_LEN - length of strings to be scanned

   This implements the algorithm for comparison of version strings
   specified by Debian and now widely adopted.  The detailed
   specification can be found in the Debian Policy Manual in the
   section on the 'Version' control field.  This version of the code
   implements that from s5.6.12 of Debian Policy v3.8.0.1
   http://www.debian.org/doc/debian-policy/ch-controlfields.html#s-f-Version */
static int _GL_ATTRIBUTE_PURE
verrevcmp (const char *s1, size_t s1_len, const char *s2, size_t s2_len)
{
  size_t s1_pos = 0;
  size_t s2_pos = 0;
  while (s1_pos < s1_len || s2_pos < s2_len)
    {
      int first_diff = 0;
      while ((s1_pos < s1_len && !c_isdigit (s1[s1_pos]))
             || (s2_pos < s2_len && !c_isdigit (s2[s2_pos])))
        {
          int s1_c = (s1_pos == s1_len) ? 0 : order (s1[s1_pos]);
          int s2_c = (s2_pos == s2_len) ? 0 : order (s2[s2_pos]);
          if (s1_c != s2_c)
            return s1_c - s2_c;
          s1_pos++;
          s2_pos++;
        }
      while (s1[s1_pos] == '0')
        s1_pos++;
      while (s2[s2_pos] == '0')
        s2_pos++;
      while (c_isdigit (s1[s1_pos]) && c_isdigit (s2[s2_pos]))
        {
          if (!first_diff)
            first_diff = s1[s1_pos] - s2[s2_pos];
          s1_pos++;
          s2_pos++;
        }
      if (c_isdigit (s1[s1_pos]))
        return 1;
      if (c_isdigit (s2[s2_pos]))
        return -1;
      if (first_diff)
        return first_diff;
    }
  return 0;
}

/* Compare version strings S1 and S2.
   See filevercmp.h for function description.  */
int
filevercmp (const char *s1, const char *s2)
{
  const char *s1_pos;
  const char *s2_pos;
  const char *s1_suffix, *s2_suffix;
  size_t s1_len, s2_len;
  int result;

  /* easy comparison to see if strings are identical */
  int simple_cmp = strcmp (s1, s2);
  if (simple_cmp == 0)
    return 0;

  /* special handle for "", "." and ".." */
  if (!*s1)
    return -1;
  if (!*s2)
    return 1;
  if (0 == strcmp (".", s1))
    return -1;
  if (0 == strcmp (".", s2))
    return 1;
  if (0 == strcmp ("..", s1))
    return -1;
  if (0 == strcmp ("..", s2))
    return 1;

  /* special handle for other hidden files */
  if (*s1 == '.' && *s2 != '.')
    return -1;
  if (*s1 != '.' && *s2 == '.')
    return 1;
  if (*s1 == '.' && *s2 == '.')
    {
      s1++;
      s2++;
    }

  /* "cut" file suffixes */
  s1_pos = s1;
  s2_pos = s2;
  s1_suffix = match_suffix (&s1_pos);
  s2_suffix = match_suffix (&s2_pos);
  s1_len = (s1_suffix ? s1_suffix : s1_pos) - s1;
  s2_len = (s2_suffix ? s2_suffix : s2_pos) - s2;

  /* restore file suffixes if strings are identical after "cut" */
  if ((s1_suffix || s2_suffix) && (s1_len == s2_len)
      && 0 == strncmp (s1, s2, s1_len))
    {
      s1_len = s1_pos - s1;
      s2_len = s2_pos - s2;
    }

  result = verrevcmp (s1, s1_len, s2, s2_len);
  return result == 0 ? simple_cmp : result;
}
