/* Test of <stdbool.h> substitute.
   Copyright (C) 2002-2007, 2009-2017 Free Software Foundation, Inc.

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

/* We want this test to succeed even when using gcc's -Werror; but to
   do that requires a pragma that didn't exist before 4.3.0.  */
#ifndef __GNUC__
# define ADDRESS_CHECK_OKAY
#elif __GNUC__ < 4 || (__GNUC__ == 4 && __GNUC_MINOR__ < 3)
/* No way to silence -Waddress.  */
#else
# pragma GCC diagnostic ignored "-Waddress"
# define ADDRESS_CHECK_OKAY
#endif

#include <config.h>

#include <stdbool.h>

#ifndef bool
 "error: bool is not defined"
#endif
#ifndef false
 "error: false is not defined"
#endif
#if false
 "error: false is not 0"
#endif
#ifndef true
 "error: true is not defined"
#endif
#if true != 1
 "error: true is not 1"
#endif
#ifndef __bool_true_false_are_defined
 "error: __bool_true_false_are_defined is not defined"
#endif

/* Several tests cannot be guaranteed with gnulib's <stdbool.h>, at
   least, not for all compilers and compiler options.  */
#if HAVE_STDBOOL_H || 3 <= __GNUC__
struct s { _Bool s: 1; _Bool t; } s;
#endif

char a[true == 1 ? 1 : -1];
char b[false == 0 ? 1 : -1];
char c[__bool_true_false_are_defined == 1 ? 1 : -1];
#if HAVE_STDBOOL_H || 3 <= __GNUC__ /* See above.  */
char d[(bool) 0.5 == true ? 1 : -1];
# ifdef ADDRESS_CHECK_OKAY /* Avoid gcc warning.  */
/* C99 may plausibly be interpreted as not requiring support for a cast from
   a variable's address to bool in a static initializer.  So treat it like a
   GCC extension.  */
#  ifdef __GNUC__
bool e = &s;
#  endif
# endif
char f[(_Bool) 0.0 == false ? 1 : -1];
#endif
char g[true];
char h[sizeof (_Bool)];
#if HAVE_STDBOOL_H || 3 <= __GNUC__ /* See above.  */
char i[sizeof s.t];
#endif
enum { j = false, k = true, l = false * true, m = true * 256 };
_Bool n[m];
char o[sizeof n == m * sizeof n[0] ? 1 : -1];
char p[-1 - (_Bool) 0 < 0 && -1 - (bool) 0 < 0 ? 1 : -1];
/* Catch a bug in an HP-UX C compiler.  See
   http://gcc.gnu.org/ml/gcc-patches/2003-12/msg02303.html
   http://lists.gnu.org/archive/html/bug-coreutils/2005-11/msg00161.html
 */
_Bool q = true;
_Bool *pq = &q;

int
main ()
{
  int error = 0;

#if HAVE_STDBOOL_H || 3 <= __GNUC__ /* See above.  */
# ifdef ADDRESS_CHECK_OKAY /* Avoid gcc warning.  */
  /* A cast from a variable's address to bool is valid in expressions.  */
  {
    bool e1 = &s;
    if (!e1)
      error = 1;
  }
# endif
#endif

  /* Catch a bug in IBM AIX xlc compiler version 6.0.0.0
     reported by James Lemley on 2005-10-05; see
     http://lists.gnu.org/archive/html/bug-coreutils/2005-10/msg00086.html
     This is a runtime test, since a corresponding compile-time
     test would rely on initializer extensions.  */
  {
    char digs[] = "0123456789";
    if (&(digs + 5)[-2 + (bool) 1] != &digs[4])
      error = 1;
  }

  return error;
}
