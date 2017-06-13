/* Test of <stdalign.h>.
   Copyright 2009-2017 Free Software Foundation, Inc.

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

/* Written by Paul Eggert, inspired by Bruno Haible's test-alignof.c.  */

#include <config.h>

#include <stdalign.h>

#include <stddef.h>
#include <stdint.h>

#include "verify.h"

#include "macros.h"

typedef long double longdouble;
typedef struct { char a[1]; } struct1;
typedef struct { char a[2]; } struct2;
typedef struct { char a[3]; } struct3;
typedef struct { char a[4]; } struct4;

verify (__alignof_is_defined == 1);
#ifndef alignof
# error "alignof is not a macro"
#endif

#if __alignas_is_defined
verify (__alignas_is_defined == 1);
# ifndef alignas
#  error "alignas is not a macro"
# endif
/* mingw can go up only to 8.  8 is all that GNU Emacs needs, so let's
   limit the test to 8 for now.  */
# define TEST_ALIGNMENT 8
#else
# define _Alignas(alignment)
# define alignas(alignment)
# define TEST_ALIGNMENT 1
#endif

#define CHECK_STATIC(type) \
  typedef struct { char slot1; type slot2; } type##_helper; \
  verify (alignof (type) == offsetof (type##_helper, slot2)); \
  verify (_Alignof (type) == alignof (type)); \
  const int type##_alignment = alignof (type); \
  type alignas (TEST_ALIGNMENT) static_##type##_alignas; \
  type _Alignas (TEST_ALIGNMENT) static_##type##_Alignas

#define CHECK_ALIGNED(var) ASSERT ((uintptr_t) &(var) % TEST_ALIGNMENT == 0)

CHECK_STATIC (char);
CHECK_STATIC (short);
CHECK_STATIC (int);
CHECK_STATIC (long);
#ifdef INT64_MAX
CHECK_STATIC (int64_t);
#endif
CHECK_STATIC (float);
CHECK_STATIC (double);
/* CHECK_STATIC (longdouble); */
CHECK_STATIC (struct1);
CHECK_STATIC (struct2);
CHECK_STATIC (struct3);
CHECK_STATIC (struct4);

int
main ()
{
#if defined __SUNPRO_C
  /* Avoid a test failure due to Sun Studio Developer Bug Report #2125432.  */
  fputs ("Skipping test: known Sun C compiler bug\n", stderr);
  return 77;
#else
  CHECK_ALIGNED (static_char_alignas);
  CHECK_ALIGNED (static_char_Alignas);
  CHECK_ALIGNED (static_short_alignas);
  CHECK_ALIGNED (static_short_Alignas);
  CHECK_ALIGNED (static_int_alignas);
  CHECK_ALIGNED (static_int_Alignas);
  CHECK_ALIGNED (static_long_alignas);
  CHECK_ALIGNED (static_long_Alignas);
# ifdef INT64_MAX
  CHECK_ALIGNED (static_int64_t_alignas);
  CHECK_ALIGNED (static_int64_t_Alignas);
# endif
  CHECK_ALIGNED (static_float_alignas);
  CHECK_ALIGNED (static_float_Alignas);
  CHECK_ALIGNED (static_double_alignas);
  CHECK_ALIGNED (static_double_Alignas);
  /* CHECK_ALIGNED (static_longdouble_alignas); */
  /* CHECK_ALIGNED (static_longdouble_Alignas); */
  CHECK_ALIGNED (static_struct1_alignas);
  CHECK_ALIGNED (static_struct1_Alignas);
  CHECK_ALIGNED (static_struct2_alignas);
  CHECK_ALIGNED (static_struct2_Alignas);
  CHECK_ALIGNED (static_struct3_alignas);
  CHECK_ALIGNED (static_struct3_Alignas);
  CHECK_ALIGNED (static_struct4_alignas);
  CHECK_ALIGNED (static_struct4_Alignas);
  return 0;
#endif
}
