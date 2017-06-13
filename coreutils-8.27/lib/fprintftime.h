/* Generate time strings directly to the output.  */

/* Copyright (C) 2005, 2009-2017 Free Software Foundation, Inc.

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

#include <stdio.h>
#include "time.h"

/* A cross between fprintf and nstrftime, that prints directly
   to the output stream, without the need for the potentially
   large buffer that nstrftime would require.

   Output to stream FP the result of formatting (according to the
   nstrftime format string, FMT) the time data, *TM, and the ZONE
   and NANOSECONDS values.  */
size_t fprintftime (FILE *fp, char const *fmt, struct tm const *tm,
                    timezone_t zone, int nanoseconds);
