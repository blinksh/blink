/* prog-fprintf.c - common formating output functions and definitions
   Copyright (C) 2008-2017 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

#include <config.h>
#include <stdarg.h>
#include <sys/types.h>

#include "system.h"

#include "prog-fprintf.h"

/* Display program name followed by variable list.
   Used for e.g. verbose output */
void
prog_fprintf (FILE *fp, char const *fmt, ...)
{
  va_list ap;
  fputs (program_name, fp);
  fputs (": ", fp);
  va_start (ap, fmt);
  vfprintf (fp, fmt, ap);
  va_end (ap);
  fputc ('\n', fp);
  fputc ('\r', fp);
}
