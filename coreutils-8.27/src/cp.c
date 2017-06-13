/* cp.c  -- file copying (main routines)
   Copyright (C) 1989-2017 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.

   Written by Torbjorn Granlund, David MacKenzie, and Jim Meyering. */

#include <config.h>
#include <stdio.h>
#include <sys/types.h>
#include <getopt.h>
#include <selinux/selinux.h>

#include "system.h"
#include "argmatch.h"
#include "backupfile.h"
#include "copy.h"
#include "cp-hash.h"
#include "die.h"
#include "error.h"
#include "filenamecat.h"
#include "ignore-value.h"
#include "quote.h"
#include "stat-time.h"
#include "utimens.h"
#include "acl.h"

#undef usage
#define usage cp_usage
static void cp_usage (int status);


#if ! HAVE_LCHOWN
# define lchown(name, uid, gid) chown (name, uid, gid)
#endif

#define ASSIGN_BASENAME_STRDUPA(Dest, File_name)	\
  do							\
    {							\
      char *tmp_abns_;					\
      ASSIGN_STRDUPA (tmp_abns_, (File_name));		\
      Dest = last_component (tmp_abns_);		\
      strip_trailing_slashes (Dest);			\
    }							\
  while (0)

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "cp"

#define AUTHORS \
  proper_name ("Torbjorn Granlund"), \
  proper_name ("David MacKenzie"), \
  proper_name ("Jim Meyering")

/* Used by do_copy, make_dir_parents_private, and re_protect
   to keep a list of leading directories whose protections
   need to be fixed after copying. */
struct dir_attr
{
  struct stat st;
  bool restore_mode;
  size_t slash_offset;
  struct dir_attr *next;
};

/* For long options that have no equivalent short option, use a
   non-character as a pseudo short option, starting with CHAR_MAX + 1.  */
enum
{
  ATTRIBUTES_ONLY_OPTION = CHAR_MAX + 1,
  COPY_CONTENTS_OPTION,
  NO_PRESERVE_ATTRIBUTES_OPTION,
  PARENTS_OPTION,
  PRESERVE_ATTRIBUTES_OPTION,
  REFLINK_OPTION,
  SPARSE_OPTION,
  STRIP_TRAILING_SLASHES_OPTION,
  UNLINK_DEST_BEFORE_OPENING
};

/* True if the kernel is SELinux enabled.  */
static bool selinux_enabled;

/* If true, the command "cp x/e_file e_dir" uses "e_dir/x/e_file"
   as its destination instead of the usual "e_dir/e_file." */
static bool parents_option = false;

/* Remove any trailing slashes from each SOURCE argument.  */
static bool remove_trailing_slashes;

static char const *const sparse_type_string[] =
{
  "never", "auto", "always", NULL
};
static enum Sparse_type const sparse_type[] =
{
  SPARSE_NEVER, SPARSE_AUTO, SPARSE_ALWAYS
};
ARGMATCH_VERIFY (sparse_type_string, sparse_type);

static char const *const reflink_type_string[] =
{
  "auto", "always", NULL
};
static enum Reflink_type const reflink_type[] =
{
  REFLINK_AUTO, REFLINK_ALWAYS
};
ARGMATCH_VERIFY (reflink_type_string, reflink_type);

static struct option const long_opts[] =
{
  {"archive", no_argument, NULL, 'a'},
  {"attributes-only", no_argument, NULL, ATTRIBUTES_ONLY_OPTION},
  {"backup", optional_argument, NULL, 'b'},
  {"copy-contents", no_argument, NULL, COPY_CONTENTS_OPTION},
  {"dereference", no_argument, NULL, 'L'},
  {"force", no_argument, NULL, 'f'},
  {"interactive", no_argument, NULL, 'i'},
  {"link", no_argument, NULL, 'l'},
  {"no-clobber", no_argument, NULL, 'n'},
  {"no-dereference", no_argument, NULL, 'P'},
  {"no-preserve", required_argument, NULL, NO_PRESERVE_ATTRIBUTES_OPTION},
  {"no-target-directory", no_argument, NULL, 'T'},
  {"one-file-system", no_argument, NULL, 'x'},
  {"parents", no_argument, NULL, PARENTS_OPTION},
  {"path", no_argument, NULL, PARENTS_OPTION},   /* Deprecated.  */
  {"preserve", optional_argument, NULL, PRESERVE_ATTRIBUTES_OPTION},
  {"recursive", no_argument, NULL, 'R'},
  {"remove-destination", no_argument, NULL, UNLINK_DEST_BEFORE_OPENING},
  {"sparse", required_argument, NULL, SPARSE_OPTION},
  {"reflink", optional_argument, NULL, REFLINK_OPTION},
  {"strip-trailing-slashes", no_argument, NULL, STRIP_TRAILING_SLASHES_OPTION},
  {"suffix", required_argument, NULL, 'S'},
  {"symbolic-link", no_argument, NULL, 's'},
  {"target-directory", required_argument, NULL, 't'},
  {"update", no_argument, NULL, 'u'},
  {"verbose", no_argument, NULL, 'v'},
  {GETOPT_SELINUX_CONTEXT_OPTION_DECL},
  {GETOPT_HELP_OPTION_DECL},
  {GETOPT_VERSION_OPTION_DECL},
  {NULL, 0, NULL, 0}
};

