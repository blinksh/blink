/*
   Copyright (C) 1995 Ian Jackson <iwj10@cus.cam.ac.uk>
   Copyright (C) 2001 Anthony Towns <aj@azure.humbug.org.au>
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
   along with this program.  If not, see <http://www.gnu.org/licenses/>. */

#ifndef FILEVERCMP_H
#define FILEVERCMP_H

/* Compare version strings:

   This function compares strings S1 and S2:
   1) By PREFIX in the same way as strcmp.
   2) Then by VERSION (most similarly to version compare of Debian's dpkg).
      Leading zeros in version numbers are ignored.
   3) If both (PREFIX and  VERSION) are equal, strcmp function is used for
      comparison. So this function can return 0 if (and only if) strings S1
      and S2 are identical.

   It returns number >0 for S1 > S2, 0 for S1 == S2 and number <0 for S1 < S2.

   This function compares strings, in a way that if VER1 and VER2 are version
   numbers and PREFIX and SUFFIX (SUFFIX defined as (\.[A-Za-z~][A-Za-z0-9~]*)*)
   are strings then VER1 < VER2 implies filevercmp (PREFIX VER1 SUFFIX,
   PREFIX VER2 SUFFIX) < 0.

   This function is intended to be a replacement for strverscmp. */
int filevercmp (const char *s1, const char *s2) _GL_ATTRIBUTE_PURE;

#endif /* FILEVERCMP_H */
