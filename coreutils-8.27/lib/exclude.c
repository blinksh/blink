/* exclude.c -- exclude file names

   Copyright (C) 1992-1994, 1997, 1999-2007, 2009-2017 Free Software
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

/* Written by Paul Eggert <eggert@twinsun.com>
   and Sergey Poznyakoff <gray@gnu.org>.
   Thanks to Phil Proudman <phil@proudman51.freeserve.co.uk>
   for improvement suggestions. */

#include "config.h"

#include <stdbool.h>

#include <ctype.h>
#include <errno.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wctype.h>
#include <regex.h>

#include "exclude.h"
#include "hash.h"
#include "mbuiter.h"
#include "fnmatch.h"
#include "xalloc.h"
#include "verify.h"
#include "filename.h"

#if USE_UNLOCKED_IO
# include "unlocked-io.h"
#endif

/* Non-GNU systems lack these options, so we don't need to check them.  */
#ifndef FNM_CASEFOLD
# define FNM_CASEFOLD 0
#endif
#ifndef FNM_EXTMATCH
# define FNM_EXTMATCH 0
#endif
#ifndef FNM_LEADING_DIR
# define FNM_LEADING_DIR 0
#endif

verify (((EXCLUDE_ANCHORED | EXCLUDE_INCLUDE | EXCLUDE_WILDCARDS)
         & (FNM_PATHNAME | FNM_NOESCAPE | FNM_PERIOD | FNM_LEADING_DIR
            | FNM_CASEFOLD | FNM_EXTMATCH))
        == 0);


/* Exclusion patterns are grouped into a singly-linked list of
   "exclusion segments".  Each segment represents a set of patterns
   that can be matches using the same algorithm.  Non-wildcard
   patterns are kept in hash tables, to speed up searches.  Wildcard
   patterns are stored as arrays of patterns. */


/* An exclude pattern-options pair.  The options are fnmatch options
   ORed with EXCLUDE_* options.  */

struct patopts
  {
    int options;
    union
    {
      char const *pattern;
      regex_t re;
    } v;
  };

/* An array of pattern-options pairs.  */

struct exclude_pattern
  {
    struct patopts *exclude;
    size_t exclude_alloc;
    size_t exclude_count;
  };

enum exclude_type
  {
    exclude_hash,                    /* a hash table of excluded names */
    exclude_pattern                  /* an array of exclude patterns */
  };

struct exclude_segment
  {
    struct exclude_segment *next;    /* next segment in list */
    enum exclude_type type;          /* type of this segment */
    int options;                     /* common options for this segment */
    union
    {
      Hash_table *table;             /* for type == exclude_hash */
      struct exclude_pattern pat;    /* for type == exclude_pattern */
    } v;
  };

struct pattern_buffer
  {
    struct pattern_buffer *next;
    char *base;
  };

/* The exclude structure keeps a singly-linked list of exclude segments,
   maintained in reverse order.  */
struct exclude
  {
    struct exclude_segment *head;
    struct pattern_buffer *patbuf;
  };

/* Register BUF in the pattern buffer list of EX.  ADD_FUNC (see
   add_exclude_file and add_exclude_fp below) can use this function
   if it modifies the pattern, to ensure the allocated memory will be
   properly reclaimed upon calling free_exclude. */
void
exclude_add_pattern_buffer (struct exclude *ex, char *buf)
{
  struct pattern_buffer *pbuf = xmalloc (sizeof *pbuf);
  pbuf->base = buf;
  pbuf->next = ex->patbuf;
  ex->patbuf = pbuf;
}

/* Return true if STR has or may have wildcards, when matched with OPTIONS.
   Return false if STR definitely does not have wildcards.  */
bool
fnmatch_pattern_has_wildcards (const char *str, int options)
{
  while (1)
    {
      switch (*str++)
        {
	case '.':
	case '{':
	case '}':
	case '(':
	case ')':
	  if (options & EXCLUDE_REGEX)
	    return true;
	  break;

        case '\\':
	  if (options & EXCLUDE_REGEX)
	    continue;
	  else
	    str += ! (options & FNM_NOESCAPE) && *str;
          break;

        case '+': case '@': case '!':
          if (options & FNM_EXTMATCH && *str == '(')
            return true;
          break;

        case '?': case '*': case '[':
          return true;

        case '\0':
          return false;
        }
    }
}

static void
unescape_pattern (char *str)
{
  char const *q = str;
  do
    q += *q == '\\' && q[1];
  while ((*str++ = *q++));
}

