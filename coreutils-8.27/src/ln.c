/* 'ln' program to create links between files.
   Copyright (C) 1986-2017 Free Software Foundation, Inc.

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

/* Written by Mike Parker and David MacKenzie. */

#include <config.h>
#include <stdio.h>
#include <sys/types.h>
#include <getopt.h>

#include "system.h"
#include "backupfile.h"
#include "die.h"
#include "error.h"
#include "filenamecat.h"
#include "file-set.h"
#include "force-link.h"
#include "hash.h"
#include "hash-triple.h"
#include "relpath.h"
#include "same.h"
#include "yesno.h"
#include "canonicalize.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "ln"

#undef usage
#define usage ln_usage
static void ln_usage (int status);

#define AUTHORS \
  proper_name ("Mike Parker"), \
  proper_name ("David MacKenzie")

/* FIXME: document */
static enum backup_type backup_type;

/* If true, make symbolic links; otherwise, make hard links.  */
static bool symbolic_link;

/* If true, make symbolic links relative  */
static bool relative;

/* If true, hard links are logical rather than physical.  */
static bool logical = !!LINK_FOLLOWS_SYMLINKS;

/* If true, ask the user before removing existing files.  */
static bool interactive;

/* If true, remove existing files unconditionally.  */
static bool remove_existing_files;

/* If true, list each file as it is moved. */
static bool verbose;

/* If true, allow the superuser to *attempt* to make hard links
   to directories.  However, it appears that this option is not useful
   in practice, since even the superuser is prohibited from hard-linking
   directories on most existing systems (Solaris being an exception).  */
static bool hard_dir_link;

/* If nonzero, and the specified destination is a symbolic link to a
   directory, treat it just as if it were a directory.  Otherwise, the
   command 'ln --force --no-dereference file symlink-to-dir' deletes
   symlink-to-dir before creating the new link.  */
static bool dereference_dest_dir_symlinks = true;

/* This is a set of destination name/inode/dev triples for hard links
   created by ln.  Use this data structure to avoid data loss via a
   sequence of commands like this:
   rm -rf a b c; mkdir a b c; touch a/f b/f; ln -f a/f b/f c && rm -r a b */
static Hash_table *dest_set;

/* Initial size of the dest_set hash table.  */
enum { DEST_INFO_INITIAL_CAPACITY = 61 };

static struct option const long_options[] =
{
  {"backup", optional_argument, NULL, 'b'},
  {"directory", no_argument, NULL, 'F'},
  {"no-dereference", no_argument, NULL, 'n'},
  {"no-target-directory", no_argument, NULL, 'T'},
  {"force", no_argument, NULL, 'f'},
  {"interactive", no_argument, NULL, 'i'},
  {"suffix", required_argument, NULL, 'S'},
  {"target-directory", required_argument, NULL, 't'},
  {"logical", no_argument, NULL, 'L'},
  {"physical", no_argument, NULL, 'P'},
  {"relative", no_argument, NULL, 'r'},
  {"symbolic", no_argument, NULL, 's'},
  {"verbose", no_argument, NULL, 'v'},
  {GETOPT_HELP_OPTION_DECL},
  {GETOPT_VERSION_OPTION_DECL},
  {NULL, 0, NULL, 0}
};

/* Return true when the passed ERR implies
   that a file does not or could not exist.  */

static bool
errno_nonexisting (int err)
{
  return err == ENOENT || err == ENAMETOOLONG || err == ENOTDIR || err == ELOOP;
}


/* FILE is the last operand of this command.  Return true if FILE is a
   directory.  But report an error if there is a problem accessing FILE,
   or if FILE does not exist but would have to refer to an existing
   directory if it referred to anything at all.  */