void
cp_usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("\
Usage: %s [OPTION]... [-T] SOURCE DEST\n\r\
  or:  %s [OPTION]... SOURCE... DIRECTORY\n\r\
  or:  %s [OPTION]... -t DIRECTORY SOURCE...\n\r\
"),
              program_name, program_name, program_name);
      fputs (_("\
Copy SOURCE to DEST, or multiple SOURCE(s) to DIRECTORY.\n\r\
"), stdout);

      emit_mandatory_arg_note ();

      fputs (_("\
  -a, --archive                same as -dR --preserve=all\n\r\
      --attributes-only        don't copy the file data, just the attributes\n\r\
      --backup[=CONTROL]       make a backup of each existing destination file\
\n\r\
  -b                           like --backup but does not accept an argument\n\r\
      --copy-contents          copy contents of special files when recursive\n\r\
  -d                           same as --no-dereference --preserve=links\n\r\
"), stdout);
      fputs (_("\
  -f, --force                  if an existing destination file cannot be\n\r\
                                 opened, remove it and try again (this option\n\r\
                                 is ignored when the -n option is also used)\n\r\
  -i, --interactive            prompt before overwrite (overrides a previous -n\
\n\r\
                                  option)\n\r\
  -H                           follow command-line symbolic links in SOURCE\n\r\
"), stdout);
      fputs (_("\
  -l, --link                   hard link files instead of copying\n\r\
  -L, --dereference            always follow symbolic links in SOURCE\n\r\
"), stdout);
      fputs (_("\
  -n, --no-clobber             do not overwrite an existing file (overrides\n\r\
                                 a previous -i option)\n\r\
  -P, --no-dereference         never follow symbolic links in SOURCE\n\r\
"), stdout);
      fputs (_("\
  -p                           same as --preserve=mode,ownership,timestamps\n\r\
      --preserve[=ATTR_LIST]   preserve the specified attributes (default:\n\r\
                                 mode,ownership,timestamps), if possible\n\r\
                                 additional attributes: context, links, xattr,\
\n\r\
                                 all\n\r\
"), stdout);
      fputs (_("\
      --no-preserve=ATTR_LIST  don't preserve the specified attributes\n\r\
      --parents                use full source file name under DIRECTORY\n\r\
"), stdout);
      fputs (_("\
  -R, -r, --recursive          copy directories recursively\n\r\
      --reflink[=WHEN]         control clone/CoW copies. See below\n\r\
      --remove-destination     remove each existing destination file before\n\r\
                                 attempting to open it (contrast with --force)\
\n\r"), stdout);
      fputs (_("\
      --sparse=WHEN            control creation of sparse files. See below\n\r\
      --strip-trailing-slashes  remove any trailing slashes from each SOURCE\n\r\
                                 argument\n\r\
"), stdout);
      fputs (_("\
  -s, --symbolic-link          make symbolic links instead of copying\n\r\
  -S, --suffix=SUFFIX          override the usual backup suffix\n\r\
  -t, --target-directory=DIRECTORY  copy all SOURCE arguments into DIRECTORY\n\r\
  -T, --no-target-directory    treat DEST as a normal file\n\r\
"), stdout);
      fputs (_("\
  -u, --update                 copy only when the SOURCE file is newer\n\r\
                                 than the destination file or when the\n\r\
                                 destination file is missing\n\r\
  -v, --verbose                explain what is being done\n\r\
  -x, --one-file-system        stay on this file system\n\r\
"), stdout);
      fputs (_("\
  -Z                           set SELinux security context of destination\n\r\
                                 file to default type\n\r\
      --context[=CTX]          like -Z, or if CTX is specified then set the\n\r\
                                 SELinux or SMACK security context to CTX\n\r\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      fputs (_("\
\n\r\
By default, sparse SOURCE files are detected by a crude heuristic and the\n\r\
corresponding DEST file is made sparse as well.  That is the behavior\n\r\
selected by --sparse=auto.  Specify --sparse=always to create a sparse DEST\n\r\
file whenever the SOURCE file contains a long enough sequence of zero bytes.\n\r\
Use --sparse=never to inhibit creation of sparse files.\n\r\
\n\r\
When --reflink[=always] is specified, perform a lightweight copy, where the\n\r\
data blocks are copied only when modified.  If this is not possible the copy\n\r\
fails, or if --reflink=auto is specified, fall back to a standard copy.\n\r\
"), stdout);
      emit_backup_suffix_note ();
      fputs (_("\
\n\r\
As a special case, cp makes a backup of SOURCE when the force and backup\n\r\
options are given and SOURCE and DEST are the same name for an existing,\n\r\
regular file.\n\r\
"), stdout);
      emit_ancillary_info (PROGRAM_NAME);
    }
  // exit (status);
}