/* Return a newly allocated and empty exclude list.  */

struct exclude *
new_exclude (void)
{
  return xzalloc (sizeof *new_exclude ());
}

/* Calculate the hash of string.  */
static size_t
string_hasher (void const *data, size_t n_buckets)
{
  char const *p = data;
  return hash_string (p, n_buckets);
}

/* Ditto, for case-insensitive hashes */
static size_t
string_hasher_ci (void const *data, size_t n_buckets)
{
  char const *p = data;
  mbui_iterator_t iter;
  size_t value = 0;

  for (mbui_init (iter, p); mbui_avail (iter); mbui_advance (iter))
    {
      mbchar_t m = mbui_cur (iter);
      wchar_t wc;

      if (m.wc_valid)
        wc = towlower (m.wc);
      else
        wc = *m.ptr;

      value = (value * 31 + wc) % n_buckets;
    }

  return value;
}

/* compare two strings for equality */
static bool
string_compare (void const *data1, void const *data2)
{
  char const *p1 = data1;
  char const *p2 = data2;
  return strcmp (p1, p2) == 0;
}

/* compare two strings for equality, case-insensitive */
static bool
string_compare_ci (void const *data1, void const *data2)
{
  char const *p1 = data1;
  char const *p2 = data2;
  return mbscasecmp (p1, p2) == 0;
}

static void
string_free (void *data)
{
  free (data);
}

/* Create new exclude segment of given TYPE and OPTIONS, and attach it
   to the head of EX.  */
static void
new_exclude_segment (struct exclude *ex, enum exclude_type type, int options)
{
  struct exclude_segment *sp = xzalloc (sizeof (struct exclude_segment));
  sp->type = type;
  sp->options = options;
  switch (type)
    {
    case exclude_pattern:
      break;

    case exclude_hash:
      sp->v.table = hash_initialize (0, NULL,
                                     (options & FNM_CASEFOLD) ?
                                       string_hasher_ci
                                       : string_hasher,
                                     (options & FNM_CASEFOLD) ?
                                       string_compare_ci
                                       : string_compare,
                                     string_free);
      break;
    }
  sp->next = ex->head;
  ex->head = sp;
}

/* Free a single exclude segment */
static void
free_exclude_segment (struct exclude_segment *seg)
{
  size_t i;

  switch (seg->type)
    {
    case exclude_pattern:
      for (i = 0; i < seg->v.pat.exclude_count; i++)
	{
	  if (seg->v.pat.exclude[i].options & EXCLUDE_REGEX)
	    regfree (&seg->v.pat.exclude[i].v.re);
	}
      free (seg->v.pat.exclude);
      break;

    case exclude_hash:
      hash_free (seg->v.table);
      break;
    }
  free (seg);
}

/* Free the storage associated with an exclude list.  */
void
free_exclude (struct exclude *ex)
{
  struct exclude_segment *seg;
  struct pattern_buffer *pbuf;

  for (seg = ex->head; seg; )
    {
      struct exclude_segment *next = seg->next;
      free_exclude_segment (seg);
      seg = next;
    }

  for (pbuf = ex->patbuf; pbuf; )
    {
      struct pattern_buffer *next = pbuf->next;
      free (pbuf->base);
      free (pbuf);
      pbuf = next;
    }

  free (ex);
}

/* Return zero if PATTERN matches F, obeying OPTIONS, except that
   (unlike fnmatch) wildcards are disabled in PATTERN.  */

static int
fnmatch_no_wildcards (char const *pattern, char const *f, int options)
{
  if (! (options & FNM_LEADING_DIR))
    return ((options & FNM_CASEFOLD)
            ? mbscasecmp (pattern, f)
            : strcmp (pattern, f));
  else if (! (options & FNM_CASEFOLD))
    {
      size_t patlen = strlen (pattern);
      int r = strncmp (pattern, f, patlen);
      if (! r)
        {
          r = f[patlen];
          if (r == '/')
            r = 0;
        }
      return r;
    }
  else
    {
      /* Walk through a copy of F, seeing whether P matches any prefix
         of F.

         FIXME: This is an O(N**2) algorithm; it should be O(N).
         Also, the copy should not be necessary.  However, fixing this
         will probably involve a change to the mbs* API.  */

      char *fcopy = xstrdup (f);
      char *p;
      int r;
      for (p = fcopy; ; *p++ = '/')
        {
          p = strchr (p, '/');
          if (p)
            *p = '\0';
          r = mbscasecmp (pattern, fcopy);
          if (!p || r <= 0)
            break;
        }
      free (fcopy);
      return r;
    }
}

