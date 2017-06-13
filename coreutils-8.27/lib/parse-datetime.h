/* Parse a string into an internal timestamp.

   Copyright (C) 1995, 1997-1998, 2003-2004, 2007, 2009-2017 Free Software
   Foundation, Inc.

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

#include <stdbool.h>
#include "time.h"

bool parse_datetime (struct timespec *, char const *, struct timespec const *);

/* parse_datetime2 flag: if set, print debug/progress information to STDERR */
#define PARSE_DATETIME_DEBUG 1

/* same as above, supporting additional flags */
bool parse_datetime2 (struct timespec *, char const *, struct timespec const *,
                      unsigned int flags, timezone_t, char const *);
