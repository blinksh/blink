/* Test of splitting a double into fraction and mantissa.
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

#include "printf-frexp.h"

#include <float.h>

#include "macros.h"

static double
my_ldexp (double x, int d)
{
  for (; d > 0; d--)
    x *= 2.0;
  for (; d < 0; d++)
    x *= 0.5;
  return x;
}

int
main ()
{
  int i;
  /* The use of 'volatile' guarantees that excess precision bits are dropped
     when dealing with denormalized numbers.  It is necessary on x86 systems
     where double-floats are not IEEE compliant by default, to avoid that the
     results become platform and compiler option dependent.  'volatile' is a
     portable alternative to gcc's -ffloat-store option.  */
  volatile double x;

  for (i = 1, x = 1.0; i <= DBL_MAX_EXP; i++, x *= 2.0)
    {
      int exp = -9999;
      double mantissa = printf_frexp (x, &exp);
      ASSERT (exp == i - 1);
      ASSERT (mantissa == 1.0);
    }
  for (i = 1, x = 1.0; i >= DBL_MIN_EXP; i--, x *= 0.5)
    {
      int exp = -9999;
      double mantissa = printf_frexp (x, &exp);
      ASSERT (exp == i - 1);
      ASSERT (mantissa == 1.0);
    }
  for (; i >= DBL_MIN_EXP - 100 && x > 0.0; i--, x *= 0.5)
    {
      int exp = -9999;
      double mantissa = printf_frexp (x, &exp);
      ASSERT (exp == DBL_MIN_EXP - 1);
      ASSERT (mantissa == my_ldexp (1.0, i - DBL_MIN_EXP));
    }

  for (i = 1, x = 1.01; i <= DBL_MAX_EXP; i++, x *= 2.0)
    {
      int exp = -9999;
      double mantissa = printf_frexp (x, &exp);
      ASSERT (exp == i - 1);
      ASSERT (mantissa == 1.01);
    }
  for (i = 1, x = 1.01; i >= DBL_MIN_EXP; i--, x *= 0.5)
    {
      int exp = -9999;
      double mantissa = printf_frexp (x, &exp);
      ASSERT (exp == i - 1);
      ASSERT (mantissa == 1.01);
    }
  for (; i >= DBL_MIN_EXP - 100 && x > 0.0; i--, x *= 0.5)
    {
      int exp = -9999;
      double mantissa = printf_frexp (x, &exp);
      ASSERT (exp == DBL_MIN_EXP - 1);
      ASSERT (mantissa >= my_ldexp (1.0, i - DBL_MIN_EXP));
      ASSERT (mantissa <= my_ldexp (2.0, i - DBL_MIN_EXP));
      ASSERT (mantissa == my_ldexp (x, - exp));
    }

  for (i = 1, x = 1.73205; i <= DBL_MAX_EXP; i++, x *= 2.0)
    {
      int exp = -9999;
      double mantissa = printf_frexp (x, &exp);
      ASSERT (exp == i - 1);
      ASSERT (mantissa == 1.73205);
    }
  for (i = 1, x = 1.73205; i >= DBL_MIN_EXP; i--, x *= 0.5)
    {
      int exp = -9999;
      double mantissa = printf_frexp (x, &exp);
      ASSERT (exp == i - 1);
      ASSERT (mantissa == 1.73205);
    }
  for (; i >= DBL_MIN_EXP - 100 && x > 0.0; i--, x *= 0.5)
    {
      int exp = -9999;
      double mantissa = printf_frexp (x, &exp);
      ASSERT (exp == DBL_MIN_EXP - 1);
      ASSERT (mantissa >= my_ldexp (1.0, i - DBL_MIN_EXP));
      ASSERT (mantissa <= my_ldexp (2.0, i - DBL_MIN_EXP));
      ASSERT (mantissa == my_ldexp (x, - exp));
    }

  return 0;
}
