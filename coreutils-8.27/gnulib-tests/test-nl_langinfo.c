/* Test of nl_langinfo replacement.
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

/* Written by Bruno Haible <bruno@clisp.org>, 2009.  */

#include <config.h>

#include <langinfo.h>

#include "signature.h"
SIGNATURE_CHECK (nl_langinfo, char *, (nl_item));

#include <locale.h>
#include <stdlib.h>
#include <string.h>

#include "c-strcase.h"
#include "macros.h"

/* For GCC >= 4.3, silence the warnings
     "comparison of unsigned expression >= 0 is always true"
   in this file.  */
#if __GNUC__ > 4 || (__GNUC__ == 4 && __GNUC_MINOR__ >= 3)
# pragma GCC diagnostic ignored "-Wtype-limits"
#endif

int
main (int argc, char *argv[])
{
  int pass = atoi (argv[1]);
  /* pass    locale
      0        C
      1        traditional French locale
      2        French UTF-8 locale
   */

  setlocale (LC_ALL, "");

  /* nl_langinfo items of the LC_CTYPE category */
  ASSERT (strlen (nl_langinfo (CODESET)) > 0);
  if (pass == 2)
    {
      const char *codeset = nl_langinfo (CODESET);
      ASSERT (c_strcasecmp (codeset, "UTF-8") == 0 || c_strcasecmp (codeset, "UTF8") == 0);
    }
  /* nl_langinfo items of the LC_NUMERIC category */
  ASSERT (strlen (nl_langinfo (RADIXCHAR)) > 0);
  ASSERT (strlen (nl_langinfo (THOUSEP)) >= 0);
  /* nl_langinfo items of the LC_TIME category */
  ASSERT (strlen (nl_langinfo (D_T_FMT)) > 0);
  ASSERT (strlen (nl_langinfo (D_FMT)) > 0);
  ASSERT (strlen (nl_langinfo (T_FMT)) > 0);
  ASSERT (strlen (nl_langinfo (T_FMT_AMPM)) >= (pass == 0 ? 1 : 0));
  ASSERT (strlen (nl_langinfo (AM_STR)) >= (pass == 0 ? 1 : 0));
  ASSERT (strlen (nl_langinfo (PM_STR)) >= (pass == 0 ? 1 : 0));
  ASSERT (strlen (nl_langinfo (DAY_1)) > 0);
  ASSERT (strlen (nl_langinfo (DAY_2)) > 0);
  ASSERT (strlen (nl_langinfo (DAY_3)) > 0);
  ASSERT (strlen (nl_langinfo (DAY_4)) > 0);
  ASSERT (strlen (nl_langinfo (DAY_5)) > 0);
  ASSERT (strlen (nl_langinfo (DAY_6)) > 0);
  ASSERT (strlen (nl_langinfo (DAY_7)) > 0);
  ASSERT (strlen (nl_langinfo (ABDAY_1)) > 0);
  ASSERT (strlen (nl_langinfo (ABDAY_2)) > 0);
  ASSERT (strlen (nl_langinfo (ABDAY_3)) > 0);
  ASSERT (strlen (nl_langinfo (ABDAY_4)) > 0);
  ASSERT (strlen (nl_langinfo (ABDAY_5)) > 0);
  ASSERT (strlen (nl_langinfo (ABDAY_6)) > 0);
  ASSERT (strlen (nl_langinfo (ABDAY_7)) > 0);
  ASSERT (strlen (nl_langinfo (MON_1)) > 0);
  ASSERT (strlen (nl_langinfo (MON_2)) > 0);
  ASSERT (strlen (nl_langinfo (MON_3)) > 0);
  ASSERT (strlen (nl_langinfo (MON_4)) > 0);
  ASSERT (strlen (nl_langinfo (MON_5)) > 0);
  ASSERT (strlen (nl_langinfo (MON_6)) > 0);
  ASSERT (strlen (nl_langinfo (MON_7)) > 0);
  ASSERT (strlen (nl_langinfo (MON_8)) > 0);
  ASSERT (strlen (nl_langinfo (MON_9)) > 0);
  ASSERT (strlen (nl_langinfo (MON_10)) > 0);
  ASSERT (strlen (nl_langinfo (MON_11)) > 0);
  ASSERT (strlen (nl_langinfo (MON_12)) > 0);
  ASSERT (strlen (nl_langinfo (ABMON_1)) > 0);
  ASSERT (strlen (nl_langinfo (ABMON_2)) > 0);
  ASSERT (strlen (nl_langinfo (ABMON_3)) > 0);
  ASSERT (strlen (nl_langinfo (ABMON_4)) > 0);
  ASSERT (strlen (nl_langinfo (ABMON_5)) > 0);
  ASSERT (strlen (nl_langinfo (ABMON_6)) > 0);
  ASSERT (strlen (nl_langinfo (ABMON_7)) > 0);
  ASSERT (strlen (nl_langinfo (ABMON_8)) > 0);
  ASSERT (strlen (nl_langinfo (ABMON_9)) > 0);
  ASSERT (strlen (nl_langinfo (ABMON_10)) > 0);
  ASSERT (strlen (nl_langinfo (ABMON_11)) > 0);
  ASSERT (strlen (nl_langinfo (ABMON_12)) > 0);
  ASSERT (strlen (nl_langinfo (ERA)) >= 0);
  ASSERT (strlen (nl_langinfo (ERA_D_FMT)) >= 0);
  ASSERT (strlen (nl_langinfo (ERA_D_T_FMT)) >= 0);
  ASSERT (strlen (nl_langinfo (ERA_T_FMT)) >= 0);
  ASSERT (nl_langinfo (ALT_DIGITS) != NULL);
  /* nl_langinfo items of the LC_MONETARY category */
  {
    const char *currency = nl_langinfo (CRNCYSTR);
    ASSERT (strlen (currency) >= 0);
#if !defined __NetBSD__
    if (pass > 0)
      ASSERT (strlen (currency) >= 1);
#endif
  }
  /* nl_langinfo items of the LC_MESSAGES category */
  ASSERT (strlen (nl_langinfo (YESEXPR)) > 0);
  ASSERT (strlen (nl_langinfo (NOEXPR)) > 0);

  return 0;
}