/* Ensure that the parent directories of CONST_DST_NAME have the
   correct protections, for the --parents option.  This is done
   after all copying has been completed, to allow permissions
   that don't include user write/execute.

   SRC_OFFSET is the index in CONST_DST_NAME of the beginning of the
   source directory name.

   ATTR_LIST is a null-terminated linked list of structures that
   indicates the end of the filename of each intermediate directory
   in CONST_DST_NAME that may need to have its attributes changed.
   The command 'cp --parents --preserve a/b/c d/e_dir' changes the
   attributes of the directories d/e_dir/a and d/e_dir/a/b to match
   the corresponding source directories regardless of whether they
   existed before the 'cp' command was given.

   Return true if the parent of CONST_DST_NAME and any intermediate
   directories specified by ATTR_LIST have the proper permissions
   when done.  */

static bool
re_protect (char const *const_dst_name, size_t src_offset,
            struct dir_attr *attr_list, const struct cp_options *x)
{
  struct dir_attr *p;
  char *dst_name;		/* A copy of CONST_DST_NAME we can change. */
  char *src_name;		/* The source name in 'dst_name'. */

  ASSIGN_STRDUPA (dst_name, const_dst_name);
  src_name = dst_name + src_offset;

  for (p = attr_list; p; p = p->next)
    {
      dst_name[p->slash_offset] = '\0';

      /* Adjust the times (and if possible, ownership) for the copy.
         chown turns off set[ug]id bits for non-root,
         so do the chmod last.  */

      if (x->preserve_timestamps)
        {
          struct timespec timespec[2];

          timespec[0] = get_stat_atime (&p->st);
          timespec[1] = get_stat_mtime (&p->st);

          if (utimens (dst_name, timespec))
            {
              error (0, errno, _("failed to preserve times for %s"),
                     quoteaf (dst_name));
              return false;
            }
        }

      if (x->preserve_ownership)
        {
          if (lchown (dst_name, p->st.st_uid, p->st.st_gid) != 0)
            {
              if (! chown_failure_ok (x))
                {
                  error (0, errno, _("failed to preserve ownership for %s"),
                         quoteaf (dst_name));
                  return false;
                }
              /* Failing to preserve ownership is OK. Still, try to preserve
                 the group, but ignore the possible error. */
              ignore_value (lchown (dst_name, -1, p->st.st_gid));
            }
        }

      if (x->preserve_mode)
        {
          if (copy_acl (src_name, -1, dst_name, -1, p->st.st_mode) != 0)
            return false;
        }
      else if (p->restore_mode)
        {
          if (lchmod (dst_name, p->st.st_mode) != 0)
            {
              error (0, errno, _("failed to preserve permissions for %s"),
                     quoteaf (dst_name));
              return false;
            }
        }

      dst_name[p->slash_offset] = '/';
    }
  return true;
}

/* Ensure that the parent directory of CONST_DIR exists, for
   the --parents option.

   SRC_OFFSET is the index in CONST_DIR (which is a destination
   directory) of the beginning of the source directory name.
   Create any leading directories that don't already exist.
   If VERBOSE_FMT_STRING is nonzero, use it as a printf format
   string for printing a message after successfully making a directory.
   The format should take two string arguments: the names of the
   source and destination directories.
   Creates a linked list of attributes of intermediate directories,
   *ATTR_LIST, for re_protect to use after calling copy.
   Sets *NEW_DST if this function creates parent of CONST_DIR.

   Return true if parent of CONST_DIR exists as a directory with the proper
   permissions when done.  */

/* FIXME: Synch this function with the one in ../lib/mkdir-p.c.  */