static bool
target_directory_operand (char const *file)
{
  char const *b = last_component (file);
  size_t blen = strlen (b);
  bool looks_like_a_dir = (blen == 0 || ISSLASH (b[blen - 1]));
  struct stat st;
  int stat_result =
    (dereference_dest_dir_symlinks ? stat (file, &st) : lstat (file, &st));
  int err = (stat_result == 0 ? 0 : errno);
  bool is_a_dir = !err && S_ISDIR (st.st_mode);
  if (err && ! errno_nonexisting (errno))
    die (EXIT_FAILURE, err, _("failed to access %s"), quoteaf (file));
  if (is_a_dir < looks_like_a_dir)
    die (EXIT_FAILURE, err, _("target %s is not a directory"),
         quoteaf (file));
  return is_a_dir;
}

/* Return FROM represented as relative to the dir of TARGET.
   The result is malloced.  */

static char *
convert_abs_rel (const char *from, const char *target)
{
  /* Get dirname to generate paths relative to.  We don't resolve
     the full TARGET as the last component could be an existing symlink.  */
  char *targetdir = dir_name (target);

  char *realdest = canonicalize_filename_mode (targetdir, CAN_MISSING);
  char *realfrom = canonicalize_filename_mode (from, CAN_MISSING);

  char *relative_from = NULL;
  if (realdest && realfrom)
    {
      /* Write to a PATH_MAX buffer.  */
      relative_from = xmalloc (PATH_MAX);

      if (!relpath (realfrom, realdest, relative_from, PATH_MAX))
        {
          free (relative_from);
          relative_from = NULL;
        }
    }

  free (targetdir);
  free (realdest);
  free (realfrom);

  return relative_from ? relative_from : xstrdup (from);
}

/* Make a link DEST to the (usually) existing file SOURCE.
   Symbolic links to nonexistent files are allowed.
   Return true if successful.  */

