/* Align/Truncate a string in a given screen width
   Copyright (C) 2009-2017 Free Software Foundation, Inc.

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

#include <stddef.h>

typedef enum { MBS_ALIGN_LEFT, MBS_ALIGN_RIGHT, MBS_ALIGN_CENTER } mbs_align_t;

enum {
  /* Use unibyte mode for invalid multibyte strings
     or when heap memory is exhausted.  */
  MBA_UNIBYTE_FALLBACK = 0x0001,

  /* As an optimization, don't do multibyte processing
     when we know no multibyte characters are present.  */
  MBA_UNIBYTE_ONLY = 0x0002,

  /* Don't add leading padding.  */
  MBA_NO_LEFT_PAD = 0x0004,

  /* Don't add trailing padding.  */
  MBA_NO_RIGHT_PAD = 0x0008

#if 0 /* Other possible options.  */
  /* Skip invalid multibyte chars rather than failing.  */
  MBA_IGNORE_INVALID

  /* Align multibyte strings using "figure space" (\u2007).  */
  MBA_USE_FIGURE_SPACE

  /* Don't truncate.  */
  MBA_NO_TRUNCATE

  /* Ensure no leading whitespace.  */
  MBA_LSTRIP

  /* Ensure no trailing whitespace.  */
  MBA_RSTRIP
#endif
};

size_t
mbsalign (const char *src, char *dest, size_t dest_size,
          size_t *width, mbs_align_t align, int flags);

char *
ambsalign (const char *src, size_t *width, mbs_align_t align, int flags);
