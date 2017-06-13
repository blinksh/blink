/* A substitute for ISO C11 <stdalign.h>.

   Copyright 2011-2017 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, see <http://www.gnu.org/licenses/>.  */

/* Written by Paul Eggert and Bruno Haible.  */

#ifndef _GL_STDALIGN_H
#define _GL_STDALIGN_H

/* ISO C11 <stdalign.h> for platforms that lack it.

   References:
   ISO C11 (latest free draft
   <http://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf>)
   sections 6.5.3.4, 6.7.5, 7.15.
   C++11 (latest free draft
   <http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2011/n3242.pdf>)
   section 18.10. */

/* alignof (TYPE), also known as _Alignof (TYPE), yields the alignment
   requirement of a structure member (i.e., slot or field) that is of
   type TYPE, as an integer constant expression.

   This differs from GCC's __alignof__ operator, which can yield a
   better-performing alignment for an object of that type.  For
   example, on x86 with GCC, __alignof__ (double) and __alignof__
   (long long) are 8, whereas alignof (double) and alignof (long long)
   are 4 unless the option '-malign-double' is used.

   The result cannot be used as a value for an 'enum' constant, if you
   want to be portable to HP-UX 10.20 cc and AIX 3.2.5 xlc.

   Include <stddef.h> for offsetof.  */
#include <stddef.h>

/* FreeBSD 9.1 <sys/cdefs.h>, included by <stddef.h> and lots of other
   standard headers, defines conflicting implementations of _Alignas
   and _Alignof that are no better than ours; override them.  */
#undef _Alignas
#undef _Alignof

/* GCC releases before GCC 4.9 had a bug in _Alignof.  See GCC bug 52023
   <http://gcc.gnu.org/bugzilla/show_bug.cgi?id=52023>.  */
#if (!defined __STDC_VERSION__ || __STDC_VERSION__ < 201112 \
     || (defined __GNUC__ && __GNUC__ < 4 + (__GNUC_MINOR__ < 9)))
# ifdef __cplusplus
#  if 201103 <= __cplusplus
#   define _Alignof(type) alignof (type)
#  else
   template <class __t> struct __alignof_helper { char __a; __t __b; };
#   define _Alignof(type) offsetof (__alignof_helper<type>, __b)
#  endif
# else
#  define _Alignof(type) offsetof (struct { char __a; type __b; }, __b)
# endif
#endif
#if ! (defined __cplusplus && 201103 <= __cplusplus)
# define alignof _Alignof
#endif
#define __alignof_is_defined 1

/* alignas (A), also known as _Alignas (A), aligns a variable or type
   to the alignment A, where A is an integer constant expression.  For
   example:

      int alignas (8) foo;
      struct s { int a; int alignas (8) bar; };

   aligns the address of FOO and the offset of BAR to be multiples of 8.

   A should be a power of two that is at least the type's alignment
   and at most the implementation's alignment limit.  This limit is
   2**28 on typical GNUish hosts, and 2**13 on MSVC.  To be portable
   to MSVC through at least version 10.0, A should be an integer
   constant, as MSVC does not support expressions such as 1 << 3.
   To be portable to Sun C 5.11, do not align auto variables to
   anything stricter than their default alignment.

   The following C11 requirements are not supported here:

     - If A is zero, alignas has no effect.
     - alignas can be used multiple times; the strictest one wins.
     - alignas (TYPE) is equivalent to alignas (alignof (TYPE)).

   */

#if !defined __STDC_VERSION__ || __STDC_VERSION__ < 201112
# if defined __cplusplus && 201103 <= __cplusplus
#  define _Alignas(a) alignas (a)
# elif ((defined __APPLE__ && defined __MACH__                  \
         ? 4 < __GNUC__ + (1 <= __GNUC_MINOR__)                 \
         : __GNUC__)                                            \
        || 061200 <= __HP_cc || 061200 <= __HP_aCC                \
        || __ICC || 0x590 <= __SUNPRO_C || 0x0600 <= __xlC__)
#  define _Alignas(a) __attribute__ ((__aligned__ (a)))
# elif 1300 <= _MSC_VER
#  define _Alignas(a) __declspec (align (a))
# endif
#endif
#if ((defined _Alignas && ! (defined __cplusplus && 201103 <= __cplusplus)) \
     || (defined __STDC_VERSION__ && 201112 <= __STDC_VERSION__))
# define alignas _Alignas
#endif
#if defined alignas || (defined __cplusplus && 201103 <= __cplusplus)
# define __alignas_is_defined 1
#endif

#endif /* _GL_STDALIGN_H */
