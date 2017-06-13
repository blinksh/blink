/* readtokens0.h -- read NUL-separated tokens from an input stream.

   Copyright (C) 2004, 2009-2017 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.

   Written by Jim Meyering. */

#ifndef READTOKENS0_H
# define READTOKENS0_H 1

# include <stdio.h>
# include <sys/types.h>
# include <stdbool.h>
# include "obstack.h"

struct Tokens
{
  size_t n_tok;
  char **tok;
  size_t *tok_len;
  struct obstack o_data; /* Contains data pointed to by each tok[i].  */
  struct obstack o_tok; /* array of pointers to tokens  */
  struct obstack o_tok_len; /* array of token lengths  */
};

void readtokens0_init (struct Tokens *t);
void readtokens0_free (struct Tokens *t);
bool readtokens0 (FILE *in, struct Tokens *t);

#endif