static bool
make_dir_parents_private (char const *const_dir, size_t src_offset,
                          char const *verbose_fmt_string,
                          struct dir_attr **attr_list, bool *new_dst,
                          const struct cp_options *x)
{
  struct stat stats;
  char *dir;		/* A copy of CONST_DIR we can change.  */
  char *src;		/* Source name in DIR.  */
  char *dst_dir;	/* Leading directory of DIR.  */
  size_t dirlen;	/* Length of DIR.  */

  ASSIGN_STRDUPA (dir, const_dir);

  src = dir + src_offset;

  dirlen = dir_len (dir);
  dst_dir = alloca (dirlen + 1);
  memcpy (dst_dir, dir, dirlen);
  dst_dir[dirlen] = '\0';

  *attr_list = NULL;

  /* XXX: If all dirs are present at the destination,
     no permissions or security contexts will be updated.  */
  if (stat (dst_dir, &stats) != 0)
    {
      /* A parent of CONST_DIR does not exist.
         Make all missing intermediate directories. */
      char *slash;

      slash = src;
      while (*slash == '/')
        slash++;
      while ((slash = strchr (slash, '/')))
        {
          struct dir_attr *new IF_LINT ( = NULL);
          bool missing_dir;

          *slash = '\0';
          missing_dir = (stat (dir, &stats) != 0);

          if (missing_dir || x->preserve_ownership || x->preserve_mode
              || x->preserve_timestamps)
            {
              /* Add this directory to the list of directories whose
                 modes might need fixing later. */
              struct stat src_st;
              int src_errno = (stat (src, &src_st) != 0
                               ? errno
                               : S_ISDIR (src_st.st_mode)
                               ? 0
                               : ENOTDIR);
              if (src_errno)
                {
                  error (0, src_errno, _("failed to get attributes of %s"),
                         quoteaf (src));
                  return false;
                }

              new = xmalloc (sizeof *new);
              new->st = src_st;
              new->slash_offset = slash - dir;
              new->restore_mode = false;
              new->next = *attr_list;
              *attr_list = new;
            }

          /* If required set the default context for created dirs.  */
          if (! set_process_security_ctx (src, dir,
                                          missing_dir ? new->st.st_mode : 0,
                                          missing_dir, x))
            return false;

          if (missing_dir)
            {
              mode_t src_mode;
              mode_t omitted_permissions;
              mode_t mkdir_mode;

              /* This component does not exist.  We must set
                 *new_dst and new->st.st_mode inside this loop because,
                 for example, in the command 'cp --parents ../a/../b/c e_dir',
                 make_dir_parents_private creates only e_dir/../a if
                 ./b already exists. */
              *new_dst = true;
              src_mode = new->st.st_mode;

              /* If the ownership or special mode bits might change,
                 omit some permissions at first, so unauthorized users
                 cannot nip in before the file is ready.  */
              omitted_permissions = (src_mode
                                     & (x->preserve_ownership
                                        ? S_IRWXG | S_IRWXO
                                        : x->preserve_mode
                                        ? S_IWGRP | S_IWOTH
                                        : 0));

              /* POSIX says mkdir's behavior is implementation-defined when
                 (src_mode & ~S_IRWXUGO) != 0.  However, common practice is
                 to ask mkdir to copy all the CHMOD_MODE_BITS, letting mkdir
                 decide what to do with S_ISUID | S_ISGID | S_ISVTX.  */
              mkdir_mode = x->explicit_no_preserve_mode ? S_IRWXUGO : src_mode;
              mkdir_mode &= CHMOD_MODE_BITS & ~omitted_permissions;
              if (mkdir (dir, mkdir_mode) != 0)
                {
                  error (0, errno, _("cannot make directory %s"),
                         quoteaf (dir));
                  return false;
                }
              else
                {
                  if (verbose_fmt_string != NULL)
                    printf (verbose_fmt_string, src, dir);
                }

              /* We need search and write permissions to the new directory
                 for writing the directory's contents. Check if these
                 permissions are there.  */

              if (lstat (dir, &stats))
                {
                  error (0, errno, _("failed to get attributes of %s"),
                         quoteaf (dir));
                  return false;
                }


              if (! x->preserve_mode)
                {
                  if (omitted_permissions & ~stats.st_mode)
                    omitted_permissions &= ~ cached_umask ();
                  if (omitted_permissions & ~stats.st_mode
                      || (stats.st_mode & S_IRWXU) != S_IRWXU)
                    {
                      new->st.st_mode = stats.st_mode | omitted_permissions;
                      new->restore_mode = true;
                    }
                }

              if ((stats.st_mode & S_IRWXU) != S_IRWXU)
                {
                  /* Make the new directory searchable and writable.
                     The original permissions will be restored later.  */

                  if (lchmod (dir, stats.st_mode | S_IRWXU) != 0)
                    {
                      error (0, errno, _("setting permissions for %s"),
                             quoteaf (dir));
                      return false;
                    }
                }
            }
          else if (!S_ISDIR (stats.st_mode))
            {
              error (0, 0, _("%s exists but is not a directory"),
                     quoteaf (dir));
              return false;
            }
          else
            *new_dst = false;

          /* For existing dirs, set the security context as per that already
             set for the process global context.  */
          if (! *new_dst
              && (x->set_security_context || x->preserve_security_context))
            {
              if (! set_file_security_ctx (dir, x->preserve_security_context,
                                           false, x)
                  && x->require_preserve_context)
                  return false;
            }

          *slash++ = '/';

          /* Avoid unnecessary calls to 'stat' when given
             file names containing multiple adjacent slashes.  */
          while (*slash == '/')
            slash++;
        }
    }

  /* We get here if the parent of DIR already exists.  */

  else if (!S_ISDIR (stats.st_mode))
    {
      error (0, 0, _("%s exists but is not a directory"), quoteaf (dst_dir));
      return false;
    }
  else
    {
      *new_dst = false;
    }
  return true;
}

