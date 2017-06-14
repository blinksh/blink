/* strdup.h -- duplicate a string
   Copyright (C) 2004 Free Software Foundation, Inc.

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

#ifndef STRDUP_H_
#define STRDUP_H_

/* Get strdup declaration, if available.  */
#include <string.h>

#if defined HAVE_DECL_STRDUP && !HAVE_DECL_STRDUP && !defined strdup
/* Duplicate S, returning an identical malloc'd string.  */
extern char *strdup (const char *s);
#endif

#endif /* STRDUP_H_ */
