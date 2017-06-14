/* timespec -- System time interface

   Copyright (C) 2000, 2002, 2004, 2005 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software Foundation,
   Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.  */

#if ! defined TIMESPEC_H
# define TIMESPEC_H

# include <sys/types.h>
# if TIME_WITH_SYS_TIME
#  include <sys/time.h>
#  include <time.h>
# else
#  if HAVE_SYS_TIME_H
#   include <sys/time.h>
#  else
#   include <time.h>
#  endif
# endif

# if ! HAVE_STRUCT_TIMESPEC
/* Some systems don't define this struct, e.g., AIX 4.1, Ultrix 4.3.  */
struct timespec
{
  time_t tv_sec;
  long tv_nsec;
};
# endif

/* Return negative, zero, positive if A < B, A == B, A > B, respectively.
   Assume the nanosecond components are in range, or close to it.  */
static inline int
timespec_cmp (struct timespec a, struct timespec b)
{
  return (a.tv_sec < b.tv_sec ? -1
	  : a.tv_sec > b.tv_sec ? 1
	  : a.tv_nsec - b.tv_nsec);
}

# if ! HAVE_DECL_NANOSLEEP
/* Don't specify a prototype here.  Some systems (e.g., OSF) declare
   nanosleep with a conflicting one (const-less first parameter).  */
int nanosleep ();
# endif

void gettime (struct timespec *);
int settime (struct timespec const *);

#endif
