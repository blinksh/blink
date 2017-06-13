/* Test of splitting a double into fraction and mantissa.
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

static DOUBLE
my_ldexp (DOUBLE x, int d)
{
  for (; d > 0; d--)
    x *= L_(2.0);
  for (; d < 0; d++)
    x *= L_(0.5);
  return x;
}

static void
test_function (void)
{
  int i;
  VOLATILE DOUBLE x;

  { /* NaN.  */
    int exp = -9999;
    DOUBLE mantissa;
    x = NAN;
    mantissa = FREXP (x, &exp);
    ASSERT (ISNAN (mantissa));
  }

  { /* Positive infinity.  */
    int exp = -9999;
    DOUBLE mantissa;
    x = INFINITY;
    mantissa = FREXP (x, &exp);
    ASSERT (mantissa == x);
  }

  { /* Negative infinity.  */
    int exp = -9999;
    DOUBLE mantissa;
    x = - INFINITY;
    mantissa = FREXP (x, &exp);
    ASSERT (mantissa == x);
  }

  { /* Positive zero.  */
    int exp = -9999;
    DOUBLE mantissa;
    x = L_(0.0);
    mantissa = FREXP (x, &exp);
    ASSERT (exp == 0);
    ASSERT (mantissa == x);
    ASSERT (!signbit (mantissa));
  }

  { /* Negative zero.  */
    int exp = -9999;
    DOUBLE mantissa;
    x = MINUS_ZERO;
    mantissa = FREXP (x, &exp);
    ASSERT (exp == 0);
    ASSERT (mantissa == x);
    ASSERT (signbit (mantissa));
  }

  for (i = 1, x = L_(1.0); i <= MAX_EXP; i++, x *= L_(2.0))
    {
      int exp = -9999;
      DOUBLE mantissa = FREXP (x, &exp);
      ASSERT (exp == i);
      ASSERT (mantissa == L_(0.5));
    }
  for (i = 1, x = L_(1.0); i >= MIN_NORMAL_EXP; i--, x *= L_(0.5))
    {
      int exp = -9999;
      DOUBLE mantissa = FREXP (x, &exp);
      ASSERT (exp == i);
      ASSERT (mantissa == L_(0.5));
    }
  for (; i >= MIN_EXP - 100 && x > L_(0.0); i--, x *= L_(0.5))
    {
      int exp = -9999;
      DOUBLE mantissa = FREXP (x, &exp);
      ASSERT (exp == i);
      ASSERT (mantissa == L_(0.5));
    }

  for (i = 1, x = - L_(1.0); i <= MAX_EXP; i++, x *= L_(2.0))
    {
      int exp = -9999;
      DOUBLE mantissa = FREXP (x, &exp);
      ASSERT (exp == i);
      ASSERT (mantissa == - L_(0.5));
    }
  for (i = 1, x = - L_(1.0); i >= MIN_NORMAL_EXP; i--, x *= L_(0.5))
    {
      int exp = -9999;
      DOUBLE mantissa = FREXP (x, &exp);
      ASSERT (exp == i);
      ASSERT (mantissa == - L_(0.5));
    }
  for (; i >= MIN_EXP - 100 && x < L_(0.0); i--, x *= L_(0.5))
    {
      int exp = -9999;
      DOUBLE mantissa = FREXP (x, &exp);
      ASSERT (exp == i);
      ASSERT (mantissa == - L_(0.5));
    }

  for (i = 1, x = L_(1.01); i <= MAX_EXP; i++, x *= L_(2.0))
    {
      int exp = -9999;
      DOUBLE mantissa = FREXP (x, &exp);
      ASSERT (exp == i);
      ASSERT (mantissa == L_(0.505));
    }
  for (i = 1, x = L_(1.01); i >= MIN_NORMAL_EXP; i--, x *= L_(0.5))
    {
      int exp = -9999;
      DOUBLE mantissa = FREXP (x, &exp);
      ASSERT (exp == i);
      ASSERT (mantissa == L_(0.505));
    }
  for (; i >= MIN_EXP - 100 && x > L_(0.0); i--, x *= L_(0.5))
    {
      int exp = -9999;
      DOUBLE mantissa = FREXP (x, &exp);
      ASSERT (exp == i);
      ASSERT (mantissa >= L_(0.5));
      ASSERT (mantissa < L_(1.0));
      ASSERT (mantissa == my_ldexp (x, - exp));
    }

  for (i = 1, x = L_(1.73205); i <= MAX_EXP; i++, x *= L_(2.0))
    {
      int exp = -9999;
      DOUBLE mantissa = FREXP (x, &exp);
      ASSERT (exp == i);
      ASSERT (mantissa == L_(0.866025));
    }
  for (i = 1, x = L_(1.73205); i >= MIN_NORMAL_EXP; i--, x *= L_(0.5))
    {
      int exp = -9999;
      DOUBLE mantissa = FREXP (x, &exp);
      ASSERT (exp == i);
      ASSERT (mantissa == L_(0.866025));
    }
  for (; i >= MIN_EXP - 100 && x > L_(0.0); i--, x *= L_(0.5))
    {
      int exp = -9999;
      DOUBLE mantissa = FREXP (x, &exp);
      ASSERT (exp == i || exp == i + 1);
      ASSERT (mantissa >= L_(0.5));
      ASSERT (mantissa < L_(1.0));
      ASSERT (mantissa == my_ldexp (x, - exp));
    }

  /* Randomized tests.  */
  for (i = 0; i < SIZEOF (RANDOM); i++)
    {
      x = L_(20.0) * RANDOM[i] - L_(10.0); /* -10.0 <= x <= 10.0 */
      {
        int exp = -9999;
        DOUBLE mantissa = FREXP (x, &exp);
        ASSERT (x == my_ldexp (mantissa, exp));
      }
    }
}
