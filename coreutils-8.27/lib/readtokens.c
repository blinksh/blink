/* readtokens.c  -- Functions for reading tokens from an input stream.

   Copyright (C) 1990-1991, 1999-2004, 2006, 2009-2017 Free Software
   Foundation, Inc.

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

/* This almost supersedes xreadline stuff -- using delim="\n"
   gives the same functionality, except that these functions
   would never return empty lines. */

#include "config.h"

#include "readtokens.h"

#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

#include "xalloc.h"

#if USE_UNLOCKED_IO
# include "unlocked-io.h"
#endif

/* Initialize a tokenbuffer. */

void
init_tokenbuffer (token_buffer *tokenbuffer)
{
  tokenbuffer->size = 0;
  tokenbuffer->buffer = NULL;
}

typedef size_t word;
enum { bits_per_word = sizeof (word) * CHAR_BIT };

static bool
get_nth_bit (size_t n, word const *bitset)
{
  return bitset[n / bits_per_word] >> n % bits_per_word & 1;
}

static void
set_nth_bit (size_t n, word *bitset)
{
  size_t one = 1;
  bitset[n / bits_per_word] |= one << n % bits_per_word;
}

/* Read a token from STREAM into TOKENBUFFER.
   A token is delimited by any of the N_DELIM bytes in DELIM.
   Upon return, the token is in tokenbuffer->buffer and
   has a trailing '\0' instead of any original delimiter.
   The function value is the length of the token not including
   the final '\0'.  Upon EOF (i.e. on the call after the last
   token is read) or error, return -1 without modifying tokenbuffer.
   The EOF and error conditions may be distinguished in the caller
   by testing ferror (STREAM).

   This function works properly on lines containing NUL bytes
   and on files that do not end with a delimiter.  */

size_t
readtoken (FILE *stream,
           const char *delim,
           size_t n_delim,
           token_buffer *tokenbuffer)
{
  char *p;
  int c;
  size_t i, n;
  word isdelim[(UCHAR_MAX + bits_per_word) / bits_per_word];

  memset (isdelim, 0, sizeof isdelim);
  for (i = 0; i < n_delim; i++)
    {
      unsigned char ch = delim[i];
      set_nth_bit (ch, isdelim);
    }

  /* skip over any leading delimiters */
  for (c = getc (stream); c >= 0 && get_nth_bit (c, isdelim); c = getc (stream))
    {
      /* empty */
    }

  p = tokenbuffer->buffer;
  n = tokenbuffer->size;
  i = 0;
  for (;;)
    {
      if (c < 0 && i == 0)
        return -1;

      if (i == n)
        p = x2nrealloc (p, &n, sizeof *p);

      if (c < 0)
        {
          p[i] = 0;
          break;
        }
      if (get_nth_bit (c, isdelim))
        {
          p[i] = 0;
          break;
        }
      p[i++] = c;
      c = getc (stream);
    }

  tokenbuffer->buffer = p;
  tokenbuffer->size = n;
  return i;
}

/* Build a NULL-terminated array of pointers to tokens
   read from STREAM.  Return the number of tokens read.
   All storage is obtained through calls to xmalloc-like functions.

   %%% Question: is it worth it to do a single
   %%% realloc() of 'tokens' just before returning? */

size_t
readtokens (FILE *stream,
            size_t projected_n_tokens,
            const char *delim,
            size_t n_delim,
            char ***tokens_out,
            size_t **token_lengths)
{
  token_buffer tb, *token = &tb;
  char **tokens;
  size_t *lengths;
  size_t sz;
  size_t n_tokens;

  if (projected_n_tokens == 0)
    projected_n_tokens = 64;
  else
    projected_n_tokens++;       /* add one for trailing NULL pointer */

  sz = projected_n_tokens;
  tokens = xnmalloc (sz, sizeof *tokens);
  lengths = xnmalloc (sz, sizeof *lengths);

  n_tokens = 0;
  init_tokenbuffer (token);
  for (;;)
    {
      char *tmp;
      size_t token_length = readtoken (stream, delim, n_delim, token);
      if (n_tokens >= sz)
        {
          tokens = x2nrealloc (tokens, &sz, sizeof *tokens);
          lengths = xnrealloc (lengths, sz, sizeof *lengths);
        }

      if (token_length == (size_t) -1)
        {
          /* don't increment n_tokens for NULL entry */
          tokens[n_tokens] = NULL;
          lengths[n_tokens] = 0;
          break;
        }
      tmp = xnmalloc (token_length + 1, sizeof *tmp);
      lengths[n_tokens] = token_length;
      tokens[n_tokens] = memcpy (tmp, token->buffer, token_length + 1);
      n_tokens++;
    }

  free (token->buffer);
  *tokens_out = tokens;
  if (token_lengths != NULL)
    *token_lengths = lengths;
  else
    free (lengths);
  return n_tokens;
}
