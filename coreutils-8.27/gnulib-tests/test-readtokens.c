/* Test the readtokens module.
   Copyright (C) 2012-2017 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

#include <config.h>
#include <stdbool.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>

#include "readtokens.h"
#include "closeout.h"
#include "macros.h"

static void
basic (void)
{
  char const *filename = "in.827";
  int fd = open (filename, O_CREAT | O_WRONLY, 0600);
  ASSERT (fd >= 0);
  ASSERT (write (fd, "a|b;c+d", 7) == 7);
  ASSERT (close (fd) == 0);

  {
    token_buffer tb;
    FILE *fp = fopen (filename, "r");
    ASSERT (fp);

    init_tokenbuffer (&tb);
    ASSERT (readtoken (fp, "|;", 2, &tb)  == 1 && tb.buffer[0] == 'a');
    ASSERT (readtoken (fp, "|;", 2, &tb) == 1 && tb.buffer[0] == 'b');
    ASSERT (readtoken (fp, "+", 1, &tb)  == 1 && tb.buffer[0] == 'c');
    ASSERT (readtoken (fp, "-", 1, &tb) == 1 && tb.buffer[0] == 'd');
    ASSERT (readtoken (fp, "%", 0, &tb) == (size_t) -1);
    ASSERT ( ! ferror (fp));
    ASSERT (fclose (fp) == 0);
  }
}

int
main (int argc, char **argv)
{
  token_buffer tb;
  char const *delim;
  size_t delim_len;

  atexit (close_stdout);

  if (argc == 1)
    {
      basic ();
      return 0;
    }

  init_tokenbuffer (&tb);

  if (argc != 2)
    return 99;

  delim = argv[1];
  delim_len = strlen (delim);

  if (STREQ (delim, "\\0"))
    {
      delim = "";
      delim_len = 1;
    }

  while (1)
    {
      size_t token_length = readtoken (stdin, delim, delim_len, &tb);
      if (token_length == (size_t) -1)
        break;
      fwrite (tb.buffer, 1, token_length, stdout);
      putchar (':');
    }
  putchar ('\n');
  free (tb.buffer);

  ASSERT ( ! ferror (stdin));

  return 0;
}
