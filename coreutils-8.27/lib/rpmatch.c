/* Determine whether string value is affirmation or negative response
   according to current locale's data.

   Copyright (C) 1996, 1998, 2000, 2002-2003, 2006-2017 Free Software
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
#include <stdlib.h>

#include <stdbool.h>
#include <stddef.h>

#if ENABLE_NLS
# include <sys/types.h>
# include <limits.h>
# include <string.h>
# if HAVE_LANGINFO_YESEXPR
#  include <langinfo.h>
# endif
# include <regex.h>
# include "gettext.h"
# define _(msgid) gettext (msgid)
# define N_(msgid) gettext_noop (msgid)

# if HAVE_LANGINFO_YESEXPR
/* Return the localized regular expression pattern corresponding to
   ENGLISH_PATTERN.  NL_INDEX can be used with nl_langinfo.
   The resulting string may only be used until the next nl_langinfo call.  */
static const char *
localized_pattern (const char *english_pattern, nl_item nl_index,
                   bool posixly_correct)
{
  const char *translated_pattern;

  /* We prefer to get the patterns from a PO file.  It would be possible to
     always use nl_langinfo (YESEXPR) instead of _("^[yY]"), and
     nl_langinfo (NOEXPR) instead of _("^[nN]"), if we could assume that the
     system's locale support is good.  But this is not the case e.g. on Cygwin.
     The localizations of gnulib.pot are of better quality in general.
     Also, if we use locale info from non-free systems that don't have a
     'localedef' command, we deprive the users of the freedom to localize
     this pattern for their preferred language.
     But some programs, such as 'cp', 'mv', 'rm', 'find', 'xargs', are
     specified by POSIX to use nl_langinfo (YESEXPR).  We implement this
     behaviour if POSIXLY_CORRECT is set, for the sake of these programs.  */

  /* If the user wants strict POSIX compliance, use nl_langinfo.  */
  if (posixly_correct)
    {
      translated_pattern = nl_langinfo (nl_index);
      /* Check against a broken system return value.  */
      if (translated_pattern != NULL && translated_pattern[0] != '\0')
        return translated_pattern;
   }

  /* Look in the gnulib message catalog.  */
  translated_pattern = _(english_pattern);
  if (translated_pattern == english_pattern)
    {
      /* The gnulib message catalog provides no translation.
         Try the system's message catalog.  */
      translated_pattern = nl_langinfo (nl_index);
      /* Check against a broken system return value.  */
      if (translated_pattern != NULL && translated_pattern[0] != '\0')
        return translated_pattern;
      /* Fall back to English.  */
      translated_pattern = english_pattern;
    }
  return translated_pattern;
}
# else
#  define localized_pattern(english_pattern,nl_index,posixly_correct) \
     _(english_pattern)
# endif

static int
try (const char *response, const char *pattern, char **lastp, regex_t *re)
{
  if (*lastp == NULL || strcmp (pattern, *lastp) != 0)
    {
      char *safe_pattern;

      /* The pattern has changed.  */
      if (*lastp != NULL)
        {
          /* Free the old compiled pattern.  */
          regfree (re);
          free (*lastp);
          *lastp = NULL;
        }
      /* Put the PATTERN into safe memory before calling regcomp.
         (regcomp may call nl_langinfo, overwriting PATTERN's storage.  */
      safe_pattern = strdup (pattern);
      if (safe_pattern == NULL)
        return -1;
      /* Compile the pattern and cache it for future runs.  */
      if (regcomp (re, safe_pattern, REG_EXTENDED) != 0)
        {
          free (safe_pattern);
          return -1;
        }
      *lastp = safe_pattern;
    }

  /* See if the regular expression matches RESPONSE.  */
  return regexec (re, response, 0, NULL, 0) == 0;
}
#endif


int
rpmatch (const char *response)
{
#if ENABLE_NLS
  /* Match against one of the response patterns, compiling the pattern
     first if necessary.  */

  /* We cache the response patterns and compiled regexps here.  */
  static char *last_yesexpr, *last_noexpr;
  static regex_t cached_yesre, cached_nore;

# if HAVE_LANGINFO_YESEXPR
  bool posixly_correct = (getenv ("POSIXLY_CORRECT") != NULL);
# endif

  const char *yesexpr, *noexpr;
  int result;

  /* TRANSLATORS: A regular expression testing for an affirmative answer
     (english: "yes").  Testing the first character may be sufficient.
     Take care to consider upper and lower case.
     To enquire the regular expression that your system uses for this
     purpose, you can use the command
       locale -k LC_MESSAGES | grep '^yesexpr='  */
  yesexpr = localized_pattern (N_("^[yY]"), YESEXPR, posixly_correct);
  result = try (response, yesexpr, &last_yesexpr, &cached_yesre);
  if (result < 0)
    return -1;
  if (result)
    return 1;

  /* TRANSLATORS: A regular expression testing for a negative answer
     (english: "no").  Testing the first character may be sufficient.
     Take care to consider upper and lower case.
     To enquire the regular expression that your system uses for this
     purpose, you can use the command
       locale -k LC_MESSAGES | grep '^noexpr='  */
  noexpr = localized_pattern (N_("^[nN]"), NOEXPR, posixly_correct);
  result = try (response, noexpr, &last_noexpr, &cached_nore);
  if (result < 0)
    return -1;
  if (result)
    return 0;

  return -1;
#else
  /* Test against "^[yY]" and "^[nN]", hardcoded to avoid requiring regex */
  return (*response == 'y' || *response == 'Y' ? 1
          : *response == 'n' || *response == 'N' ? 0 : -1);
#endif
}
