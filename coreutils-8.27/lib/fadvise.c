/* Declare an access pattern hint for files.
   Copyright (C) 2010-2017 Free Software Foundation, Inc.

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

/* Without this pragma, gcc suggests that (given !HAVE_POSIX_FADVISE)
   the fdadvise function might be a candidate for attribute 'const'.  */
#if (__GNUC__ == 4 && 6 <= __GNUC_MINOR__) || 4 < __GNUC__
# pragma GCC diagnostic ignored "-Wsuggest-attribute=const"
#endif

#include "config.h"
#include "fadvise.h"

#include <stdio.h>
#include <fcntl.h>
#include "ignore-value.h"

void
fdadvise (int fd, off_t offset, off_t len, fadvice_t advice)
{
#if HAVE_POSIX_FADVISE
  ignore_value (posix_fadvise (fd, offset, len, advice));
#endif
}

void
fadvise (FILE *fp, fadvice_t advice)
{
  if (fp)
    fdadvise (fileno (fp), 0, 0, advice);
}
