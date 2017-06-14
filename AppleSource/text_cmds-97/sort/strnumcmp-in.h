/* Compare numeric strings.  This is an internal include file.

   Copyright (C) 1988, 1991, 1992, 1993, 1995, 1996, 1998, 1999, 2000,
   2003, 2004, 2005 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software Foundation,
   Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.  */

/* Written by Mike Haertel.  */

#ifndef STRNUMCMP_IN_H
# define STRNUMCMP_IN_H 1

# include "strnumcmp.h"

# include <stddef.h>

# define NEGATION_SIGN   '-'
# define NUMERIC_ZERO    '0'

/* ISDIGIT differs from isdigit, as follows:
   - Its arg may be any int or unsigned int; it need not be an unsigned char.
   - It's guaranteed to evaluate its argument exactly once.
   - It's typically faster.
   POSIX says that only '0' through '9' are digits.  Prefer ISDIGIT to
   ISDIGIT_LOCALE unless it's important to use the locale's definition
   of `digit' even when the host does not conform to POSIX.  */
# define ISDIGIT(c) ((unsigned int) (c) - '0' <= 9)


/* Compare strings A and B containing decimal fractions < 1.
   DECIMAL_POINT is the decimal point.  Each string
   should begin with a decimal point followed immediately by the digits
   of the fraction.  Strings not of this form are treated as zero.  */

/* The goal here, is to take two numbers a and b... compare these
   in parallel.  Instead of converting each, and then comparing the
   outcome.  Most likely stopping the comparison before the conversion
   is complete.  The algorithm used, in the old "sort" utility:

   Algorithm: fraccompare
   Action   : compare two decimal fractions
   accepts  : char *a, char *b
   returns  : -1 if a<b, 0 if a=b, 1 if a>b.
   implement:

   if *a == decimal_point AND *b == decimal_point
     find first character different in a and b.
     if both are digits, return the difference *a - *b.
     if *a is a digit
       skip past zeros
       if digit return 1, else 0
     if *b is a digit
       skip past zeros
       if digit return -1, else 0
   if *a is a decimal_point
     skip past decimal_point and zeros
     if digit return 1, else 0
   if *b is a decimal_point
     skip past decimal_point and zeros
     if digit return -1, else 0
   return 0 */

static inline int
fraccompare (char const *a, char const *b, char decimal_point)
{
  if (*a == decimal_point && *b == decimal_point)
    {
      while (*++a == *++b)
	if (! ISDIGIT (*a))
	  return 0;
      if (ISDIGIT (*a) && ISDIGIT (*b))
	return *a - *b;
      if (ISDIGIT (*a))
	goto a_trailing_nonzero;
      if (ISDIGIT (*b))
	goto b_trailing_nonzero;
      return 0;
    }
  else if (*a++ == decimal_point)
    {
    a_trailing_nonzero:
      while (*a == NUMERIC_ZERO)
	a++;
      return ISDIGIT (*a);
    }
  else if (*b++ == decimal_point)
    {
    b_trailing_nonzero:
      while (*b == NUMERIC_ZERO)
	b++;
      return - ISDIGIT (*b);
    }
  return 0;
}

/* Compare strings A and B as numbers without explicitly converting
   them to machine numbers, to avoid overflow problems and perhaps
   improve performance.  DECIMAL_POINT is the decimal point and
   THOUSANDS_SEP the thousands separator.  A DECIMAL_POINT of -1
   causes comparisons to act as if there is no decimal point
   character, and likewise for THOUSANDS_SEP.  */

static inline int
numcompare (char const *a, char const *b,
	    int decimal_point, int thousands_sep)
{
  unsigned char tmpa = *a;
  unsigned char tmpb = *b;
  int tmp;
  size_t log_a;
  size_t log_b;

  if (tmpa == NEGATION_SIGN)
    {
      do
	tmpa = *++a;
      while (tmpa == NUMERIC_ZERO || tmpa == thousands_sep);
      if (tmpb != NEGATION_SIGN)
	{
	  if (tmpa == decimal_point)
	    do
	      tmpa = *++a;
	    while (tmpa == NUMERIC_ZERO);
	  if (ISDIGIT (tmpa))
	    return -1;
	  while (tmpb == NUMERIC_ZERO || tmpb == thousands_sep)
	    tmpb = *++b;
	  if (tmpb == decimal_point)
	    do
	      tmpb = *++b;
	    while (tmpb == NUMERIC_ZERO);
	  return - ISDIGIT (tmpb);
	}
      do
	tmpb = *++b;
      while (tmpb == NUMERIC_ZERO || tmpb == thousands_sep);

      while (tmpa == tmpb && ISDIGIT (tmpa))
	{
	  do
	    tmpa = *++a;
	  while (tmpa == thousands_sep);
	  do
	    tmpb = *++b;
	  while (tmpb == thousands_sep);
	}

      if ((tmpa == decimal_point && !ISDIGIT (tmpb))
	  || (tmpb == decimal_point && !ISDIGIT (tmpa)))
	return fraccompare (b, a, decimal_point);

      tmp = tmpb - tmpa;

      for (log_a = 0; ISDIGIT (tmpa); ++log_a)
	do
	  tmpa = *++a;
	while (tmpa == thousands_sep);

      for (log_b = 0; ISDIGIT (tmpb); ++log_b)
	do
	  tmpb = *++b;
	while (tmpb == thousands_sep);

      if (log_a != log_b)
	return log_a < log_b ? 1 : -1;

      if (!log_a)
	return 0;

      return tmp;
    }
  else if (tmpb == NEGATION_SIGN)
    {
      do
	tmpb = *++b;
      while (tmpb == NUMERIC_ZERO || tmpb == thousands_sep);
      if (tmpb == decimal_point)
	do
	  tmpb = *++b;
	while (tmpb == NUMERIC_ZERO);
      if (ISDIGIT (tmpb))
	return 1;
      while (tmpa == NUMERIC_ZERO || tmpa == thousands_sep)
	tmpa = *++a;
      if (tmpa == decimal_point)
	do
	  tmpa = *++a;
	while (tmpa == NUMERIC_ZERO);
      return ISDIGIT (tmpa);
    }
  else
    {
      while (tmpa == NUMERIC_ZERO || tmpa == thousands_sep)
	tmpa = *++a;
      while (tmpb == NUMERIC_ZERO || tmpb == thousands_sep)
	tmpb = *++b;

      while (tmpa == tmpb && ISDIGIT (tmpa))
	{
	  do
	    tmpa = *++a;
	  while (tmpa == thousands_sep);
	  do
	    tmpb = *++b;
	  while (tmpb == thousands_sep);
	}

      if ((tmpa == decimal_point && !ISDIGIT (tmpb))
	  || (tmpb == decimal_point && !ISDIGIT (tmpa)))
	return fraccompare (a, b, decimal_point);

      tmp = tmpa - tmpb;

      for (log_a = 0; ISDIGIT (tmpa); ++log_a)
	do
	  tmpa = *++a;
	while (tmpa == thousands_sep);

      for (log_b = 0; ISDIGIT (tmpb); ++log_b)
	do
	  tmpb = *++b;
	while (tmpb == thousands_sep);

      if (log_a != log_b)
	return log_a < log_b ? -1 : 1;

      if (!log_a)
	return 0;

      return tmp;
    }
}

#endif