static bool
do_link (const char *source, const char *dest)
{
  struct stat source_stats;
  struct stat dest_stats;
  char *dest_backup = NULL;
  char *rel_source = NULL;
  bool dest_lstat_ok = false;
  bool source_is_dir = false;

  if (!symbolic_link)
    {
       /* Which stat to use depends on whether linkat will follow the
          symlink.  We can't use the shorter
          (logical?stat:lstat) (source, &source_stats)
          since stat might be a function-like macro.  */
      if ((logical ? stat (source, &source_stats)
           : lstat (source, &source_stats))
          != 0)
        {
          error (0, errno, _("failed to access %s"), quoteaf (source));
          return false;
        }

      if (S_ISDIR (source_stats.st_mode))
        {
          source_is_dir = true;
          if (! hard_dir_link)
            {
              error (0, 0, _("%s: hard link not allowed for directory"),
                     quotef (source));
              return false;
            }
        }
    }

  if (remove_existing_files || interactive || backup_type != no_backups)
    {
      dest_lstat_ok = (lstat (dest, &dest_stats) == 0);
      if (!dest_lstat_ok && errno != ENOENT)
        {
          error (0, errno, _("failed to access %s"), quoteaf (dest));
          return false;
        }
    }

  /* If the current target was created as a hard link to another
     source file, then refuse to unlink it.  */
  if (dest_lstat_ok
      && dest_set != NULL
      && seen_file (dest_set, dest, &dest_stats))
    {
      error (0, 0,
             _("will not overwrite just-created %s with %s"),
             quoteaf_n (0, dest), quoteaf_n (1, source));
      return false;
    }

  /* If --force (-f) has been specified without --backup, then before
     making a link ln must remove the destination file if it exists.
     (with --backup, it just renames any existing destination file)
     But if the source and destination are the same, don't remove
     anything and fail right here.  */
  if ((remove_existing_files
       /* Ensure that "ln --backup f f" fails here, with the
          "... same file" diagnostic, below.  Otherwise, subsequent
          code would give a misleading "file not found" diagnostic.
          This case is different than the others handled here, since
          the command in question doesn't use --force.  */
       || (!symbolic_link && backup_type != no_backups))
      && dest_lstat_ok
      /* Allow 'ln -sf --backup k k' to succeed in creating the
         self-referential symlink, but don't allow the hard-linking
         equivalent: 'ln -f k k' (with or without --backup) to get
         beyond this point, because the error message you'd get is
         misleading.  */
      && (backup_type == no_backups || !symbolic_link)
      && (!symbolic_link || stat (source, &source_stats) == 0)
      && SAME_INODE (source_stats, dest_stats)
      /* The following detects whether removing DEST will also remove
         SOURCE.  If the file has only one link then both are surely
         the same link.  Otherwise check whether they point to the same
         name in the same directory.  */
      && (source_stats.st_nlink == 1 || same_name (source, dest)))
    {
      error (0, 0, _("%s and %s are the same file"),
             quoteaf_n (0, source), quoteaf_n (1, dest));
      return false;
    }

  if (dest_lstat_ok)
    {
      if (S_ISDIR (dest_stats.st_mode))
        {
          error (0, 0, _("%s: cannot overwrite directory"), quotef (dest));
          return false;
        }
      if (interactive)
        {
          fprintf (stderr, _("%s: replace %s? "), program_name, quoteaf (dest));
          if (!yesno ())
            return true;
          remove_existing_files = true;
        }

      if (backup_type != no_backups)
        {
          dest_backup = find_backup_file_name (dest, backup_type);
          if (rename (dest, dest_backup) != 0)
            {
              int rename_errno = errno;
              free (dest_backup);
              dest_backup = NULL;
              if (rename_errno != ENOENT)
                {
                  error (0, rename_errno, _("cannot backup %s"),
                         quoteaf (dest));
                  return false;
                }
            }
        }
    }

  if (relative)
    source = rel_source = convert_abs_rel (source, dest);

  /* If the attempt to create a link fails and we are removing or
     backing up destinations, unlink the destination and try again.

     On the surface, POSIX describes an algorithm that states that
     'ln -f A B' will call unlink() on B before ever attempting
     link() on A.  But strictly following this has the counterintuitive
     effect of losing the contents of B, if A does not exist.
     Fortunately, POSIX 2008 clarified that an application is free
     to fail early if it can prove that continuing onwards cannot
     succeed, so we are justified in trying link() before blindly
     removing B, thus sometimes calling link() a second time during
     a successful 'ln -f A B'.

     Try to unlink DEST even if we may have backed it up successfully.
     In some unusual cases (when DEST and DEST_BACKUP are hard-links
     that refer to the same file), rename succeeds and DEST remains.
     If we didn't remove DEST in that case, the subsequent symlink or link
     call would fail.  */
  bool ok_to_remove = remove_existing_files || dest_backup;
  bool ok = 0 <= (symbolic_link
                  ? force_symlinkat (source, AT_FDCWD, dest, ok_to_remove)
                  : force_linkat (AT_FDCWD, source, AT_FDCWD, dest,
                                  logical ? AT_SYMLINK_FOLLOW : 0,
                                  ok_to_remove));

  if (ok)
    {
      /* Right after creating a hard link, do this: (note dest name and
         source_stats, which are also the just-linked-destinations stats) */
      if (! symbolic_link)
        record_file (dest_set, dest, &source_stats);

      if (verbose)
        {
          if (dest_backup)
            printf ("%s ~ ", quoteaf (dest_backup));
          printf ("%s %c> %s\n\r", quoteaf_n (0, dest),
                  (symbolic_link ? '-' : '='), quoteaf_n (1, source));
        }
    }
  else
    {
      error (0, errno,
             (symbolic_link
              ? (errno != ENAMETOOLONG && *source
                 ? _("failed to create symbolic link %s")
                 : _("failed to create symbolic link %s -> %s"))
              : (errno == EMLINK && !source_is_dir
                 ? _("failed to create hard link to %.0s%s")
                 : (errno == EDQUOT || errno == EEXIST || errno == ENOSPC
                    || errno == EROFS)
                 ? _("failed to create hard link %s")
                 : _("failed to create hard link %s => %s"))),
             quoteaf_n (0, dest), quoteaf_n (1, source));

      if (dest_backup)
        {
          if (rename (dest_backup, dest) != 0)
            error (0, errno, _("cannot un-backup %s"), quoteaf (dest));
        }
    }

  free (dest_backup);
  free (rel_source);
  return ok;
}

