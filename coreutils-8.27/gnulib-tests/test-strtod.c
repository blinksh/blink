/*
 * Copyright (C) 2008-2017 Free Software Foundation, Inc.
 * Written by Eric Blake
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

#include <config.h>

#include <stdlib.h>

#include "signature.h"
SIGNATURE_CHECK (strtod, double, (char const *, char **));

#include <errno.h>
#include <float.h>
#include <math.h>
#include <string.h>

#include "isnand-nolibm.h"
#include "minus-zero.h"
#include "macros.h"

/* Avoid requiring -lm just for fabs.  */
#define FABS(d) ((d) < 0.0 ? -(d) : (d))

int
main (void)
{
  int status = 0;
  /* Subject sequence empty or invalid.  */
  {
    const char input[] = "";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 0.0);
    ASSERT (!signbit (result));
    ASSERT (ptr == input);
    ASSERT (errno == 0 || errno == EINVAL);
  }
  {
    const char input[] = " ";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 0.0);
    ASSERT (!signbit (result));
    ASSERT (ptr == input);
    ASSERT (errno == 0 || errno == EINVAL);
  }
  {
    const char input[] = " +";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 0.0);
    ASSERT (!signbit (result));
    ASSERT (ptr == input);
    ASSERT (errno == 0 || errno == EINVAL);
  }
  {
    const char input[] = " .";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 0.0);
    ASSERT (!signbit (result));
    ASSERT (ptr == input);
    ASSERT (errno == 0 || errno == EINVAL);
  }
  {
    const char input[] = " .e0";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 0.0);
    ASSERT (!signbit (result));
    ASSERT (ptr == input);              /* IRIX 6.5, OSF/1 5.1 */
    ASSERT (errno == 0 || errno == EINVAL);
  }
  {
    const char input[] = " +.e-0";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 0.0);
    ASSERT (!signbit (result));
    ASSERT (ptr == input);              /* IRIX 6.5, OSF/1 5.1 */
    ASSERT (errno == 0 || errno == EINVAL);
  }
  {
    const char input[] = " in";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 0.0);
    ASSERT (!signbit (result));
    ASSERT (ptr == input);
    ASSERT (errno == 0 || errno == EINVAL);
  }
  {
    const char input[] = " na";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 0.0);
    ASSERT (!signbit (result));
    ASSERT (ptr == input);
    ASSERT (errno == 0 || errno == EINVAL);
  }

  /* Simple floating point values.  */
  {
    const char input[] = "1";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 1.0);
    ASSERT (ptr == input + 1);
    ASSERT (errno == 0);
  }
  {
    const char input[] = "1.";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 1.0);
    ASSERT (ptr == input + 2);
    ASSERT (errno == 0);
  }
  {
    const char input[] = ".5";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    /* FIXME - gnulib's version is rather inaccurate.  It would be
       nice to guarantee an exact result, but for now, we settle for a
       1-ulp error.  */
    ASSERT (FABS (result - 0.5) < DBL_EPSILON);
    ASSERT (ptr == input + 2);
    ASSERT (errno == 0);
  }
  {
    const char input[] = " 1";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 1.0);
    ASSERT (ptr == input + 2);
    ASSERT (errno == 0);
  }
  {
    const char input[] = "+1";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 1.0);
    ASSERT (ptr == input + 2);
    ASSERT (errno == 0);
  }
  {
    const char input[] = "-1";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == -1.0);
    ASSERT (ptr == input + 2);
    ASSERT (errno == 0);
  }
  {
    const char input[] = "1e0";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 1.0);
    ASSERT (ptr == input + 3);
    ASSERT (errno == 0);
  }
  {
    const char input[] = "1e+0";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 1.0);
    ASSERT (ptr == input + 4);
    ASSERT (errno == 0);
  }
  {
    const char input[] = "1e-0";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 1.0);
    ASSERT (ptr == input + 4);
    ASSERT (errno == 0);
  }
  {
    const char input[] = "1e1";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 10.0);
    ASSERT (ptr == input + 3);
    ASSERT (errno == 0);
  }
  {
    const char input[] = "5e-1";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    /* FIXME - gnulib's version is rather inaccurate.  It would be
       nice to guarantee an exact result, but for now, we settle for a
       1-ulp error.  */
    ASSERT (FABS (result - 0.5) < DBL_EPSILON);
    ASSERT (ptr == input + 4);
    ASSERT (errno == 0);
  }

  /* Zero.  */
  {
    const char input[] = "0";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 0.0);
    ASSERT (!signbit (result));
    ASSERT (ptr == input + 1);
    ASSERT (errno == 0);
  }
  {
    const char input[] = ".0";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 0.0);
    ASSERT (!signbit (result));
    ASSERT (ptr == input + 2);
    ASSERT (errno == 0);
  }
  {
    const char input[] = "0e0";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 0.0);
    ASSERT (!signbit (result));
    ASSERT (ptr == input + 3);
    ASSERT (errno == 0);
  }
  {
    const char input[] = "0e+9999999";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 0.0);
    ASSERT (!signbit (result));
    ASSERT (ptr == input + 10);
    ASSERT (errno == 0);
  }
  {
    const char input[] = "0e-9999999";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 0.0);
    ASSERT (!signbit (result));
    ASSERT (ptr == input + 10);
    ASSERT (errno == 0);
  }
  {
    const char input[] = "-0";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 0.0);
    ASSERT (!!signbit (result) == !!signbit (minus_zerod)); /* IRIX 6.5, OSF/1 4.0 */
    ASSERT (ptr == input + 2);
    ASSERT (errno == 0);
  }

  /* Suffixes.  */
  {
    const char input[] = "1f";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 1.0);
    ASSERT (ptr == input + 1);
    ASSERT (errno == 0);
  }
  {
    const char input[] = "1.f";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 1.0);
    ASSERT (ptr == input + 2);
    ASSERT (errno == 0);
  }
  {
    const char input[] = "1e";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 1.0);
    ASSERT (ptr == input + 1);
    ASSERT (errno == 0);
  }
  {
    const char input[] = "1e+";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 1.0);
    ASSERT (ptr == input + 1);
    ASSERT (errno == 0);
  }
  {
    const char input[] = "1e-";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 1.0);
    ASSERT (ptr == input + 1);
    ASSERT (errno == 0);
  }
  {
    const char input[] = "1E 2";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 1.0);             /* HP-UX 11.11, IRIX 6.5, OSF/1 4.0 */
    ASSERT (ptr == input + 1);          /* HP-UX 11.11, IRIX 6.5 */
    ASSERT (errno == 0);
  }
  {
    const char input[] = "0x";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 0.0);
    ASSERT (!signbit (result));
    ASSERT (ptr == input + 1);          /* glibc-2.3.6, Mac OS X 10.3, FreeBSD 6.2, AIX 7.1 */
    ASSERT (errno == 0);
  }
  {
    const char input[] = "00x1";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 0.0);
    ASSERT (!signbit (result));
    ASSERT (ptr == input + 2);
    ASSERT (errno == 0);
  }
  {
    const char input[] = "-0x";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 0.0);
    ASSERT (!!signbit (result) == !!signbit (minus_zerod)); /* Mac OS X 10.3, FreeBSD 6.2, IRIX 6.5, OSF/1 4.0 */
    ASSERT (ptr == input + 2);          /* glibc-2.3.6, Mac OS X 10.3, FreeBSD 6.2, AIX 7.1 */
    ASSERT (errno == 0);
  }
  {
    const char input[] = "0xg";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 0.0);
    ASSERT (!signbit (result));
    ASSERT (ptr == input + 1);          /* glibc-2.3.6, Mac OS X 10.3, FreeBSD 6.2, AIX 7.1 */
    ASSERT (errno == 0);
  }
  {
    const char input[] = "0xp";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 0.0);
    ASSERT (!signbit (result));
    ASSERT (ptr == input + 1);          /* glibc-2.3.6, Mac OS X 10.3, FreeBSD 6.2, AIX 7.1 */
    ASSERT (errno == 0);
  }
  {
    const char input[] = "0XP";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 0.0);
    ASSERT (!signbit (result));
    ASSERT (ptr == input + 1);          /* glibc-2.3.6, Mac OS X 10.3, FreeBSD 6.2, AIX 7.1 */
    ASSERT (errno == 0);
  }
  {
    const char input[] = "0x.";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 0.0);
    ASSERT (!signbit (result));
    ASSERT (ptr == input + 1);          /* glibc-2.3.6, Mac OS X 10.3, FreeBSD 6.2, AIX 7.1 */
    ASSERT (errno == 0);
  }
  {
    const char input[] = "0xp+";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 0.0);
    ASSERT (!signbit (result));
    ASSERT (ptr == input + 1);          /* glibc-2.3.6, Mac OS X 10.3, FreeBSD 6.2, AIX 7.1 */
    ASSERT (errno == 0);
  }
  {
    const char input[] = "0xp+1";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 0.0);
    ASSERT (!signbit (result));
    ASSERT (ptr == input + 1);          /* glibc-2.3.6, Mac OS X 10.3, FreeBSD 6.2, AIX 7.1 */
    ASSERT (errno == 0);
  }
  {
    const char input[] = "0x.p+1";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 0.0);
    ASSERT (!signbit (result));
    ASSERT (ptr == input + 1);          /* glibc-2.3.6, Mac OS X 10.3, FreeBSD 6.2, AIX 7.1 */
    ASSERT (errno == 0);
  }
  {
    const char input[] = "1p+1";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 1.0);
    ASSERT (ptr == input + 1);
    ASSERT (errno == 0);
  }
  {
    const char input[] = "1P+1";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 1.0);
    ASSERT (ptr == input + 1);
    ASSERT (errno == 0);
  }

  /* Overflow/underflow.  */
  {
    const char input[] = "1E1000000";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == HUGE_VAL);
    ASSERT (ptr == input + 9);          /* OSF/1 5.1 */
    ASSERT (errno == ERANGE);
  }
  {
    const char input[] = "-1E1000000";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == -HUGE_VAL);
    ASSERT (ptr == input + 10);
    ASSERT (errno == ERANGE);
  }
  {
    const char input[] = "1E-100000";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (0.0 <= result && result <= DBL_MIN);
    ASSERT (!signbit (result));
    ASSERT (ptr == input + 9);
    ASSERT (errno == ERANGE);
  }
  {
    const char input[] = "-1E-100000";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (-DBL_MIN <= result && result <= 0.0);
#if 0
    /* FIXME - this is glibc bug 5995; POSIX allows returning positive
       0 on negative underflow, even though quality of implementation
       demands preserving the sign.  Disable this test until fixed
       glibc is more prevalent.  */
    ASSERT (!!signbit (result) == !!signbit (minus_zerod)); /* glibc-2.3.6, mingw */
#endif
    ASSERT (ptr == input + 10);
    ASSERT (errno == ERANGE);
  }
  {
    const char input[] = "1E 1000000";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 1.0);             /* HP-UX 11.11, IRIX 6.5, OSF/1 4.0 */
    ASSERT (ptr == input + 1);          /* HP-UX 11.11, IRIX 6.5 */
    ASSERT (errno == 0);
  }
  {
    const char input[] = "0x1P 1000000";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 1.0);             /* NetBSD 3.0, OpenBSD 4.0, AIX 7.1, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, Solaris 10, mingw */
    ASSERT (ptr == input + 3);          /* NetBSD 3.0, OpenBSD 4.0, AIX 7.1, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, Solaris 10, mingw */
    ASSERT (errno == 0);
  }

  /* Infinity.  */
  {
    const char input[] = "iNf";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == HUGE_VAL);        /* OpenBSD 4.0, IRIX 6.5, OSF/1 5.1, mingw */
    ASSERT (ptr == input + 3);          /* OpenBSD 4.0, HP-UX 11.00, IRIX 6.5, OSF/1 5.1, Solaris 9, mingw */
    ASSERT (errno == 0);                /* HP-UX 11.11, OSF/1 4.0 */
  }
  {
    const char input[] = "-InF";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == -HUGE_VAL);       /* OpenBSD 4.0, IRIX 6.5, OSF/1 5.1, mingw */
    ASSERT (ptr == input + 4);          /* OpenBSD 4.0, HP-UX 11.00, IRIX 6.5, OSF/1 4.0, Solaris 9, mingw */
    ASSERT (errno == 0);                /* HP-UX 11.11, OSF/1 4.0 */
  }
  {
    const char input[] = "infinite";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == HUGE_VAL);        /* OpenBSD 4.0, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, mingw */
    ASSERT (ptr == input + 3);          /* OpenBSD 4.0, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, mingw */
    ASSERT (errno == 0);                /* OSF/1 4.0 */
  }
  {
    const char input[] = "infinitY";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == HUGE_VAL);        /* OpenBSD 4.0, IRIX 6.5, OSF/1 5.1, mingw */
    ASSERT (ptr == input + 8);          /* OpenBSD 4.0, HP-UX 11.00, IRIX 6.5, OSF/1 5.1, Solaris 9, mingw */
    ASSERT (errno == 0);                /* HP-UX 11.11, OSF/1 4.0 */
  }
  {
    const char input[] = "infinitY.";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == HUGE_VAL);        /* OpenBSD 4.0, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, mingw */
    ASSERT (ptr == input + 8);          /* OpenBSD 4.0, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, mingw */
    ASSERT (errno == 0);                /* OSF/1 4.0 */
  }

  /* NaN.  Some processors set the sign bit of the default NaN, so all
     we check is that using a sign changes the result.  */
  {
    const char input[] = "-nan";
    char *ptr1;
    char *ptr2;
    double result1;
    double result2;
    errno = 0;
    result1 = strtod (input, &ptr1);
    result2 = strtod (input + 1, &ptr2);
#if 1 /* All known CPUs support NaNs.  */
    ASSERT (isnand (result1));          /* OpenBSD 4.0, IRIX 6.5, OSF/1 5.1, mingw */
    ASSERT (isnand (result2));          /* OpenBSD 4.0, IRIX 6.5, OSF/1 5.1, mingw */
# if 0
    /* Sign bits of NaN is a portability sticking point, not worth
       worrying about.  */
    ASSERT (!!signbit (result1) != !!signbit (result2)); /* glibc-2.3.6, IRIX 6.5, OSF/1 5.1, mingw */
# endif
    ASSERT (ptr1 == input + 4);         /* OpenBSD 4.0, IRIX 6.5, OSF/1 5.1, Solaris 2.5.1, mingw */
    ASSERT (ptr2 == input + 4);         /* OpenBSD 4.0, IRIX 6.5, OSF/1 5.1, Solaris 2.5.1, mingw */
    ASSERT (errno == 0);                /* HP-UX 11.11 */
#else
    ASSERT (result1 == 0.0);
    ASSERT (result2 == 0.0);
    ASSERT (!signbit (result1));
    ASSERT (!signbit (result2));
    ASSERT (ptr1 == input);
    ASSERT (ptr2 == input + 1);
    ASSERT (errno == 0 || errno == EINVAL);
#endif
  }
  {
    const char input[] = "+nan(";
    char *ptr1;
    char *ptr2;
    double result1;
    double result2;
    errno = 0;
    result1 = strtod (input, &ptr1);
    result2 = strtod (input + 1, &ptr2);
#if 1 /* All known CPUs support NaNs.  */
    ASSERT (isnand (result1));          /* OpenBSD 4.0, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, mingw */
    ASSERT (isnand (result2));          /* OpenBSD 4.0, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, mingw */
    ASSERT (!!signbit (result1) == !!signbit (result2));
    ASSERT (ptr1 == input + 4);         /* OpenBSD 4.0, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, Solaris 2.5.1, mingw */
    ASSERT (ptr2 == input + 4);         /* OpenBSD 4.0, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, Solaris 2.5.1, mingw */
    ASSERT (errno == 0);
#else
    ASSERT (result1 == 0.0);
    ASSERT (result2 == 0.0);
    ASSERT (!signbit (result1));
    ASSERT (!signbit (result2));
    ASSERT (ptr1 == input);
    ASSERT (ptr2 == input + 1);
    ASSERT (errno == 0 || errno == EINVAL);
#endif
  }
  {
    const char input[] = "-nan()";
    char *ptr1;
    char *ptr2;
    double result1;
    double result2;
    errno = 0;
    result1 = strtod (input, &ptr1);
    result2 = strtod (input + 1, &ptr2);
#if 1 /* All known CPUs support NaNs.  */
    ASSERT (isnand (result1));          /* OpenBSD 4.0, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, mingw */
    ASSERT (isnand (result2));          /* OpenBSD 4.0, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, mingw */
# if 0
    /* Sign bits of NaN is a portability sticking point, not worth
       worrying about.  */
    ASSERT (!!signbit (result1) != !!signbit (result2)); /* glibc-2.3.6, IRIX 6.5, OSF/1 5.1, mingw */
# endif
    ASSERT (ptr1 == input + 6);         /* glibc-2.3.6, Mac OS X 10.3, FreeBSD 6.2, OpenBSD 4.0, AIX 7.1, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, mingw */
    ASSERT (ptr2 == input + 6);         /* glibc-2.3.6, Mac OS X 10.3, FreeBSD 6.2, OpenBSD 4.0, AIX 7.1, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, mingw */
    ASSERT (errno == 0);
#else
    ASSERT (result1 == 0.0);
    ASSERT (result2 == 0.0);
    ASSERT (!signbit (result1));
    ASSERT (!signbit (result2));
    ASSERT (ptr1 == input);
    ASSERT (ptr2 == input + 1);
    ASSERT (errno == 0 || errno == EINVAL);
#endif
  }
  {
    const char input[] = " nan().";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
#if 1 /* All known CPUs support NaNs.  */
    ASSERT (isnand (result));           /* OpenBSD 4.0, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, mingw */
    ASSERT (ptr == input + 6);          /* glibc-2.3.6, Mac OS X 10.3, FreeBSD 6.2, OpenBSD 4.0, AIX 7.1, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, mingw */
    ASSERT (errno == 0);
#else
    ASSERT (result == 0.0);
    ASSERT (!signbit (result));
    ASSERT (ptr == input);
    ASSERT (errno == 0 || errno == EINVAL);
#endif
  }
  {
    /* The behavior of nan(0) is implementation-defined, but all
       implementations we know of which handle optional
       n-char-sequences handle nan(0) the same as nan().  */
    const char input[] = "-nan(0).";
    char *ptr1;
    char *ptr2;
    double result1;
    double result2;
    errno = 0;
    result1 = strtod (input, &ptr1);
    result2 = strtod (input + 1, &ptr2);
#if 1 /* All known CPUs support NaNs.  */
    ASSERT (isnand (result1));          /* OpenBSD 4.0, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, mingw */
    ASSERT (isnand (result2));          /* OpenBSD 4.0, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, mingw */
# if 0
    /* Sign bits of NaN is a portability sticking point, not worth
       worrying about.  */
    ASSERT (!!signbit (result1) != !!signbit (result2)); /* glibc-2.3.6, IRIX 6.5, OSF/1 5.1, mingw */
# endif
    ASSERT (ptr1 == input + 7);         /* glibc-2.3.6, OpenBSD 4.0, AIX 7.1, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, mingw */
    ASSERT (ptr2 == input + 7);         /* glibc-2.3.6, OpenBSD 4.0, AIX 7.1, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, mingw */
    ASSERT (errno == 0);
#else
    ASSERT (result1 == 0.0);
    ASSERT (result2 == 0.0);
    ASSERT (!signbit (result1));
    ASSERT (!signbit (result2));
    ASSERT (ptr1 == input);
    ASSERT (ptr2 == input + 1);
    ASSERT (errno == 0 || errno == EINVAL);
#endif
  }

  /* Hex.  */
  {
    const char input[] = "0xa";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 10.0);            /* NetBSD 3.0, OpenBSD 4.0, AIX 5.1, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, Solaris 10, mingw */
    ASSERT (ptr == input + 3);          /* NetBSD 3.0, OpenBSD 4.0, AIX 5.1, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, Solaris 10, mingw */
    ASSERT (errno == 0);
  }
  {
    const char input[] = "0XA";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 10.0);            /* NetBSD 3.0, OpenBSD 4.0, AIX 5.1, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, Solaris 10, mingw */
    ASSERT (ptr == input + 3);          /* NetBSD 3.0, OpenBSD 4.0, AIX 5.1, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, Solaris 10, mingw */
    ASSERT (errno == 0);
  }
  {
    const char input[] = "0x1p";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 1.0);             /* NetBSD 3.0, OpenBSD 4.0, AIX 7.1, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, Solaris 10, mingw */
    ASSERT (ptr == input + 3);          /* NetBSD 3.0, OpenBSD 4.0, AIX 7.1, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, Solaris 10, mingw */
    ASSERT (errno == 0);
  }
  {
    const char input[] = "0x1p+";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 1.0);             /* NetBSD 3.0, OpenBSD 4.0, AIX 5.1, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, Solaris 10, mingw */
    ASSERT (ptr == input + 3);          /* NetBSD 3.0, OpenBSD 4.0, AIX 5.1, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, Solaris 10, mingw */
    ASSERT (errno == 0);
  }
  {
    const char input[] = "0x1P+";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 1.0);             /* NetBSD 3.0, OpenBSD 4.0, AIX 5.1, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, Solaris 10, mingw */
    ASSERT (ptr == input + 3);          /* NetBSD 3.0, OpenBSD 4.0, AIX 5.1, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, Solaris 10, mingw */
    ASSERT (errno == 0);
  }
  {
    const char input[] = "0x1p+1";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 2.0);             /* NetBSD 3.0, OpenBSD 4.0, AIX 5.1, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, Solaris 10, mingw */
    ASSERT (ptr == input + 6);          /* NetBSD 3.0, OpenBSD 4.0, AIX 5.1, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, Solaris 10, mingw */
    ASSERT (errno == 0);
  }
  {
    const char input[] = "0X1P+1";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 2.0);             /* NetBSD 3.0, OpenBSD 4.0, AIX 5.1, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, Solaris 10, mingw */
    ASSERT (ptr == input + 6);          /* NetBSD 3.0, OpenBSD 4.0, AIX 5.1, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, Solaris 10, mingw */
    ASSERT (errno == 0);
  }
  {
    const char input[] = "0x1p+1a";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 2.0);             /* NetBSD 3.0, OpenBSD 4.0, AIX 5.1, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, Solaris 10, mingw */
    ASSERT (ptr == input + 6);          /* NetBSD 3.0, OpenBSD 4.0, AIX 5.1, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, Solaris 10, mingw */
    ASSERT (errno == 0);
  }
  {
    const char input[] = "0x1p 2";
    char *ptr;
    double result;
    errno = 0;
    result = strtod (input, &ptr);
    ASSERT (result == 1.0);             /* NetBSD 3.0, OpenBSD 4.0, AIX 7.1, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, Solaris 10, mingw */
    ASSERT (ptr == input + 3);          /* NetBSD 3.0, OpenBSD 4.0, AIX 7.1, HP-UX 11.11, IRIX 6.5, OSF/1 5.1, Solaris 10, mingw */
    ASSERT (errno == 0);
  }

  /* Large buffers.  */
  {
    size_t m = 1000000;
    char *input = malloc (m + 1);
    if (input)
      {
        char *ptr;
        double result;
        memset (input, '\t', m - 1);
        input[m - 1] = '1';
        input[m] = '\0';
        errno = 0;
        result = strtod (input, &ptr);
        ASSERT (result == 1.0);
        ASSERT (ptr == input + m);
        ASSERT (errno == 0);
      }
    free (input);
  }
  {
    size_t m = 1000000;
    char *input = malloc (m + 1);
    if (input)
      {
        char *ptr;
        double result;
        memset (input, '0', m - 1);
        input[m - 1] = '1';
        input[m] = '\0';
        errno = 0;
        result = strtod (input, &ptr);
        ASSERT (result == 1.0);
        ASSERT (ptr == input + m);
        ASSERT (errno == 0);
      }
    free (input);
  }
