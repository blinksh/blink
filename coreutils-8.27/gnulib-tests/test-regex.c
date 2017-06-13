/* Test regular expressions
   Copyright 1996-2001, 2003-2017 Free Software Foundation, Inc.

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

#include <config.h>

#include "regex.h"

#include <locale.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#if HAVE_DECL_ALARM
# include <unistd.h>
# include <signal.h>
#endif

#include "localcharset.h"

int
main (void)
{
  int result = 0;
  static struct re_pattern_buffer regex;
  unsigned char folded_chars[UCHAR_MAX + 1];
  int i;
  const char *s;
  struct re_registers regs;

#if HAVE_DECL_ALARM
  /* Some builds of glibc go into an infinite loop on this test.  */
  int alarm_value = 2;
  signal (SIGALRM, SIG_DFL);
  alarm (alarm_value);
#endif
  if (setlocale (LC_ALL, "en_US.UTF-8"))
    {
      {
        /* http://sourceware.org/ml/libc-hacker/2006-09/msg00008.html
           This test needs valgrind to catch the bug on Debian
           GNU/Linux 3.1 x86, but it might catch the bug better
           on other platforms and it shouldn't hurt to try the
           test here.  */
        static char const pat[] = "insert into";
        static char const data[] =
          "\xFF\0\x12\xA2\xAA\xC4\xB1,K\x12\xC4\xB1*\xACK";
        re_set_syntax (RE_SYNTAX_GREP | RE_HAT_LISTS_NOT_NEWLINE
                       | RE_ICASE);
        memset (&regex, 0, sizeof regex);
        s = re_compile_pattern (pat, sizeof pat - 1, &regex);
        if (s)
          result |= 1;
        else
          {
            memset (&regs, 0, sizeof regs);
            if (re_search (&regex, data, sizeof data - 1,
                           0, sizeof data - 1, &regs)
                != -1)
              result |= 1;
            regfree (&regex);
            free (regs.start);
            free (regs.end);
          }
      }

      /* Check whether it's really a UTF-8 locale.
         On mingw, the setlocale call succeeds but returns
         "English_United States.1252", with locale_charset() returning
         "CP1252".  */
      if (strcmp (locale_charset (), "UTF-8") == 0)
        {
          /* This test is from glibc bug 15078.
             The test case is from Andreas Schwab in
             <http://www.sourceware.org/ml/libc-alpha/2013-01/msg00967.html>.
          */
          static char const pat[] = "[^x]x";
          static char const data[] =
            /* <U1000><U103B><U103D><U1014><U103A><U102F><U1015><U103A> */
            "\xe1\x80\x80"
            "\xe1\x80\xbb"
            "\xe1\x80\xbd"
            "\xe1\x80\x94"
            "\xe1\x80\xba"
            "\xe1\x80\xaf"
            "\xe1\x80\x95"
            "\xe1\x80\xba"
            "x";
          re_set_syntax (0);
          memset (&regex, 0, sizeof regex);
          s = re_compile_pattern (pat, sizeof pat - 1, &regex);
          if (s)
            result |= 1;
          else
            {
              memset (&regs, 0, sizeof regs);
              i = re_search (&regex, data, sizeof data - 1,
                             0, sizeof data - 1, 0);
              if (i != 0 && i != 21)
                result |= 1;
              regfree (&regex);
              free (regs.start);
              free (regs.end);
            }
        }

      if (! setlocale (LC_ALL, "C"))
        return 1;
    }

  /* This test is from glibc bug 3957, reported by Andrew Mackey.  */
  re_set_syntax (RE_SYNTAX_EGREP | RE_HAT_LISTS_NOT_NEWLINE);
  memset (&regex, 0, sizeof regex);
  s = re_compile_pattern ("a[^x]b", 6, &regex);
  if (s)
    result |= 2;
  /* This should fail, but succeeds for glibc-2.5.  */
  else
    {
      memset (&regs, 0, sizeof regs);
      if (re_search (&regex, "a\nb", 3, 0, 3, &regs) != -1)
        result |= 2;
      regfree (&regex);
      free (regs.start);
      free (regs.end);
    }

  /* This regular expression is from Spencer ere test number 75
     in grep-2.3.  */
  re_set_syntax (RE_SYNTAX_POSIX_EGREP);
  memset (&regex, 0, sizeof regex);
  for (i = 0; i <= UCHAR_MAX; i++)
    folded_chars[i] = i;
  regex.translate = folded_chars;
  s = re_compile_pattern ("a[[:@:>@:]]b\n", 11, &regex);
  /* This should fail with _Invalid character class name_ error.  */
  if (!s)
    {
      result |= 4;
      regfree (&regex);
    }

  /* Ensure that [b-a] is diagnosed as invalid, when
     using RE_NO_EMPTY_RANGES. */
  re_set_syntax (RE_SYNTAX_POSIX_EGREP | RE_NO_EMPTY_RANGES);
  memset (&regex, 0, sizeof regex);
  s = re_compile_pattern ("a[b-a]", 6, &regex);
  if (s == 0)
    {
      result |= 8;
      regfree (&regex);
    }

  /* This should succeed, but does not for glibc-2.1.3.  */
  memset (&regex, 0, sizeof regex);
  s = re_compile_pattern ("{1", 2, &regex);
  if (s)
    result |= 8;
  else
    regfree (&regex);

  /* The following example is derived from a problem report
     against gawk from Jorge Stolfi <stolfi@ic.unicamp.br>.  */
  memset (&regex, 0, sizeof regex);
  s = re_compile_pattern ("[an\371]*n", 7, &regex);
  if (s)
    result |= 8;
  /* This should match, but does not for glibc-2.2.1.  */
  else
    {
      memset (&regs, 0, sizeof regs);
      if (re_match (&regex, "an", 2, 0, &regs) != 2)
        result |= 8;
      regfree (&regex);
      free (regs.start);
      free (regs.end);
    }

  memset (&regex, 0, sizeof regex);
  s = re_compile_pattern ("x", 1, &regex);
  if (s)
    result |= 8;
  /* glibc-2.2.93 does not work with a negative RANGE argument.  */
  else
    {
      memset (&regs, 0, sizeof regs);
      if (re_search (&regex, "wxy", 3, 2, -2, &regs) != 1)
        result |= 8;
      regfree (&regex);
      free (regs.start);
      free (regs.end);
    }

  /* The version of regex.c in older versions of gnulib
     ignored RE_ICASE.  Detect that problem too.  */
  re_set_syntax (RE_SYNTAX_EMACS | RE_ICASE);
  memset (&regex, 0, sizeof regex);
  s = re_compile_pattern ("x", 1, &regex);
  if (s)
    result |= 16;
  else
    {
      memset (&regs, 0, sizeof regs);
      if (re_search (&regex, "WXY", 3, 0, 3, &regs) < 0)
        result |= 16;
      regfree (&regex);
      free (regs.start);
      free (regs.end);
    }

  /* Catch a bug reported by Vin Shelton in
     http://lists.gnu.org/archive/html/bug-coreutils/2007-06/msg00089.html
     */
  re_set_syntax (RE_SYNTAX_POSIX_BASIC
                 & ~RE_CONTEXT_INVALID_DUP
                 & ~RE_NO_EMPTY_RANGES);
  memset (&regex, 0, sizeof regex);
  s = re_compile_pattern ("[[:alnum:]_-]\\\\+$", 16, &regex);
  if (s)
    result |= 32;
  else
    regfree (&regex);

  /* REG_STARTEND was added to glibc on 2004-01-15.
     Reject older versions.  */
  if (! REG_STARTEND)
    result |= 64;

#if 0
  /* It would be nice to reject hosts whose regoff_t values are too
     narrow (including glibc on hosts with 64-bit ptrdiff_t and
     32-bit int), but we should wait until glibc implements this
     feature.  Otherwise, support for equivalence classes and
     multibyte collation symbols would always be broken except
     when compiling --without-included-regex.   */
  if (sizeof (regoff_t) < sizeof (ptrdiff_t)
      || sizeof (regoff_t) < sizeof (ssize_t))
    result |= 64;
#endif

  return result;
}