void
usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("\
Usage: %s [OPTION]... [-T] TARGET LINK_NAME   (1st form)\n\r\
  or:  %s [OPTION]... TARGET                  (2nd form)\n\r\
  or:  %s [OPTION]... TARGET... DIRECTORY     (3rd form)\n\r\
  or:  %s [OPTION]... -t DIRECTORY TARGET...  (4th form)\n\r\
"),
              program_name, program_name, program_name, program_name);
      fputs (_("\
In the 1st form, create a link to TARGET with the name LINK_NAME.\n\r\
In the 2nd form, create a link to TARGET in the current directory.\n\r\
In the 3rd and 4th forms, create links to each TARGET in DIRECTORY.\n\r\
Create hard links by default, symbolic links with --symbolic.\n\r\
By default, each destination (name of new link) should not already exist.\n\r\
When creating hard links, each TARGET must exist.  Symbolic links\n\r\
can hold arbitrary text; if later resolved, a relative link is\n\r\
interpreted in relation to its parent directory.\n\r\
"), stdout);

      emit_mandatory_arg_note ();

      fputs (_("\
      --backup[=CONTROL]      make a backup of each existing destination file\n\r\
  -b                          like --backup but does not accept an argument\n\r\
  -d, -F, --directory         allow the superuser to attempt to hard link\n\r\
                                directories (note: will probably fail due to\n\r\
                                system restrictions, even for the superuser)\n\r\
  -f, --force                 remove existing destination files\n\r\
"), stdout);
      fputs (_("\
  -i, --interactive           prompt whether to remove destinations\n\r\
  -L, --logical               dereference TARGETs that are symbolic links\n\r\
  -n, --no-dereference        treat LINK_NAME as a normal file if\n\r\
                                it is a symbolic link to a directory\n\r\
  -P, --physical              make hard links directly to symbolic links\n\r\
  -r, --relative              create symbolic links relative to link location\n\r\
  -s, --symbolic              make symbolic links instead of hard links\n\r\
"), stdout);
      fputs (_("\
  -S, --suffix=SUFFIX         override the usual backup suffix\n\r\
  -t, --target-directory=DIRECTORY  specify the DIRECTORY in which to create\n\r\
                                the links\n\r\
  -T, --no-target-directory   treat LINK_NAME as a normal file always\n\r\
  -v, --verbose               print name of each linked file\n\r\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      emit_backup_suffix_note ();
      printf (_("\
\n\r\
Using -s ignores -L and -P.  Otherwise, the last option specified controls\n\r\
behavior when a TARGET is a symbolic link, defaulting to %s.\n\r\
"), LINK_FOLLOWS_SYMLINKS ? "-L" : "-P");
      emit_ancillary_info (PROGRAM_NAME);
    }
  // exit (status);
}