/* FILE is the last operand of this command.
   Return true if FILE is a directory.
   But report an error and exit if there is a problem accessing FILE,
   or if FILE does not exist but would have to refer to an existing
   directory if it referred to anything at all.

   If the file exists, store the file's status into *ST.
   Otherwise, set *NEW_DST.  */

static bool
target_directory_operand (char const *file, struct stat *st, bool *new_dst)
{
  int err = (stat (file, st) == 0 ? 0 : errno);
  bool is_a_dir = !err && S_ISDIR (st->st_mode);
  if (err)
    {
      if (err != ENOENT)
        die (EXIT_FAILURE, err, _("failed to access %s"), quoteaf (file));
      *new_dst = true;
    }
  return is_a_dir;
}

/* Scan the arguments, and copy each by calling copy.
   Return true if successful.  */

static bool
do_copy (int n_files, char **file, const char *target_directory,
         bool no_target_directory, struct cp_options *x)
{
  struct stat sb;
  bool new_dst = false;
  bool ok = true;

  if (n_files <= !target_directory)
    {
      if (n_files <= 0)
        error (0, 0, _("missing file operand"));
      else
        error (0, 0, _("missing destination file operand after %s"),
               quoteaf (file[0]));
      usage (EXIT_FAILURE);
    }

  if (no_target_directory)
    {
      if (target_directory)
        die (EXIT_FAILURE, 0,
             _("cannot combine --target-directory (-t) "
               "and --no-target-directory (-T)"));
      if (2 < n_files)
        {
          error (0, 0, _("extra operand %s"), quoteaf (file[2]));
          usage (EXIT_FAILURE);
        }
      /* Update NEW_DST and SB, which may be checked below.  */
      ignore_value (target_directory_operand (file[n_files -1], &sb, &new_dst));
    }
  else if (!target_directory)
    {
      if (2 <= n_files
          && target_directory_operand (file[n_files - 1], &sb, &new_dst))
        target_directory = file[--n_files];
      else if (2 < n_files)
        die (EXIT_FAILURE, 0, _("target %s is not a directory"),
             quoteaf (file[n_files - 1]));
    }

  if (target_directory)
    {
      /* cp file1...filen edir
         Copy the files 'file1' through 'filen'
         to the existing directory 'edir'. */
      int i;

      /* Initialize these hash tables only if we'll need them.
         The problems they're used to detect can arise only if
         there are two or more files to copy.  */
      if (2 <= n_files)
        {
          dest_info_init (x);
          src_info_init (x);
        }

      for (i = 0; i < n_files; i++)
        {
          char *dst_name;
          bool parent_exists = true;  /* True if dir_name (dst_name) exists. */
          struct dir_attr *attr_list;
          char *arg_in_concat = NULL;
          char *arg = file[i];

          /* Trailing slashes are meaningful (i.e., maybe worth preserving)
             only in the source file names.  */
          if (remove_trailing_slashes)
            strip_trailing_slashes (arg);

          if (parents_option)
            {
              char *arg_no_trailing_slash;

              /* Use 'arg' without trailing slashes in constructing destination
                 file names.  Otherwise, we can end up trying to create a
                 directory via 'mkdir ("dst/foo/"...', which is not portable.
                 It fails, due to the trailing slash, on at least
                 NetBSD 1.[34] systems.  */
              ASSIGN_STRDUPA (arg_no_trailing_slash, arg);
              strip_trailing_slashes (arg_no_trailing_slash);

              /* Append all of 'arg' (minus any trailing slash) to 'dest'.  */
              dst_name = file_name_concat (target_directory,
                                           arg_no_trailing_slash,
                                           &arg_in_concat);

              /* For --parents, we have to make sure that the directory
                 dir_name (dst_name) exists.  We may have to create a few
                 leading directories. */
              parent_exists =
                (make_dir_parents_private
                 (dst_name, arg_in_concat - dst_name,
                  (x->verbose ? "%s -> %s\n\r" : NULL),
                  &attr_list, &new_dst, x));
            }
          else
            {
              char *arg_base;
              /* Append the last component of 'arg' to 'target_directory'.  */

              ASSIGN_BASENAME_STRDUPA (arg_base, arg);
              /* For 'cp -R source/.. dest', don't copy into 'dest/..'. */
              dst_name = (STREQ (arg_base, "..")
                          ? xstrdup (target_directory)
                          : file_name_concat (target_directory, arg_base,
                                              NULL));
            }

          if (!parent_exists)
            {
              /* make_dir_parents_private failed, so don't even
                 attempt the copy.  */
              ok = false;
            }
          else
            {
              bool copy_into_self;
              ok &= copy (arg, dst_name, new_dst, x, &copy_into_self, NULL);

              if (parents_option)
                ok &= re_protect (dst_name, arg_in_concat - dst_name,
                                  attr_list, x);
            }

          if (parents_option)
            {
              while (attr_list)
                {
                  struct dir_attr *p = attr_list;
                  attr_list = attr_list->next;
                  free (p);
                }
            }

          free (dst_name);
        }
    }
  else /* !target_directory */
    {
      char const *new_dest;
      char const *source = file[0];
      char const *dest = file[1];
      bool unused;

      if (parents_option)
        {
          error (0, 0,
                 _("with --parents, the destination must be a directory"));
          usage (EXIT_FAILURE);
        }

      /* When the force and backup options have been specified and
         the source and destination are the same name for an existing
         regular file, convert the user's command, e.g.,
         'cp --force --backup foo foo' to 'cp --force foo fooSUFFIX'
         where SUFFIX is determined by any version control options used.  */

      if (x->unlink_dest_after_failed_open
          && x->backup_type != no_backups
          && STREQ (source, dest)
          && !new_dst && S_ISREG (sb.st_mode))
        {
          static struct cp_options x_tmp;

          new_dest = find_backup_file_name (dest, x->backup_type);
          /* Set x->backup_type to 'no_backups' so that the normal backup
             mechanism is not used when performing the actual copy.
             backup_type must be set to 'no_backups' only *after* the above
             call to find_backup_file_name -- that function uses
             backup_type to determine the suffix it applies.  */
          x_tmp = *x;
          x_tmp.backup_type = no_backups;
          x = &x_tmp;
        }
      else
        {
          new_dest = dest;
        }

      ok = copy (source, new_dest, 0, x, &unused, NULL);
    }

  return ok;
}

