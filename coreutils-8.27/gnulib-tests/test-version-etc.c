/* Test suite for version-etc.
   Copyright (C) 2009-2017 Free Software Foundation, Inc.
   This file is part of the GNUlib Library.

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

#include "version-etc.h"


#define AUTHORS "Sergey Poznyakoff", "Eric Blake"

int
main (int argc _GL_UNUSED, char **argv)
{
  version_etc (stdout, "test-version-etc", "dummy", "0", AUTHORS,
               (const char *) NULL);
  return 0;
}
