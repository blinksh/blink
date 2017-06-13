/* pwd - print current directory
   Copyright (C) 1994-2017 Free Software Foundation, Inc.

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

#include <config.h>
#include <getopt.h>
#include <stdio.h>
#include <sys/types.h>

#include "system.h"
#include "die.h"
#include "error.h"
#include "quote.h"
#include "root-dev-ino.h"
#include "xgetcwd.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "pwd"

#undef usage
#define usage pwd_usage
static void pwd_usage (int status);


#define AUTHORS proper_name ("Jim Meyering")

struct file_name
{
  char *buf;
  size_t n_alloc;
  char *start;
};

static struct option const longopts[] =
{
  {"logical", no_argument, NULL, 'L'},
  {"physical", no_argument, NULL, 'P'},
  {GETOPT_HELP_OPTION_DECL},
  {GETOPT_VERSION_OPTION_DECL},
  {NULL, 0, NULL, 0}
};

void
pwd_usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("Usage: %s [OPTION]...\n\r"), program_name);
      fputs (_("\
Print the full filename of the current working directory.\n\r\
\n\r\
"), stdout);
      fputs (_("\
  -L, --logical   use PWD from environment, even if it contains symlinks\n\r\
  -P, --physical  avoid all symlinks\n\r\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      fputs (_("\n\r\
If no option is specified, -P is assumed.\n\r\
"), stdout);
      printf (USAGE_BUILTIN_WARNING, PROGRAM_NAME);
      emit_ancillary_info (PROGRAM_NAME);
    }
  // exit (status);
}

static void
file_name_free (struct file_name *p)
{
  free (p->buf);
  free (p);
}

static struct file_name *
file_name_init (void)
{
  struct file_name *p = xmalloc (sizeof *p);

  /* Start with a buffer larger than PATH_MAX, but beware of systems
     on which PATH_MAX is very large -- e.g., INT_MAX.  */
  p->n_alloc = MIN (2 * PATH_MAX, 32 * 1024);

  p->buf = xmalloc (p->n_alloc);
  p->start = p->buf + (p->n_alloc - 1);
  p->start[0] = '\0';
  return p;
}

/* Prepend the name S of length S_LEN, to the growing file_name, P.  */
static void
file_name_prepend (struct file_name *p, char const *s, size_t s_len)
{
  size_t n_free = p->start - p->buf;
  if (n_free < 1 + s_len)
    {
      size_t half = p->n_alloc + 1 + s_len;
      /* Use xnmalloc+free rather than xnrealloc, since with the latter
         we'd end up copying the data twice: once via realloc, then again
         to align it with the end of the new buffer.  With xnmalloc, we
         copy it only once.  */
      char *q = xnmalloc (2, half);
      size_t n_used = p->n_alloc - n_free;
      p->start = q + 2 * half - n_used;
      memcpy (p->start, p->buf + n_free, n_used);
      free (p->buf);
      p->buf = q;
      p->n_alloc = 2 * half;
    }

  p->start -= 1 + s_len;
  p->start[0] = '/';
  memcpy (p->start + 1, s, s_len);
}

/* Return a string (malloc'd) consisting of N '/'-separated ".." components.  */
static char *
nth_parent (size_t n)
{
  char *buf = xnmalloc (3, n);
  char *p = buf;
  size_t i;

  for (i = 0; i < n; i++)
    {
      memcpy (p, "../", 3);
      p += 3;
    }
  p[-1] = '\0';
  return buf;
}

/* Determine the basename of the current directory, where DOT_SB is the
   result of lstat'ing "." and prepend that to the file name in *FILE_NAME.
   Find the directory entry in '..' that matches the dev/i-node of DOT_SB.
   Upon success, update *DOT_SB with stat information of '..', chdir to '..',
   and prepend "/basename" to FILE_NAME.
   Otherwise, exit with a diagnostic.
   PARENT_HEIGHT is the number of levels '..' is above the starting directory.
   The first time this function is called (from the initial directory),
   PARENT_HEIGHT is 1.  This is solely for diagnostics.
   Exit nonzero upon error.  */

static void
find_dir_entry (struct stat *dot_sb, struct file_name *file_name,
                size_t parent_height)
{
  DIR *dirp;
  int fd;
  struct stat parent_sb;
  bool use_lstat;
  bool found;

  dirp = opendir ("..");
  if (dirp == NULL)
    die (EXIT_FAILURE, errno, _("cannot open directory %s"),
         quote (nth_parent (parent_height)));

  fd = dirfd (dirp);
  if ((0 <= fd ? fchdir (fd) : chdir ("..")) < 0)
    die (EXIT_FAILURE, errno, _("failed to chdir to %s"),
         quote (nth_parent (parent_height)));

  if ((0 <= fd ? fstat (fd, &parent_sb) : stat (".", &parent_sb)) < 0)
    die (EXIT_FAILURE, errno, _("failed to stat %s"),
         quote (nth_parent (parent_height)));

  /* If parent and child directory are on different devices, then we
     can't rely on d_ino for useful i-node numbers; use lstat instead.  */
  use_lstat = (parent_sb.st_dev != dot_sb->st_dev);

  found = false;
  while (1)
    {
      struct dirent const *dp;
      struct stat ent_sb;
      ino_t ino;

      errno = 0;
      if ((dp = readdir_ignoring_dot_and_dotdot (dirp)) == NULL)
        {
          if (errno)
            {
              /* Save/restore errno across closedir call.  */
              int e = errno;
              closedir (dirp);
              errno = e;

              /* Arrange to give a diagnostic after exiting this loop.  */
              dirp = NULL;
            }
          break;
        }

      ino = D_INO (dp);

      if (ino == NOT_AN_INODE_NUMBER || use_lstat)
        {
          if (lstat (dp->d_name, &ent_sb) < 0)
            {
              /* Skip any entry we can't stat.  */
              continue;
            }
          ino = ent_sb.st_ino;
        }

      if (ino != dot_sb->st_ino)
        continue;

      /* If we're not crossing a device boundary, then a simple i-node
         match is enough.  */
      if ( ! use_lstat || ent_sb.st_dev == dot_sb->st_dev)
        {
          file_name_prepend (file_name, dp->d_name, _D_EXACT_NAMLEN (dp));
          found = true;
          break;
        }
    }

  if (dirp == NULL || closedir (dirp) != 0)
    {
      /* Note that this diagnostic serves for both readdir
         and closedir failures.  */
      die (EXIT_FAILURE, errno, _("reading directory %s"),
           quote (nth_parent (parent_height)));
    }

  if ( ! found)
    die (EXIT_FAILURE, 0,
         _("couldn't find directory entry in %s with matching i-node"),
         quote (nth_parent (parent_height)));

  *dot_sb = parent_sb;
}