static void
cp_option_init (struct cp_options *x)
{
  cp_options_default (x);
  x->copy_as_regular = true;
  x->dereference = DEREF_UNDEFINED;
  x->unlink_dest_before_opening = false;
  x->unlink_dest_after_failed_open = false;
  x->hard_link = false;
  x->interactive = I_UNSPECIFIED;
  x->move_mode = false;
  x->install_mode = false;
  x->one_file_system = false;
  x->reflink_mode = REFLINK_NEVER;

  x->preserve_ownership = false;
  x->preserve_links = false;
  x->preserve_mode = false;
  x->preserve_timestamps = false;
  x->explicit_no_preserve_mode = false;
  x->preserve_security_context = false; /* -a or --preserve=context.  */
  x->require_preserve_context = false;  /* --preserve=context.  */
  x->set_security_context = false;      /* -Z, set sys default context. */
  x->preserve_xattr = false;
  x->reduce_diagnostics = false;
  x->require_preserve_xattr = false;

  x->data_copy_required = true;
  x->require_preserve = false;
  x->recursive = false;
  x->sparse_mode = SPARSE_AUTO;
  x->symbolic_link = false;
  x->set_mode = false;
  x->mode = 0;

  /* Not used.  */
  x->stdin_tty = false;

  x->update = false;
  x->verbose = false;

  /* By default, refuse to open a dangling destination symlink, because
     in general one cannot do that safely, give the current semantics of
     open's O_EXCL flag, (which POSIX doesn't even allow cp to use, btw).
     But POSIX requires it.  */
  x->open_dangling_dest_symlink = getenv ("POSIXLY_CORRECT") != NULL;

  x->dest_info = NULL;
  x->src_info = NULL;
}

/* Given a string, ARG, containing a comma-separated list of arguments
   to the --preserve option, set the appropriate fields of X to ON_OFF.  */
