/* long-options.h -- declaration for --help- and --version-handling function.
   Copyright (C) 1993, 1994, 1998, 1999, 2003 Free Software Foundation, Inc.

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

/* Written by Jim Meyering.  */

void parse_long_options (int _argc,
			 char **_argv,
			 const char *_command_name,
			 const char *_package,
			 const char *_version,
			 void (*_usage) (int),
			 /* const char *author1, ...*/ ...);
