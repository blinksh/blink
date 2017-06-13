/* Provide a working getlogin for systems which lack it.

   Copyright (C) 2010-2017 Free Software Foundation, Inc.

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

/* Written by Bruno Haible, 2010.  */

#include "config.h"

/* Specification.  */
#include <unistd.h>

#if (defined _WIN32 || defined __WIN32__) && ! defined __CYGWIN__
# define WIN32_LEAN_AND_MEAN
# include <windows.h>
#endif

char *
getlogin (void)
{
#if (defined _WIN32 || defined __WIN32__) && ! defined __CYGWIN__
  static char login_name[1024];
  DWORD sz = sizeof (login_name);

  if (GetUserName (login_name, &sz))
    return login_name;
#endif
  return NULL;
}