static void
decode_preserve_arg (char const *arg, struct cp_options *x, bool on_off)
{
  enum File_attribute
    {
      PRESERVE_MODE,
      PRESERVE_TIMESTAMPS,
      PRESERVE_OWNERSHIP,
      PRESERVE_LINK,
      PRESERVE_CONTEXT,
      PRESERVE_XATTR,
      PRESERVE_ALL
    };
  static enum File_attribute const preserve_vals[] =
    {
      PRESERVE_MODE, PRESERVE_TIMESTAMPS,
      PRESERVE_OWNERSHIP, PRESERVE_LINK, PRESERVE_CONTEXT, PRESERVE_XATTR,
      PRESERVE_ALL
    };
  /* Valid arguments to the '--preserve' option. */
  static char const* const preserve_args[] =
    {
      "mode", "timestamps",
      "ownership", "links", "context", "xattr", "all", NULL
    };
  ARGMATCH_VERIFY (preserve_args, preserve_vals);

  char *arg_writable = xstrdup (arg);
  char *s = arg_writable;
  do
    {
      /* find next comma */
      char *comma = strchr (s, ',');
      enum File_attribute val;

      /* If we found a comma, put a NUL in its place and advance.  */
      if (comma)
        *comma++ = 0;

      /* process S.  */
      val = XARGMATCH (on_off ? "--preserve" : "--no-preserve",
                       s, preserve_args, preserve_vals);
      switch (val)
        {
        case PRESERVE_MODE:
          x->preserve_mode = on_off;
          x->explicit_no_preserve_mode = !on_off;
          break;

        case PRESERVE_TIMESTAMPS:
          x->preserve_timestamps = on_off;
          break;

        case PRESERVE_OWNERSHIP:
          x->preserve_ownership = on_off;
          break;

        case PRESERVE_LINK:
          x->preserve_links = on_off;
          break;

        case PRESERVE_CONTEXT:
          x->require_preserve_context = on_off;
          x->preserve_security_context = on_off;
          break;

        case PRESERVE_XATTR:
          x->preserve_xattr = on_off;
          x->require_preserve_xattr = on_off;
          break;

        case PRESERVE_ALL:
          x->preserve_mode = on_off;
          x->preserve_timestamps = on_off;
          x->preserve_ownership = on_off;
          x->preserve_links = on_off;
          x->explicit_no_preserve_mode = !on_off;
          if (selinux_enabled)
            x->preserve_security_context = on_off;
          x->preserve_xattr = on_off;
          break;

        default:
          abort ();
        }
      s = comma;
    }
  while (s);

  free (arg_writable);
}