int
ln_main (int argc, char **argv)
{
  int c;
  bool ok;
  bool make_backups = false;
  char *version_control_string = NULL;
  char const *target_directory = NULL;
  bool no_target_directory = false;
  int n_files;
  char **file;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdin);

  symbolic_link = remove_existing_files = interactive = verbose
    = hard_dir_link = false;

  while ((c = getopt_long (argc, argv, "bdfinrst:vFLPS:T", long_options, NULL))
         != -1)
    {
      switch (c)
        {
        case 'b':
          make_backups = true;
          if (optarg)
            version_control_string = optarg;
          break;
        case 'd':
        case 'F':
          hard_dir_link = true;
          break;
        case 'f':
          remove_existing_files = true;
          interactive = false;
          break;
        case 'i':
          remove_existing_files = false;
          interactive = true;
          break;
        case 'L':
          logical = true;
          break;
        case 'n':
          dereference_dest_dir_symlinks = false;
          break;
        case 'P':
          logical = false;
          break;
        case 'r':
          relative = true;
          break;
        case 's':
          symbolic_link = true;
          break;
        case 't':
          if (target_directory)
            die (EXIT_FAILURE, 0, _("multiple target directories specified"));
          else
            {
              struct stat st;
              if (stat (optarg, &st) != 0)
                die (EXIT_FAILURE, errno, _("failed to access %s"),
                     quoteaf (optarg));
              if (! S_ISDIR (st.st_mode))
                die (EXIT_FAILURE, 0, _("target %s is not a directory"),
                     quoteaf (optarg));
            }
          target_directory = optarg;
          break;
        case 'T':
          no_target_directory = true;
          break;
        case 'v':
          verbose = true;
          break;
        case 'S':
          make_backups = true;
          simple_backup_suffix = optarg;
          break;
        case_GETOPT_HELP_CHAR;
        case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);
        default:
          usage (EXIT_FAILURE);
          return EXIT_FAILURE;
          break;
        }
    }

  n_files = argc - optind;
  file = argv + optind;

  if (n_files <= 0)
    {
      error (0, 0, _("missing file operand"));
      usage (EXIT_FAILURE);
    }

  if (no_target_directory)
    {
      if (target_directory)
        die (EXIT_FAILURE, 0,
             _("cannot combine --target-directory "
               "and --no-target-directory"));
      if (n_files != 2)
        {
          if (n_files < 2)
            error (0, 0,
                   _("missing destination file operand after %s"),
                   quoteaf (file[0]));
          else
            error (0, 0, _("extra operand %s"), quoteaf (file[2]));
          usage (EXIT_FAILURE);
        }
    }
  else if (!target_directory)
    {
      if (n_files < 2)
        target_directory = ".";
      else if (2 <= n_files && target_directory_operand (file[n_files - 1]))
        target_directory = file[--n_files];
      else if (2 < n_files)
        die (EXIT_FAILURE, 0, _("target %s is not a directory"),
             quoteaf (file[n_files - 1]));
    }

  backup_type = (make_backups
                 ? xget_version (_("backup type"), version_control_string)
                 : no_backups);

  if (relative && !symbolic_link)
    {
        die (EXIT_FAILURE, 0,
             _("cannot do --relative without --symbolic"));
    }


  if (target_directory)
    {
      int i;

      /* Create the data structure we'll use to record which hard links we
         create.  Used to ensure that ln detects an obscure corner case that
         might result in user data loss.  Create it only if needed.  */
      if (2 <= n_files
          && remove_existing_files
          /* Don't bother trying to protect symlinks, since ln clobbering
             a just-created symlink won't ever lead to real data loss.  */
          && ! symbolic_link
          /* No destination hard link can be clobbered when making
             numbered backups.  */
          && backup_type != numbered_backups)

        {
          dest_set = hash_initialize (DEST_INFO_INITIAL_CAPACITY,
                                      NULL,
                                      triple_hash,
                                      triple_compare,
                                      triple_free);
          if (dest_set == NULL)
            xalloc_die ();
        }

      ok = true;
      for (i = 0; i < n_files; ++i)
        {
          char *dest_base;
          char *dest = file_name_concat (target_directory,
                                         last_component (file[i]),
                                         &dest_base);
          strip_trailing_slashes (dest_base);
          ok &= do_link (file[i], dest);
          free (dest);
        }
    }
  else
    ok = do_link (file[0], file[1]);

  return ok ? EXIT_SUCCESS : EXIT_FAILURE;
}
