/* readtokens0.c -- Read NUL-separated tokens from an input stream.

   Copyright (C) 2004, 2006, 2009-2017 Free Software Foundation, Inc.

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

#include "config.h"

#include <stdlib.h>

#include "readtokens0.h"

#define obstack_chunk_alloc malloc
#define obstack_chunk_free free

void
readtokens0_init (struct Tokens *t)
{
  t->n_tok = 0;
  t->tok = NULL;
  t->tok_len = NULL;
  obstack_init (&t->o_data);
  obstack_init (&t->o_tok);
  obstack_init (&t->o_tok_len);
}

void
readtokens0_free (struct Tokens *t)
{
  obstack_free (&t->o_data, NULL);
  obstack_free (&t->o_tok, NULL);
  obstack_free (&t->o_tok_len, NULL);
}

/* Finalize (in the obstack_finish sense) the current token
   and record its pointer and length.  */
static void
save_token (struct Tokens *t)
{
  /* Don't count the trailing NUL byte in the length.  */
  size_t len = obstack_object_size (&t->o_data) - 1;
  char const *s = obstack_finish (&t->o_data);
  obstack_ptr_grow (&t->o_tok, s);
  obstack_grow (&t->o_tok_len, &len, sizeof len);
  t->n_tok++;
}

/* Read NUL-separated tokens from stream IN into T until EOF or error.
   The final NUL is optional.  Always append a NULL pointer to the
   resulting list of token pointers, but that pointer isn't counted
   via t->n_tok.  Return true if successful.  */
bool
readtokens0 (FILE *in, struct Tokens *t)
{

  while (1)
    {
      int c = fgetc (in);
      if (c == EOF)
        {
          size_t len = obstack_object_size (&t->o_data);
          /* If the current object has nonzero length, then there
             was no NUL byte at EOF -- or maybe there was an error,
             in which case, we need to append a NUL byte to our buffer.  */
          if (len)
            {
              obstack_1grow (&t->o_data, '\0');
              save_token (t);
            }

          break;
        }

      obstack_1grow (&t->o_data, c);
      if (c == '\0')
        save_token (t);
    }

  /* Add a NULL pointer at the end, in case the caller (like du)
     requires an argv-style array of strings.  */
  obstack_ptr_grow (&t->o_tok, NULL);

  t->tok = obstack_finish (&t->o_tok);
  t->tok_len = obstack_finish (&t->o_tok_len);
  return ! ferror (in);
}
