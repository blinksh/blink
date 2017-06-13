/* Report an error and exit.
   Copyright 2016-2017 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street - Fifth Floor, Boston, MA
   02110-1301, USA.  */

#ifndef DIE_H
# define DIE_H

# include <error.h>
# include <stdbool.h>
# include <verify.h>

/* Like 'error (STATUS, ...)', except STATUS must be a nonzero constant.
   This may pacify the compiler or help it generate better code.  */
# define die(status, ...) \
  verify_expr (status, (error (status, __VA_ARGS__), assume (false)))

#endif /* DIE_H */
