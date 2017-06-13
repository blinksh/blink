/* Compare two memory areas with possibly different lengths.
   Copyright (C) 2009-2017 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published
   by the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

#ifndef MEMCMP2_H
#define MEMCMP2_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif


/* Compare the memory regions S1 = [s1..s1+N1-1], S2 = [s2..s2+n2-1],
   lexicographically.
   This function's result is locale independent, unlike memcoll()'s.
   Return a negative number if S1 < S2, a positive number if S1 > S2, or
   0 if S1 and S2 have the same contents.  */
extern int memcmp2 (const char *s1, size_t n1, const char *s2, size_t n2)
  _GL_ATTRIBUTE_PURE;


#ifdef __cplusplus
}
#endif

#endif /* MEMCMP2_H */
