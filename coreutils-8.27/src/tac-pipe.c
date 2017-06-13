/* tac from a pipe.

   Copyright (C) 1997-2017 Free Software Foundation, Inc.

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

/* FIXME */
#include <assert.h>

#include "die.h"

/* FIXME: this is small for testing */
#define BUFFER_SIZE (8)

#define LEN(X, I) ((X)->p[(I)].one_past_end - (X)->p[(I)].start)
#define EMPTY(X) ((X)->n_bufs == 1 && LEN (X, 0) == 0)

#define ONE_PAST_END(X, I) ((X)->p[(I)].one_past_end)

struct Line_ptr
{
  size_t i;
  char *ptr;
};
typedef struct Line_ptr Line_ptr;

struct B_pair
{
  char *start;
  char *one_past_end;
};

struct Buf
{
  size_t n_bufs;
  struct obstack obs;
  struct B_pair *p;
};
typedef struct Buf Buf;

static bool
buf_init_from_stdin (Buf *x, char eol_byte)
{
  bool last_byte_is_eol_byte = true;
  bool ok = true;

#define OBS (&(x->obs))
  obstack_init (OBS);

  while (1)
    {
      char *buf = (char *) malloc (BUFFER_SIZE);
      size_t bytes_read;

      if (buf == NULL)
        {
          /* Fall back on the code that relies on a temporary file.
             Write all buffers to that file and free them.  */
          /* FIXME */
          ok = false;
          break;
        }
      bytes_read = full_read (STDIN_FILENO, buf, BUFFER_SIZE);
      if (bytes_read != buffer_size && errno != 0)
        die (EXIT_FAILURE, errno, _("read error"));

      {
        struct B_pair bp;
        bp.start = buf;
        bp.one_past_end = buf + bytes_read;
        obstack_grow (OBS, &bp, sizeof (bp));
      }

      if (bytes_read != 0)
        last_byte_is_eol_byte = (buf[bytes_read - 1] == eol_byte);

      if (bytes_read < BUFFER_SIZE)
        break;
    }

  if (ok)
    {
      /* If the file was non-empty and lacked an EOL_BYTE at its end,
         then add a buffer containing just that one byte.  */
      if (!last_byte_is_eol_byte)
        {
          char *buf = malloc (1);
          if (buf == NULL)
            {
              /* FIXME: just like above */
              ok = false;
            }
          else
            {
              struct B_pair bp;
              *buf = eol_byte;
              bp.start = buf;
              bp.one_past_end = buf + 1;
              obstack_grow (OBS, &bp, sizeof (bp));
            }
        }
    }

  x->n_bufs = obstack_object_size (OBS) / sizeof (x->p[0]);
  x->p = (struct B_pair *) obstack_finish (OBS);

  /* If there are two or more buffers and the last buffer is empty,
     then free the last one and decrement the buffer count.  */
  if (x->n_bufs >= 2
      && x->p[x->n_bufs - 1].start == x->p[x->n_bufs - 1].one_past_end)
    free (x->p[--(x->n_bufs)].start);

  return ok;
}

static void
buf_free (Buf *x)
{
  size_t i;
  for (i = 0; i < x->n_bufs; i++)
    free (x->p[i].start);
  obstack_free (OBS, NULL);
}

Line_ptr
line_ptr_decrement (const Buf *x, const Line_ptr *lp)
{
  Line_ptr lp_new;

  if (lp->ptr > x->p[lp->i].start)
    {
      lp_new.i = lp->i;
      lp_new.ptr = lp->ptr - 1;
    }
  else
    {
      assert (lp->i > 0);
      lp_new.i = lp->i - 1;
      lp_new.ptr = ONE_PAST_END (x, lp->i - 1) - 1;
    }
  return lp_new;
}

Line_ptr
line_ptr_increment (const Buf *x, const Line_ptr *lp)
{
  Line_ptr lp_new;

  assert (lp->ptr <= ONE_PAST_END (x, lp->i) - 1);
  if (lp->ptr < ONE_PAST_END (x, lp->i) - 1)
    {
      lp_new.i = lp->i;
      lp_new.ptr = lp->ptr + 1;
    }
  else
    {
      assert (lp->i < x->n_bufs - 1);
      lp_new.i = lp->i + 1;
      lp_new.ptr = x->p[lp->i + 1].start;
    }
  return lp_new;
}

static bool
find_bol (const Buf *x,
          const Line_ptr *last_bol, Line_ptr *new_bol, char eol_byte)
{
  size_t i;
  Line_ptr tmp;
  char *last_bol_ptr;

  if (last_bol->ptr == x->p[0].start)
    return false;

  tmp = line_ptr_decrement (x, last_bol);
  last_bol_ptr = tmp.ptr;
  i = tmp.i;
  while (1)
    {
      char *nl = memrchr (x->p[i].start, last_bol_ptr, eol_byte);
      if (nl)
        {
          Line_ptr nl_pos;
          nl_pos.i = i;
          nl_pos.ptr = nl;
          *new_bol = line_ptr_increment (x, &nl_pos);
          return true;
        }

      if (i == 0)
        break;

      --i;
      last_bol_ptr = ONE_PAST_END (x, i);
    }

  /* If last_bol->ptr didn't point at the first byte of X, then reaching
     this point means that we're about to return the line that is at the
     beginning of X.  */
  if (last_bol->ptr != x->p[0].start)
    {
      new_bol->i = 0;
      new_bol->ptr = x->p[0].start;
      return true;
    }

  return false;
}

static void
print_line (FILE *out_stream, const Buf *x,
            const Line_ptr *bol, const Line_ptr *bol_next)
{
  size_t i;
  for (i = bol->i; i <= bol_next->i; i++)
    {
      char *a = (i == bol->i ? bol->ptr : x->p[i].start);
      char *b = (i == bol_next->i ? bol_next->ptr : ONE_PAST_END (x, i));
      fwrite (a, 1, b - a, out_stream);
    }
}

static bool
tac_mem ()
{
  Buf x;
  Line_ptr bol;
  char eol_byte = '\n';

  if (! buf_init_from_stdin (&x, eol_byte))
    {
      buf_free (&x);
      return false;
    }

  /* Special case the empty file.  */
  if (EMPTY (&x))
    return true;

  /* Initially, point at one past the last byte of the file.  */
  bol.i = x.n_bufs - 1;
  bol.ptr = ONE_PAST_END (&x, bol.i);

  while (1)
    {
      Line_ptr new_bol;
      if (! find_bol (&x, &bol, &new_bol, eol_byte))
        break;
      print_line (stdout, &x, &new_bol, &bol);
      bol = new_bol;
    }
  return true;
}
