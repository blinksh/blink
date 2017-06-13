/* declarations for strftime.c

   Copyright (C) 2002, 2004, 2008-2017 Free Software Foundation, Inc.

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

#include "time.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Just like strftime, but with two more arguments:
   POSIX requires that strftime use the local timezone information.
   Use the timezone __TZ instead.  Use __NS as the number of
   nanoseconds in the %N directive.  */
size_t nstrftime (char *, size_t, char const *, struct tm const *,
                  timezone_t __tz, int __ns);

#ifdef __cplusplus
}
#endif
