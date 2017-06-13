/* getusershell.c -- Return names of valid user shells.

   Copyright (C) 1991, 1997, 2000-2001, 2003-2006, 2008-2017 Free Software
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
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* Written by David MacKenzie <djm@gnu.ai.mit.edu> */

#include "config.h"

/* Specification.  */
#include <unistd.h>

#ifndef SHELLS_FILE
# ifndef __DJGPP__
/* File containing a list of nonrestricted shells, one per line. */
#  define SHELLS_FILE "/etc/shells"
# else
/* This is a horrible kludge.  Isn't there a better way?  */
#  define SHELLS_FILE "/dev/env/DJDIR/etc/shells"
# endif
#endif

#include <stdlib.h>
#include <ctype.h>

#include "stdio--.h"
#include "xalloc.h"

#if USE_UNLOCKED_IO
# include "unlocked-io.h"
#endif

static size_t readname (char **, size_t *, FILE *);

#if ! defined ADDITIONAL_DEFAULT_SHELLS && defined __MSDOS__
# define ADDITIONAL_DEFAULT_SHELLS \
  "c:/dos/command.com", "c:/windows/command.com", "c:/command.com",
#else
# define ADDITIONAL_DEFAULT_SHELLS /* empty */
#endif

/* List of shells to use if the shells file is missing. */
static char const* const default_shells[] =
{
  ADDITIONAL_DEFAULT_SHELLS
  "/bin/sh", "/bin/csh", "/usr/bin/sh", "/usr/bin/csh", NULL
};

/* Index of the next shell in 'default_shells' to return.
   0 means we are not using 'default_shells'. */
static size_t default_index = 0;

/* Input stream from the shells file. */
static FILE *shellstream = NULL;

/* Line of input from the shells file. */
static char *line = NULL;

/* Number of bytes allocated for 'line'. */
static size_t line_size = 0;

/* Return an entry from the shells file, ignoring comment lines.
   If the file doesn't exist, use the list in DEFAULT_SHELLS (above).
   In any case, the returned string is in memory allocated through malloc.
   Return NULL if there are no more entries.  */

char *
getusershell (void)
{
  if (default_index > 0)
    {
      if (default_shells[default_index])
        /* Not at the end of the list yet.  */
        return xstrdup (default_shells[default_index++]);
      return NULL;
    }

  if (shellstream == NULL)
    {
      shellstream = fopen (SHELLS_FILE, "r");
      if (shellstream == NULL)
        {
          /* No shells file.  Use the default list.  */
          default_index = 1;
          return xstrdup (default_shells[0]);
        }
    }

  while (readname (&line, &line_size, shellstream))
    {
      if (*line != '#')
        return line;
    }
  return NULL;                  /* End of file. */
}

/* Rewind the shells file. */

void
setusershell (void)
{
  default_index = 0;
  if (shellstream)
    rewind (shellstream);
}

/* Close the shells file. */

void
endusershell (void)
{
  if (shellstream)
    {
      fclose (shellstream);
      shellstream = NULL;
    }
}

/* Read a line from STREAM, removing any newline at the end.
   Place the result in *NAME, which is malloc'd
   and/or realloc'd as necessary and can start out NULL,
   and whose size is passed and returned in *SIZE.

   Return the number of bytes placed in *NAME
   if some nonempty sequence was found, otherwise 0.  */

static size_t
readname (char **name, size_t *size, FILE *stream)
{
  int c;
  size_t name_index = 0;

  /* Skip blank space.  */
  while ((c = getc (stream)) != EOF && isspace (c))
    /* Do nothing. */ ;

  for (;;)
    {
      if (*size <= name_index)
        *name = x2nrealloc (*name, size, sizeof **name);
      if (c == EOF || isspace (c))
        break;
      (*name)[name_index++] = c;
      c = getc (stream);
    }
  (*name)[name_index] = '\0';
  return name_index;
}

#ifdef TEST
int
main (void)
{
  char *s;

  while (s = getusershell ())
    puts (s);
  exit (0);
}
#endif