int
cp_main (int argc, char **argv)
{
  int c;
  bool ok;
  bool make_backups = false;
  char *version_control_string = NULL;
  struct cp_options x;
  bool copy_contents = false;
  char *target_directory = NULL;
  bool no_target_directory = false;
  char const *scontext = NULL;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdin);

  selinux_enabled = (0 < is_selinux_enabled ());
  cp_option_init (&x);

  while ((c = getopt_long (argc, argv, "abdfHilLnprst:uvxPRS:TZ",
                           long_opts, NULL))
         != -1)
    {
      switch (c)
        {
        case SPARSE_OPTION:
          x.sparse_mode = XARGMATCH ("--sparse", optarg,
                                     sparse_type_string, sparse_type);
          break;

        case REFLINK_OPTION:
          if (optarg == NULL)
            x.reflink_mode = REFLINK_ALWAYS;
          else
            x.reflink_mode = XARGMATCH ("--reflink", optarg,
                                       reflink_type_string, reflink_type);
          break;

        case 'a':
          /* Like -dR --preserve=all with reduced failure diagnostics.  */
          x.dereference = DEREF_NEVER;
          x.preserve_links = true;
          x.preserve_ownership = true;
          x.preserve_mode = true;
          x.preserve_timestamps = true;
          x.require_preserve = true;
          if (selinux_enabled)
             x.preserve_security_context = true;
          x.preserve_xattr = true;
          x.reduce_diagnostics = true;
          x.recursive = true;
          break;

        case 'b':
          make_backups = true;
          if (optarg)
            version_control_string = optarg;
          break;

        case ATTRIBUTES_ONLY_OPTION:
          x.data_copy_required = false;
          break;

        case COPY_CONTENTS_OPTION:
          copy_contents = true;
          break;

        case 'd':
          x.preserve_links = true;
          x.dereference = DEREF_NEVER;
          break;

        case 'f':
          x.unlink_dest_after_failed_open = true;
          break;

        case 'H':
          x.dereference = DEREF_COMMAND_LINE_ARGUMENTS;
          break;

        case 'i':
          x.interactive = I_ASK_USER;
          break;

        case 'l':
          x.hard_link = true;
          break;

        case 'L':
          x.dereference = DEREF_ALWAYS;
          break;

        case 'n':
          x.interactive = I_ALWAYS_NO;
          break;

        case 'P':
          x.dereference = DEREF_NEVER;
          break;

        case NO_PRESERVE_ATTRIBUTES_OPTION:
          decode_preserve_arg (optarg, &x, false);
          break;

        case PRESERVE_ATTRIBUTES_OPTION:
          if (optarg == NULL)
            {
              /* Fall through to the case for 'p' below.  */
            }
          else
            {
              decode_preserve_arg (optarg, &x, true);
              x.require_preserve = true;
              break;
            }
          /* fall through */

        case 'p':
          x.preserve_ownership = true;
          x.preserve_mode = true;
          x.preserve_timestamps = true;
          x.require_preserve = true;
          break;

        case PARENTS_OPTION:
          parents_option = true;
          break;

        case 'r':
        case 'R':
          x.recursive = true;
          break;

        case UNLINK_DEST_BEFORE_OPENING:
          x.unlink_dest_before_opening = true;
          break;

        case STRIP_TRAILING_SLASHES_OPTION:
          remove_trailing_slashes = true;
          break;

        case 's':
          x.symbolic_link = true;
          break;

        case 't':
          if (target_directory)
            die (EXIT_FAILURE, 0,
                 _("multiple target directories specified"));
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

        case 'u':
          x.update = true;
          break;

        case 'v':
          x.verbose = true;
          break;

        case 'x':
          x.one_file_system = true;
          break;

        case 'Z':
          /* politely decline if we're not on a selinux-enabled kernel.  */
          if (selinux_enabled)
            {
              if (optarg)
                scontext = optarg;
              else
                x.set_security_context = true;
            }
          else if (optarg)
            {
              error (0, 0,
                     _("warning: ignoring --context; "
                       "it requires an SELinux-enabled kernel"));
            }
          break;

        case 'S':
          make_backups = true;
          simple_backup_suffix = optarg;
          break;

        case_GETOPT_HELP_CHAR;
                return EXIT_SUCCESS;

        case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);
                return EXIT_SUCCESS;

        default:
          usage (EXIT_FAILURE);
                return EXIT_FAILURE;
        }
    }

  if (x.hard_link && x.symbolic_link)
    {
      error (0, 0, _("cannot make both hard and symbolic links"));
      usage (EXIT_FAILURE);
    }

  if (make_backups && x.interactive == I_ALWAYS_NO)
    {
      error (0, 0,
             _("options --backup and --no-clobber are mutually exclusive"));
      usage (EXIT_FAILURE);
    }

  if (x.reflink_mode == REFLINK_ALWAYS && x.sparse_mode != SPARSE_AUTO)
    {
      error (0, 0, _("--reflink can be used only with --sparse=auto"));
      usage (EXIT_FAILURE);
    }

  x.backup_type = (make_backups
                   ? xget_version (_("backup type"),
                                   version_control_string)
                   : no_backups);

  if (x.dereference == DEREF_UNDEFINED)
    {
      if (x.recursive && ! x.hard_link)
        /* This is compatible with FreeBSD.  */
        x.dereference = DEREF_NEVER;
      else
        x.dereference = DEREF_ALWAYS;
    }

  if (x.recursive)
    x.copy_as_regular = copy_contents;

  /* Ensure -Z overrides -a.  */
  if ((x.set_security_context || scontext)
      && ! x.require_preserve_context)
    x.preserve_security_context = false;

  if (x.preserve_security_context && (x.set_security_context || scontext))
    die (EXIT_FAILURE, 0,
         _("cannot set target context and preserve it"));

  if (x.require_preserve_context && ! selinux_enabled)
    die (EXIT_FAILURE, 0,
         _("cannot preserve security context "
           "without an SELinux-enabled kernel"));

  /* FIXME: This handles new files.  But what about existing files?
     I.e., if updating a tree, new files would have the specified context,
     but shouldn't existing files be updated for consistency like this?
       if (scontext)
         restorecon (dst_path, 0, true);
   */
  if (scontext && setfscreatecon (se_const (scontext)) < 0)
    die (EXIT_FAILURE, errno,
         _("failed to set default file creation context to %s"),
         quote (scontext));

#if !USE_XATTR
  if (x.require_preserve_xattr)
    die (EXIT_FAILURE, 0, _("cannot preserve extended attributes, cp is "
                            "built without xattr support"));
#endif

  /* Allocate space for remembering copied and created files.  */

  hash_init ();

  ok = do_copy (argc - optind, argv + optind,
                target_directory, no_target_directory, &x);

#ifdef lint
  forget_all ();
#endif

  return ok ? EXIT_SUCCESS : EXIT_FAILURE;
}