#if 0
  /* Newlib has an artificial limit of 20000 for the exponent.  TODO -
     gnulib should fix this.  */
  {
    size_t m = 1000000;
    char *input = malloc (m + 1);
    if (input)
      {
        char *ptr;
        double result;
        input[0] = '.';
        memset (input + 1, '0', m - 10);
        input[m - 9] = '1';
        input[m - 8] = 'e';
        input[m - 7] = '+';
        input[m - 6] = '9';
        input[m - 5] = '9';
        input[m - 4] = '9';
        input[m - 3] = '9';
        input[m - 2] = '9';
        input[m - 1] = '1';
        input[m] = '\0';
        errno = 0;
        result = strtod (input, &ptr);
        ASSERT (result == 1.0);         /* Mac OS X 10.3, FreeBSD 6.2, NetBSD 3.0, OpenBSD 4.0, IRIX 6.5, OSF/1 5.1, mingw */
        ASSERT (ptr == input + m);      /* OSF/1 5.1 */
        ASSERT (errno == 0);            /* Mac OS X 10.3, FreeBSD 6.2, NetBSD 3.0, OpenBSD 4.0, IRIX 6.5, OSF/1 5.1, mingw */
      }
    free (input);
  }
  {
    size_t m = 1000000;
    char *input = malloc (m + 1);
    if (input)
      {
        char *ptr;
        double result;
        input[0] = '1';
        memset (input + 1, '0', m - 9);
        input[m - 8] = 'e';
        input[m - 7] = '-';
        input[m - 6] = '9';
        input[m - 5] = '9';
        input[m - 4] = '9';
        input[m - 3] = '9';
        input[m - 2] = '9';
        input[m - 1] = '1';
        input[m] = '\0';
        errno = 0;
        result = strtod (input, &ptr);
        ASSERT (result == 1.0);         /* Mac OS X 10.3, FreeBSD 6.2, NetBSD 3.0, OpenBSD 4.0, IRIX 6.5, OSF/1 5.1, mingw */
        ASSERT (ptr == input + m);
        ASSERT (errno == 0);            /* Mac OS X 10.3, FreeBSD 6.2, NetBSD 3.0, OpenBSD 4.0, IRIX 6.5, OSF/1 5.1, mingw */
      }
    free (input);
  }
#endif
  {
    size_t m = 1000000;
    char *input = malloc (m + 1);
    if (input)
      {
        char *ptr;
        double result;
        input[0] = '-';
        input[1] = '0';
        input[2] = 'e';
        input[3] = '1';
        memset (input + 4, '0', m - 3);
        input[m] = '\0';
        errno = 0;
        result = strtod (input, &ptr);
        ASSERT (result == 0.0);
        ASSERT (!!signbit (result) == !!signbit (minus_zerod)); /* IRIX 6.5, OSF/1 4.0 */
        ASSERT (ptr == input + m);
        ASSERT (errno == 0);
      }
    free (input);
  }

  /* Rounding.  */
  /* TODO - is it worth some tests of rounding for typical IEEE corner
     cases, such as .5 ULP rounding up to the smallest denormal and
     not causing underflow, or DBL_MIN - .5 ULP not causing an
     infinite loop?  */

  return status;
}
