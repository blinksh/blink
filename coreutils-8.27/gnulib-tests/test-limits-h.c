/* Test of <limits.h> substitute.
   Copyright 2016-2017 Free Software Foundation, Inc.

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

/* Written by Paul Eggert.  */

#include <config.h>

#include <limits.h>

#include "verify.h"

#if 4 < __GNUC__ + (3 <= __GNUC_MINOR__)
# pragma GCC diagnostic ignored "-Woverlength-strings"
#endif

/* Macros specified by ISO/IEC TS 18661-1:2014.  */

#define verify_width(width, min, max) \
  verify ((max) >> ((width) - 1 - ((min) < 0)) == 1)

verify_width (CHAR_WIDTH, CHAR_MIN, CHAR_MAX);
verify_width (SCHAR_WIDTH, SCHAR_MIN, SCHAR_MAX);
verify_width (UCHAR_WIDTH, 0, UCHAR_MAX);
verify_width (SHRT_WIDTH, SHRT_MIN, SHRT_MAX);
verify_width (USHRT_WIDTH, 0, USHRT_MAX);
verify_width (INT_WIDTH, INT_MIN, INT_MAX);
verify_width (UINT_WIDTH, 0, UINT_MAX);
verify_width (LONG_WIDTH, LONG_MIN, LONG_MAX);
verify_width (ULONG_WIDTH, 0, ULONG_MAX);
verify_width (LLONG_WIDTH, LLONG_MIN, LLONG_MAX);
verify_width (ULLONG_WIDTH, 0, ULLONG_MAX);

int
main (void)
{
  return 0;
}
