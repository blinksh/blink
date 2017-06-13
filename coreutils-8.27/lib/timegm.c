/* Convert UTC calendar time to simple time.  Like mktime but assumes UTC.

   Copyright (C) 1994, 1997, 2003-2004, 2006-2007, 2009-2017 Free Software
   Foundation, Inc.  This file is part of the GNU C Library.

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

#ifndef _LIBC
# include "config.h"
#endif

#include "time.h"

#ifdef _LIBC
typedef time_t mktime_offset_t;
#else
# undef __gmtime_r
# define __gmtime_r gmtime_r
# define __mktime_internal mktime_internal
# include "mktime-internal.h"
#endif

time_t
timegm (struct tm *tmp)
{
  static mktime_offset_t gmtime_offset;
  tmp->tm_isdst = 0;
  return __mktime_internal (tmp, __gmtime_r, &gmtime_offset);
}
