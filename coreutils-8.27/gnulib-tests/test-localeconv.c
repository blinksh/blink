/* Test of localeconv() function.
   Copyright (C) 2012-2017 Free Software Foundation, Inc.

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

/* Written by Bruno Haible <bruno@clisp.org>, 2012.  */

#include <config.h>

#include <locale.h>

#include "signature.h"
SIGNATURE_CHECK (localeconv, struct lconv *, (void));

#include <limits.h>
#include <string.h>

#include "macros.h"

int
main ()
{
  /* Test localeconv() result in the "C" locale.  */
  {
    struct lconv *l = localeconv ();

    ASSERT (STREQ (l->decimal_point, "."));
    ASSERT (STREQ (l->thousands_sep, ""));
#if !(defined __FreeBSD__ || defined __sun)
    ASSERT (STREQ (l->grouping, ""));
#endif

    ASSERT (STREQ (l->mon_decimal_point, ""));
    ASSERT (STREQ (l->mon_thousands_sep, ""));
#if !(defined __FreeBSD__ || defined __sun)
    ASSERT (STREQ (l->mon_grouping, ""));
#endif
    ASSERT (STREQ (l->positive_sign, ""));
    ASSERT (STREQ (l->negative_sign, ""));

    ASSERT (STREQ (l->currency_symbol, ""));
    ASSERT (l->frac_digits == CHAR_MAX);
    ASSERT (l->p_cs_precedes == CHAR_MAX);
    ASSERT (l->p_sign_posn == CHAR_MAX);
    ASSERT (l->p_sep_by_space == CHAR_MAX);
    ASSERT (l->n_cs_precedes == CHAR_MAX);
    ASSERT (l->n_sign_posn == CHAR_MAX);
    ASSERT (l->n_sep_by_space == CHAR_MAX);

    ASSERT (STREQ (l->int_curr_symbol, ""));
    ASSERT (l->int_frac_digits == CHAR_MAX);
    ASSERT (l->int_p_cs_precedes == CHAR_MAX);
    ASSERT (l->int_p_sign_posn == CHAR_MAX);
    ASSERT (l->int_p_sep_by_space == CHAR_MAX);
    ASSERT (l->int_n_cs_precedes == CHAR_MAX);
    ASSERT (l->int_n_sign_posn == CHAR_MAX);
    ASSERT (l->int_n_sep_by_space == CHAR_MAX);
  }

  return 0;
}
