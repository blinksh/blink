/* Test the "verify" module.

   Copyright (C) 2005, 2009-2017 Free Software Foundation, Inc.

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

/* Written by Bruno Haible.  */

#include <config.h>

#include "verify.h"

#ifndef EXP_FAIL
# define EXP_FAIL 0
#endif

int x;
enum { a, b, c };

#if EXP_FAIL == 1
verify (x >= 0);                  /* should give ERROR: non-constant expression */
#endif
verify (c == 2);                  /* should be ok */
#if EXP_FAIL == 2
verify (1 + 1 == 3);              /* should give ERROR */
#endif
verify (1 == 1); verify (1 == 1); /* should be ok */

enum
{
  item = verify_true (1 == 1) * 0 + 17 /* should be ok */
};

static int
function (int n)
{
#if EXP_FAIL == 3
  verify (n >= 0);                  /* should give ERROR: non-constant expression */
#endif
  verify (c == 2);                  /* should be ok */
#if EXP_FAIL == 4
  verify (1 + 1 == 3);              /* should give ERROR */
#endif
  verify (1 == 1); verify (1 == 1); /* should be ok */

  if (n)
    return ((void) verify_expr (1 == 1, 1), verify_expr (1 == 1, 8)); /* should be ok */
#if EXP_FAIL == 5
  return verify_expr (1 == 2, 5); /* should give ERROR */
#endif
  return 0;
}

int
main (void)
{
  return !(function (0) == 0 && function (1) == 8);
}
