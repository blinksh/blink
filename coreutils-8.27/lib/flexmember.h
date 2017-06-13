/* Sizes of structs with flexible array members.

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
   along with this program.  If not, see <http://www.gnu.org/licenses/>.

   Written by Paul Eggert.  */

#include <stddef.h>

/* Nonzero multiple of alignment of TYPE, suitable for FLEXSIZEOF below.
   On older platforms without _Alignof, use a pessimistic bound that is
   safe in practice even if FLEXIBLE_ARRAY_MEMBER is 1.
   On newer platforms, use _Alignof to get a tighter bound.  */

#if !defined __STDC_VERSION__ || __STDC_VERSION__ < 201112
# define FLEXALIGNOF(type) (sizeof (type) & ~ (sizeof (type) - 1))
#else
# define FLEXALIGNOF(type) _Alignof (type)
#endif

/* Upper bound on the size of a struct of type TYPE with a flexible
   array member named MEMBER that is followed by N bytes of other data.
   This is not simply sizeof (TYPE) + N, since it may require
   alignment on unusually picky C11 platforms, and
   FLEXIBLE_ARRAY_MEMBER may be 1 on pre-C11 platforms.
   Yield a value less than N if and only if arithmetic overflow occurs.  */

#define FLEXSIZEOF(type, member, n) \
   ((offsetof (type, member) + FLEXALIGNOF (type) - 1 + (n)) \
    & ~ (FLEXALIGNOF (type) - 1))
