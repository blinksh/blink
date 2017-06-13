/* human.h -- print human readable file size

   Copyright (C) 1996-2007, 2009-2017 Free Software Foundation, Inc.

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

/* Written by Paul Eggert and Larry McVoy.  */

#ifndef HUMAN_H_
# define HUMAN_H_ 1

# include <limits.h>
# include <stdbool.h>
# include <stdint.h>
# include <unistd.h>

# include <xstrtol.h>

/* A conservative bound on the maximum length of a human-readable string.
   The output can be the square of the largest uintmax_t, so double
   its size before converting to a bound.
   log10 (2.0) < 146/485.  Add 1 for integer division truncation.
   Also, the output can have a thousands separator between every digit,
   so multiply by MB_LEN_MAX + 1 and then subtract MB_LEN_MAX.
   Append 1 for a space before the suffix.
   Finally, append 3, the maximum length of a suffix.  */
# define LONGEST_HUMAN_READABLE \
  ((2 * sizeof (uintmax_t) * CHAR_BIT * 146 / 485 + 1) * (MB_LEN_MAX + 1) \
   - MB_LEN_MAX + 1 + 3)

/* Options for human_readable.  */
enum
{
  /* Unless otherwise specified these options may be ORed together.  */

  /* The following three options are mutually exclusive.  */
  /* Round to plus infinity (default).  */
  human_ceiling = 0,
  /* Round to nearest, ties to even.  */
  human_round_to_nearest = 1,
  /* Round to minus infinity.  */
  human_floor = 2,

  /* Group digits together, e.g. "1,000,000".  This uses the
     locale-defined grouping; the traditional C locale does not group,
     so this has effect only if some other locale is in use.  */
  human_group_digits = 4,

  /* When autoscaling, suppress ".0" at end.  */
  human_suppress_point_zero = 8,

  /* Scale output and use SI-style units, ignoring the output block size.  */
  human_autoscale = 16,

  /* Prefer base 1024 to base 1000.  */
  human_base_1024 = 32,

  /* Prepend " " before unit symbol.  */
  human_space_before_unit = 64,

  /* Append SI prefix, e.g. "k" or "M".  */
  human_SI = 128,

  /* Append "B" (if base 1000) or "iB" (if base 1024) to SI prefix.  */
  human_B = 256
};

char *human_readable (uintmax_t, char *, int, uintmax_t, uintmax_t);

enum strtol_error human_options (char const *, int *, uintmax_t *);

#endif /* HUMAN_H_ */
