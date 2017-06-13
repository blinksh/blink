/* Test of splitting a 'long double' into fraction and mantissa.
   Copyright (C) 2007-2017 Free Software Foundation, Inc.

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

/* Written by Bruno Haible <bruno@clisp.org>, 2007.  */

#include <config.h>

#include "printf-frexpl.h"

#include <float.h>

#include "fpucw.h"
#include "macros.h"

/* On MIPS IRIX machines, LDBL_MIN_EXP is -1021, but the smallest reliable
   exponent for 'long double' is -964.  Similarly, on PowerPC machines,
   LDBL_MIN_EXP is -1021, but the smallest reliable exponent for 'long double'
   is -968.  For exponents below that, the precision may be truncated to the
   precision used for 'double'.  */
#ifdef __sgi
# define MIN_NORMAL_EXP (LDBL_MIN_EXP + 57)
# define MIN_SUBNORMAL_EXP MIN_NORMAL_EXP
#elif defined __ppc || defined __ppc__ || defined __powerpc || defined __powerpc__
# define MIN_NORMAL_EXP (LDBL_MIN_EXP + 53)
# define MIN_SUBNORMAL_EXP MIN_NORMAL_EXP
#else
# define MIN_NORMAL_EXP LDBL_MIN_EXP
# define MIN_SUBNORMAL_EXP (LDBL_MIN_EXP - 100)
#endif

static long double
my_ldexp (long double x, int d)
{
  for (; d > 0; d--)
    x *= 2.0L;
  for (; d < 0; d++)
    x *= 0.5L;
  return x;
}

int
main ()
{
  int i;
  long double x;
  DECL_LONG_DOUBLE_ROUNDING

  BEGIN_LONG_DOUBLE_ROUNDING ();

  for (i = 1, x = 1.0L; i <= LDBL_MAX_EXP; i++, x *= 2.0L)
    {
      int exp = -9999;
      long double mantissa = printf_frexpl (x, &exp);
      ASSERT (exp == i - 1);
      ASSERT (mantissa == 1.0L);
    }
  for (i = 1, x = 1.0L; i >= MIN_NORMAL_EXP; i--, x *= 0.5L)
    {
      int exp = -9999;
      long double mantissa = printf_frexpl (x, &exp);
      ASSERT (exp == i - 1);
      ASSERT (mantissa == 1.0L);
    }
  for (; i >= MIN_SUBNORMAL_EXP && x > 0.0L; i--, x *= 0.5L)
    {
      int exp = -9999;
      long double mantissa = printf_frexpl (x, &exp);
      ASSERT (exp == LDBL_MIN_EXP - 1);
      ASSERT (mantissa == my_ldexp (1.0L, i - LDBL_MIN_EXP));
    }

  for (i = 1, x = 1.01L; i <= LDBL_MAX_EXP; i++, x *= 2.0L)
    {
      int exp = -9999;
      long double mantissa = printf_frexpl (x, &exp);
      ASSERT (exp == i - 1);
      ASSERT (mantissa == 1.01L);
    }
  for (i = 1, x = 1.01L; i >= MIN_NORMAL_EXP; i--, x *= 0.5L)
    {
      int exp = -9999;
      long double mantissa = printf_frexpl (x, &exp);
      ASSERT (exp == i - 1);
      ASSERT (mantissa == 1.01L);
    }
  for (; i >= MIN_SUBNORMAL_EXP && x > 0.0L; i--, x *= 0.5L)
    {
      int exp = -9999;
      long double mantissa = printf_frexpl (x, &exp);
      ASSERT (exp == LDBL_MIN_EXP - 1);
      ASSERT (mantissa >= my_ldexp (1.0L, i - LDBL_MIN_EXP));
      ASSERT (mantissa <= my_ldexp (2.0L, i - LDBL_MIN_EXP));
      ASSERT (mantissa == my_ldexp (x, - exp));
    }

  for (i = 1, x = 1.73205L; i <= LDBL_MAX_EXP; i++, x *= 2.0L)
    {
      int exp = -9999;
      long double mantissa = printf_frexpl (x, &exp);
      ASSERT (exp == i - 1);
      ASSERT (mantissa == 1.73205L);
    }
  for (i = 1, x = 1.73205L; i >= MIN_NORMAL_EXP; i--, x *= 0.5L)
    {
      int exp = -9999;
      long double mantissa = printf_frexpl (x, &exp);
      ASSERT (exp == i - 1);
      ASSERT (mantissa == 1.73205L);
    }
  for (; i >= MIN_SUBNORMAL_EXP && x > 0.0L; i--, x *= 0.5L)
    {
      int exp = -9999;
      long double mantissa = printf_frexpl (x, &exp);
      ASSERT (exp == LDBL_MIN_EXP - 1);
      ASSERT (mantissa >= my_ldexp (1.0L, i - LDBL_MIN_EXP));
      ASSERT (mantissa <= my_ldexp (2.0L, i - LDBL_MIN_EXP));
      ASSERT (mantissa == my_ldexp (x, - exp));
    }

  return 0;
}