bool
exclude_fnmatch (char const *pattern, char const *f, int options)
{
  int (*matcher) (char const *, char const *, int) =
    (options & EXCLUDE_WILDCARDS
     ? fnmatch
     : fnmatch_no_wildcards);
  bool matched = ((*matcher) (pattern, f, options) == 0);
  char const *p;

  if (! (options & EXCLUDE_ANCHORED))
    for (p = f; *p && ! matched; p++)
      if (*p == '/' && p[1] != '/')
	matched = ((*matcher) (pattern, p + 1, options) == 0);

  return matched;
}

static bool
exclude_patopts (struct patopts const *opts, char const *f)
{
  int options = opts->options;

  return (options & EXCLUDE_REGEX)
          ? regexec (&opts->v.re, f, 0, NULL, 0) == 0
          : exclude_fnmatch (opts->v.pattern, f, options);
}

/* Return true if the exclude_pattern segment SEG matches F.  */

static bool
file_pattern_matches (struct exclude_segment const *seg, char const *f)
{
  size_t exclude_count = seg->v.pat.exclude_count;
  struct patopts const *exclude = seg->v.pat.exclude;
  size_t i;

  for (i = 0; i < exclude_count; i++)
    {
      if (exclude_patopts (exclude + i, f))
        return true;
    }
  return false;
}

/* Return true if the exclude_hash segment SEG matches F.
   BUFFER is an auxiliary storage of the same length as F (with nul
   terminator included) */
static bool
file_name_matches (struct exclude_segment const *seg, char const *f,
                   char *buffer)
{
  int options = seg->options;
  Hash_table *table = seg->v.table;

  do
    {
      /* initialize the pattern */
      strcpy (buffer, f);

      while (1)
        {
          if (hash_lookup (table, buffer))
            return true;
          if (options & FNM_LEADING_DIR)
            {
              char *p = strrchr (buffer, '/');
              if (p)
                {
                  *p = 0;
                  continue;
                }
            }
          break;
        }

      if (!(options & EXCLUDE_ANCHORED))
        {
          f = strchr (f, '/');
          if (f)
            f++;
        }
      else
        break;
    }
  while (f);

  return false;
}

/* Return true if EX excludes F.  */

bool
excluded_file_name (struct exclude const *ex, char const *f)
{
  struct exclude_segment *seg;
  bool invert = false;
  char *filename = NULL;

  /* If no patterns are given, the default is to include.  */
  if (!ex->head)
    return false;

  /* Scan through the segments, reporting the status of the first match.
     The segments are in reverse order, so this reports the status of
     the last match in the original option list.  */
  for (seg = ex->head; ; seg = seg->next)
    {
      if (seg->type == exclude_hash)
        {
          if (!filename)
            filename = xmalloc (strlen (f) + 1);
          if (file_name_matches (seg, f, filename))
            break;
        }
      else
        {
          if (file_pattern_matches (seg, f))
            break;
        }

      if (! seg->next)
        {
          /* If patterns are given but none match, the default is the
             opposite of the last segment (i.e., the first in the
             original option list).  For example, in the command
             'grep -r --exclude="a*" --include="*b" pat dir', the
             first option is --exclude so any file name matching
             neither a* nor *b is included.  */
          invert = true;
          break;
        }
    }

  free (filename);
  return invert ^ ! (seg->options & EXCLUDE_INCLUDE);
}

/* Append to EX the exclusion PATTERN with OPTIONS.  */

