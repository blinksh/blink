/* inttostr.h -- convert integers to printable strings

   Copyright (C) 2001-2006, 2009-2017 Free Software Foundation, Inc.

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

/* Written by Paul Eggert */

#include <stdint.h>
#include <sys/types.h>

#include "intprops.h"

#ifndef __GNUC_PREREQ
# if defined __GNUC__ && defined __GNUC_MINOR__
#  define __GNUC_PREREQ(maj, min) \
         ((__GNUC__ << 16) + __GNUC_MINOR__ >= ((maj) << 16) + (min))
# else
#  define __GNUC_PREREQ(maj, min) 0
# endif
#endif

#if __GNUC_PREREQ (3,4)
# undef __attribute_warn_unused_result__
# define __attribute_warn_unused_result__ \
   __attribute__ ((__warn_unused_result__))
#else
# define __attribute_warn_unused_result__ /* empty */
#endif

char *imaxtostr (intmax_t, char *) __attribute_warn_unused_result__;
char *inttostr (int, char *) __attribute_warn_unused_result__;
char *offtostr (off_t, char *) __attribute_warn_unused_result__;
char *uinttostr (unsigned int, char *) __attribute_warn_unused_result__;
char *umaxtostr (uintmax_t, char *) __attribute_warn_unused_result__;
