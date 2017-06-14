/* hard-locale.c -- Determine whether a locale is hard.

   Copyright (C) 1997, 1998, 1999, 2002, 2003, 2004 Free Software
   Foundation, Inc.

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

#ifdef HAVE_CONFIG_H
# include <config.h>
#endif

#include "hard-locale.h"

#include <locale.h>
#include <stdlib.h>
#include <string.h>

#include "strdup.h"

#ifdef __GLIBC__
# define GLIBC_VERSION __GLIBC__
#else
# define GLIBC_VERSION 0
#endif

/* Return true if the current CATEGORY locale is hard, i.e. if you
   can't get away with assuming traditional C or POSIX behavior.  */
bool
hard_locale (int category)
{
  bool hard = true;
  char const *p = setlocale (category, NULL);

  if (p)
    {
      if (2 <= GLIBC_VERSION)
	{
	  if (strcmp (p, "C") == 0 || strcmp (p, "POSIX") == 0)
	    hard = false;
	}
      else
	{
	  char *locale = strdup (p);
	  if (locale)
	    {
	      /* Temporarily set the locale to the "C" and "POSIX" locales
		 to find their names, so that we can determine whether one
		 or the other is the caller's locale.  */
	      if (((p = setlocale (category, "C"))
		   && strcmp (p, locale) == 0)
		  || ((p = setlocale (category, "POSIX"))
		      && strcmp (p, locale) == 0))
		hard = false;

	      /* Restore the caller's locale.  */
	      setlocale (category, locale);
	      free (locale);
	    }
	}
    }

  return hard;
}