void
add_exclude (struct exclude *ex, char const *pattern, int options)
{
  struct exclude_segment *seg;
  struct exclude_pattern *pat;
  struct patopts *patopts;

  if ((options & (EXCLUDE_REGEX|EXCLUDE_WILDCARDS))
      && fnmatch_pattern_has_wildcards (pattern, options))
    {
      if (! (ex->head && ex->head->type == exclude_pattern
	     && ((ex->head->options & EXCLUDE_INCLUDE)
		 == (options & EXCLUDE_INCLUDE))))
	new_exclude_segment (ex, exclude_pattern, options);

      seg = ex->head;

      pat = &seg->v.pat;
      if (pat->exclude_count == pat->exclude_alloc)
        pat->exclude = x2nrealloc (pat->exclude, &pat->exclude_alloc,
                                   sizeof *pat->exclude);
      patopts = &pat->exclude[pat->exclude_count++];

      patopts->options = options;
      if (options & EXCLUDE_REGEX)
	{
	  int rc;
	  int cflags = REG_NOSUB|REG_EXTENDED|
	               ((options & FNM_CASEFOLD) ? REG_ICASE : 0);

	  if (options & FNM_LEADING_DIR)
	    {
	      char *tmp;
	      size_t len = strlen (pattern);

	      while (len > 0 && ISSLASH (pattern[len-1]))
		--len;

	      if (len == 0)
		rc = 1;
	      else
		{
		  tmp = xmalloc (len + 7);
		  memcpy (tmp, pattern, len);
		  strcpy (tmp + len, "(/.*)?");
		  rc = regcomp (&patopts->v.re, tmp, cflags);
		  free (tmp);
		}
	    }
	  else
	    rc = regcomp (&patopts->v.re, pattern, cflags);

	  if (rc)
	    {
	      pat->exclude_count--;
	      return;
	    }
	}
      else
	{
	  if (options & EXCLUDE_ALLOC)
	    {
	      pattern = xstrdup (pattern);
	      exclude_add_pattern_buffer (ex, (char*) pattern);
	    }
	  patopts->v.pattern = pattern;
	}
    }
  else
    {
      char *str, *p;
      int exclude_hash_flags = (EXCLUDE_INCLUDE | EXCLUDE_ANCHORED
                                | FNM_LEADING_DIR | FNM_CASEFOLD);
      if (! (ex->head && ex->head->type == exclude_hash
             && ((ex->head->options & exclude_hash_flags)
                 == (options & exclude_hash_flags))))
        new_exclude_segment (ex, exclude_hash, options);
      seg = ex->head;

      str = xstrdup (pattern);
      if ((options & (EXCLUDE_WILDCARDS | FNM_NOESCAPE)) == EXCLUDE_WILDCARDS)
        unescape_pattern (str);
      p = hash_insert (seg->v.table, str);
      if (p != str)
        free (str);
    }
}

/* Use ADD_FUNC to append to EX the patterns in FILE_NAME, each with
   OPTIONS.  LINE_END terminates each pattern in the file.  If
   LINE_END is a space character, ignore trailing spaces and empty
   lines in FP.  Return -1 on failure, 0 on success.  */

int
add_exclude_fp (void (*add_func) (struct exclude *, char const *, int, void *),
		struct exclude *ex, FILE *fp, int options,
		char line_end,
		void *data)
{
  char *buf = NULL;
  char *p;
  char *pattern;
  char const *lim;
  size_t buf_alloc = 0;
  size_t buf_count = 0;
  int c;
  int e = 0;

  while ((c = getc (fp)) != EOF)
    {
      if (buf_count == buf_alloc)
        buf = x2realloc (buf, &buf_alloc);
      buf[buf_count++] = c;
    }

  if (ferror (fp))
    e = errno;

  buf = xrealloc (buf, buf_count + 1);
  buf[buf_count] = line_end;
  lim = buf + buf_count + ! (buf_count == 0 || buf[buf_count - 1] == line_end);

  exclude_add_pattern_buffer (ex, buf);

  pattern = buf;

  for (p = buf; p < lim; p++)
    if (*p == line_end)
      {
        char *pattern_end = p;

        if (isspace ((unsigned char) line_end))
          {
            for (; ; pattern_end--)
              if (pattern_end == pattern)
                goto next_pattern;
              else if (! isspace ((unsigned char) pattern_end[-1]))
                break;
          }

        *pattern_end = '\0';
        (*add_func) (ex, pattern, options, data);

      next_pattern:
        pattern = p + 1;
      }

  errno = e;
  return e ? -1 : 0;
}

static void
call_addfn (struct exclude *ex, char const *pattern, int options, void *data)
{
  void (**addfnptr) (struct exclude *, char const *, int) = data;
  (*addfnptr) (ex, pattern, options);
}

int
add_exclude_file (void (*add_func) (struct exclude *, char const *, int),
		  struct exclude *ex, char const *file_name, int options,
		  char line_end)
{
  bool use_stdin = file_name[0] == '-' && !file_name[1];
  FILE *in;
  int rc = 0;

  if (use_stdin)
    in = stdin;
  else if (! (in = fopen (file_name, "r")))
    return -1;

  rc = add_exclude_fp (call_addfn, ex, in, options, line_end, &add_func);

  if (!use_stdin && fclose (in) != 0)
    rc = -1;

  return rc;
}
