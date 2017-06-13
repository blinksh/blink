/* Test of <sys/resource.h> substitute.
   Copyright (C) 2012-2017 Free Software Foundation, Inc.

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

#include <config.h>

#include <sys/resource.h>

/* Check that necessary types are defined.  */
#ifdef TODO /* Not implemented in gnulib yet */
rlim_t t1;
struct rlimit t2;
#endif
struct rusage t3;
#ifdef TODO
struct timeval t4;
id_t t5;
time_t t10;
suseconds_t t11;
fd_set t12;
#endif

/* Check that the necessary constants are defined.  */
#ifdef TODO /* Not implemented in gnulib yet */
int prios[] =
  {
    PRIO_PROCESS,
    PRIO_PGRP,
    PRIO_USER
  };
int rlims[] =
  {
    RLIM_INFINITY,
    RLIM_SAVED_MAX,
    RLIM_SAVED_CUR
  };
#endif
int rusages[] =
  {
    RUSAGE_SELF,
    RUSAGE_CHILDREN
  };
#ifdef TODO
int rlimits[] =
  {
    RLIMIT_CORE,
    RLIMIT_CPU,
    RLIMIT_DATA,
    RLIMIT_FSIZE,
    RLIMIT_NOFILE,
    RLIMIT_STACK,
    RLIMIT_AS
  };
#endif

int
main (void)
{
  return 0;
}
