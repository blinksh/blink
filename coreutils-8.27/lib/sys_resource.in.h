/* Substitute for <sys/resource.h>.
   Copyright (C) 2012-2017 Free Software Foundation, Inc.

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

# if __GNUC__ >= 3
@PRAGMA_SYSTEM_HEADER@
# endif
@PRAGMA_COLUMNS@

#ifndef _@GUARD_PREFIX@_SYS_RESOURCE_H

#if @HAVE_SYS_RESOURCE_H@

/* On FreeBSD 5.0, <sys/resource.h> assumes prior inclusion of <sys/types.h>
   and <sys/time.h>.  */
# include <sys/types.h>
# include <sys/time.h>

/* The include_next requires a split double-inclusion guard.  */
# @INCLUDE_NEXT@ @NEXT_SYS_RESOURCE_H@

#endif

#ifndef _@GUARD_PREFIX@_SYS_RESOURCE_H
#define _@GUARD_PREFIX@_SYS_RESOURCE_H

#if !@HAVE_SYS_RESOURCE_H@
/* A platform that lacks <sys/resource.h>.  */

/* Get 'struct timeval'.  */
# include <sys/time.h>

/* Define the RUSAGE_* constants.  */
# define RUSAGE_SELF 0
# define RUSAGE_CHILDREN -1

# ifdef __cplusplus
extern "C" {
# endif

# if !GNULIB_defined_struct_rusage
/* All known platforms that lack <sys/resource.h> also lack any declaration
   of struct rusage in any other header.  */
struct rusage
{
  struct timeval ru_utime;      /* CPU time used in user mode */
  struct timeval ru_stime;      /* CPU time used in system mode (kernel) */
  long ru_maxrss;
  long ru_ixrss;
  long ru_idrss;
  long ru_isrss;
  long ru_minflt;
  long ru_majflt;
  long ru_nswap;
  long ru_inblock;
  long ru_oublock;
  long ru_msgsnd;
  long ru_msgrcv;
  long ru_nsignals;
  long ru_nvcsw;
  long ru_nivcsw;
};
#  define GNULIB_defined_struct_rusage 1
# endif

# ifdef __cplusplus
}
# endif

#endif

/* The definitions of _GL_FUNCDECL_RPL etc. are copied here.  */

/* The definition of _GL_ARG_NONNULL is copied here.  */

/* The definition of _GL_WARN_ON_USE is copied here.  */


/* Declare overridden functions.  */


#if @GNULIB_GETRUSAGE@
# if !@HAVE_GETRUSAGE@
_GL_FUNCDECL_SYS (getrusage, int, (int who, struct rusage *usage_p)
                                  _GL_ARG_NONNULL ((2)));
# endif
_GL_CXXALIAS_SYS (getrusage, int, (int who, struct rusage *usage_p));
_GL_CXXALIASWARN (getrusage);
#elif defined GNULIB_POSIXCHECK
# undef getrusage
# if HAVE_RAW_DECL_GETRUSAGE
_GL_WARN_ON_USE (getrusage, "getrusage is unportable - "
                 "use gnulib module getrusage for portability");
# endif
#endif


#endif /* _@GUARD_PREFIX@_SYS_RESOURCE_H */
#endif /* _@GUARD_PREFIX@_SYS_RESOURCE_H */