/* Construct the full, absolute name of the current working
   directory and store it in *FILE_NAME.
   The getcwd function performs nearly the same task, but is typically
   unable to handle names longer than PATH_MAX.  This function has
   no such limitation.  However, this function *can* fail due to
   permission problems or a lack of memory, while GNU/Linux's getcwd
   function works regardless of restricted permissions on parent
   directories.  Upon failure, give a diagnostic and exit nonzero.

   Note: although this function is similar to getcwd, it has a fundamental
   difference in that it gives a diagnostic and exits upon failure.
   I would have liked a function that did not exit, and that could be
   used as a getcwd replacement.  Unfortunately, considering all of
   the information the caller would require in order to produce good
   diagnostics, it doesn't seem worth the added complexity.
   In any case, any getcwd replacement must *not* exceed the PATH_MAX
   limitation.  Otherwise, functions like 'chdir' would fail with
   ENAMETOOLONG.

   FIXME-maybe: if find_dir_entry fails due to permissions, try getcwd,
   in case the unreadable directory is close enough to the root that
   getcwd works from there.  */

static void
robust_getcwd (struct file_name *file_name)
{
  size_t height = 1;
  struct dev_ino dev_ino_buf;
  struct dev_ino *root_dev_ino = get_root_dev_ino (&dev_ino_buf);
  struct stat dot_sb;

  if (root_dev_ino == NULL)
    die (EXIT_FAILURE, errno, _("failed to get attributes of %s"),
         quoteaf ("/"));

  if (stat (".", &dot_sb) < 0)
    die (EXIT_FAILURE, errno, _("failed to stat %s"), quoteaf ("."));

  while (1)
    {
      /* If we've reached the root, we're done.  */
      if (SAME_INODE (dot_sb, *root_dev_ino))
        break;

      find_dir_entry (&dot_sb, file_name, height++);
    }

  /* See if a leading slash is needed; file_name_prepend adds one.  */
  if (file_name->start[0] == '\0')
    file_name_prepend (file_name, "", 0);
}


/* Return PWD from the environment if it is acceptable for 'pwd -L'
   output, otherwise NULL.  */
static char *
logical_getcwd (void)
{
  struct stat st1;
  struct stat st2;
  char *wd = getenv ("PWD");
  char *p;

  /* Textual validation first.  */
  if (!wd || wd[0] != '/')
    return NULL;
  p = wd;
  while ((p = strstr (p, "/.")))
    {
      if (!p[2] || p[2] == '/'
          || (p[2] == '.' && (!p[3] || p[3] == '/')))
        return NULL;
      p++;
    }

  /* System call validation.  */
  if (stat (wd, &st1) == 0 && stat (".", &st2) == 0 && SAME_INODE (st1, st2))
    return wd;
  return NULL;
}


int
pwd_main (int argc, char **argv)
{
  char *wd;
  /* POSIX requires a default of -L, but most scripts expect -P.
     Currently shells default to -L, while stand-alone
     pwd implementations default to -P.  */
  bool logical = (getenv ("POSIXLY_CORRECT") != NULL);

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdout);

  while (1)
    {
      int c = getopt_long (argc, argv, "LP", longopts, NULL);
      if (c == -1)
        break;
      switch (c)
        {
        case 'L':
          logical = true;
          break;
        case 'P':
          logical = false;
          break;

        case_GETOPT_HELP_CHAR;

        case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);

        default:
          pwd_usage (EXIT_FAILURE);
          return EXIT_FAILURE;
        }
    }

  if (optind < argc)
    error (0, 0, _("ignoring non-option arguments"));

  if (logical)
    {
      wd = logical_getcwd ();
      if (wd)
        {
          puts (wd);
          puts ("\r");
          return EXIT_SUCCESS;
        }
    }

  wd = xgetcwd ();
  if (wd != NULL)
    {
      puts (wd);
      puts ("\r");
      free (wd);
    }
  else
    {
      struct file_name *file_name = file_name_init ();
      robust_getcwd (file_name);
      puts (file_name->start);
      puts ("\r");
      file_name_free (file_name);
    }

  return EXIT_SUCCESS;
}
