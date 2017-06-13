/* copy.c -- core functions for copying files and directories
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
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* Extracted from cp.c and librarified by Jim Meyering.  */

#include <config.h>
#include <stdio.h>
#include <assert.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <selinux/selinux.h>

#if HAVE_HURD_H
# include <hurd.h>
#endif
#if HAVE_PRIV_H
# include <priv.h>
#endif

#include "system.h"
#include "acl.h"
#include "backupfile.h"
#include "buffer-lcm.h"
#include "canonicalize.h"
#include "copy.h"
#include "cp-hash.h"
#include "extent-scan.h"
#include "die.h"
#include "error.h"
#include "fadvise.h"
#include "fcntl--.h"
#include "fiemap.h"
#include "file-set.h"
#include "filemode.h"
#include "filenamecat.h"
#include "force-link.h"
#include "full-write.h"
#include "hash.h"
#include "hash-triple.h"
#include "ignore-value.h"
#include "ioblksize.h"
#include "quote.h"
#include "root-uid.h"
#include "same.h"
#include "savedir.h"
#include "stat-size.h"
#include "stat-time.h"
#include "utimecmp.h"
#include "utimens.h"
#include "write-any-file.h"
#include "areadlink.h"
#include "yesno.h"
#include "selinux.h"

#if USE_XATTR
# include <attr/error_context.h>
# include <attr/libattr.h>
# include <stdarg.h>
# include "verror.h"
#endif

#if HAVE_LINUX_FALLOC_H
# include <linux/falloc.h>
#endif

/* See HAVE_FALLOCATE workaround when including this file.  */
#ifdef HAVE_LINUX_FS_H
# include <linux/fs.h>
#endif

#if !defined FICLONE && defined __linux__
# define FICLONE _IOW (0x94, 9, int)
#endif

#ifndef HAVE_FCHOWN
# define HAVE_FCHOWN false
# define fchown(fd, uid, gid) (-1)
#endif

#ifndef HAVE_LCHOWN
# define HAVE_LCHOWN false
# define lchown(name, uid, gid) chown (name, uid, gid)
#endif

#ifndef HAVE_MKFIFO
static int
rpl_mkfifo (char const *file, mode_t mode)
{
  errno = ENOTSUP;
  return -1;
}
# define mkfifo rpl_mkfifo
#endif

#ifndef USE_ACL
# define USE_ACL 0
#endif

#define SAME_OWNER(A, B) ((A).st_uid == (B).st_uid)
#define SAME_GROUP(A, B) ((A).st_gid == (B).st_gid)
#define SAME_OWNER_AND_GROUP(A, B) (SAME_OWNER (A, B) && SAME_GROUP (A, B))

/* LINK_FOLLOWS_SYMLINKS is tri-state; if it is -1, we don't know
   how link() behaves, so assume we can't hardlink symlinks in that case.  */
#if (defined HAVE_LINKAT && ! LINKAT_SYMLINK_NOTSUP) || ! LINK_FOLLOWS_SYMLINKS
# define CAN_HARDLINK_SYMLINKS 1
#else
# define CAN_HARDLINK_SYMLINKS 0
#endif

struct dir_list
{
  struct dir_list *parent;
  ino_t ino;
  dev_t dev;
};

/* Initial size of the cp.dest_info hash table.  */
#define DEST_INFO_INITIAL_CAPACITY 61

static bool copy_internal (char const *src_name, char const *dst_name,
                           bool new_dst, struct stat const *parent,
                           struct dir_list *ancestors,
                           const struct cp_options *x,
                           bool command_line_arg,
                           bool *first_dir_created_per_command_line_arg,
                           bool *copy_into_self,
                           bool *rename_succeeded);
static bool owner_failure_ok (struct cp_options const *x);

/* Pointers to the file names:  they're used in the diagnostic that is issued
   when we detect the user is trying to copy a directory into itself.  */
static char const *top_level_src_name;
static char const *top_level_dst_name;

/* Set the timestamp of symlink, FILE, to TIMESPEC.
   If this system lacks support for that, simply return 0.  */
static inline int
utimens_symlink (char const *file, struct timespec const *timespec)
{
  int err = lutimens (file, timespec);
  /* When configuring on a system with new headers and libraries, and
     running on one with a kernel that is old enough to lack the syscall,
     utimensat fails with ENOSYS.  Ignore that.  */
  if (err && errno == ENOSYS)
    err = 0;
  return err;
}

/* Attempt to punch a hole to avoid any permanent
   speculative preallocation on file systems such as XFS.
   Return values as per fallocate(2) except ENOSYS etc. are ignored.  */

static int
punch_hole (int fd, off_t offset, off_t length)
{
  int ret = 0;
/* +0 is to work around older <linux/fs.h> defining HAVE_FALLOCATE to empty.  */
#if HAVE_FALLOCATE + 0
# if defined FALLOC_FL_PUNCH_HOLE && defined FALLOC_FL_KEEP_SIZE
  ret = fallocate (fd, FALLOC_FL_PUNCH_HOLE | FALLOC_FL_KEEP_SIZE,
                   offset, length);
  if (ret < 0 && (is_ENOTSUP (errno) || errno == ENOSYS))
    ret = 0;
# endif
#endif
  return ret;
}

/* Create a hole at the end of a file,
   avoiding preallocation if requested.  */

static bool
create_hole (int fd, char const *name, bool punch_holes, off_t size)
{
  off_t file_end = lseek (fd, size, SEEK_CUR);

  if (file_end < 0)
    {
      error (0, errno, _("cannot lseek %s"), quoteaf (name));
      return false;
    }

  /* Some file systems (like XFS) preallocate when write extending a file.
     I.e., a previous write() may have preallocated extra space
     that the seek above will not discard.  A subsequent write() could
     then make this allocation permanent.  */
  if (punch_holes && punch_hole (fd, file_end - size, size) < 0)
    {
      error (0, errno, _("error deallocating %s"), quoteaf (name));
      return false;
    }

  return true;
}


/* Copy the regular file open on SRC_FD/SRC_NAME to DST_FD/DST_NAME,
   honoring the MAKE_HOLES setting and using the BUF_SIZE-byte buffer
   BUF for temporary storage.  Copy no more than MAX_N_READ bytes.
   Return true upon successful completion;
   print a diagnostic and return false upon error.
   Note that for best results, BUF should be "well"-aligned.
   BUF must have sizeof(uintptr_t)-1 bytes of additional space
   beyond BUF[BUF_SIZE-1].
   Set *LAST_WRITE_MADE_HOLE to true if the final operation on
   DEST_FD introduced a hole.  Set *TOTAL_N_READ to the number of
   bytes read.  */
static bool
sparse_copy (int src_fd, int dest_fd, char *buf, size_t buf_size,
             size_t hole_size, bool punch_holes,
             char const *src_name, char const *dst_name,
             uintmax_t max_n_read, off_t *total_n_read,
             bool *last_write_made_hole)
{
  *last_write_made_hole = false;
  *total_n_read = 0;
  bool make_hole = false;
  off_t psize = 0;

  while (max_n_read)
    {
      ssize_t n_read = read (src_fd, buf, MIN (max_n_read, buf_size));
      if (n_read < 0)
        {
          if (errno == EINTR)
            continue;
          error (0, errno, _("error reading %s"), quoteaf (src_name));
          return false;
        }
      if (n_read == 0)
        break;
      max_n_read -= n_read;
      *total_n_read += n_read;

      /* Loop over the input buffer in chunks of hole_size.  */
      size_t csize = hole_size ? hole_size : buf_size;
      char *cbuf = buf;
      char *pbuf = buf;

      while (n_read)
        {
          bool prev_hole = make_hole;
          csize = MIN (csize, n_read);

          if (hole_size && csize)
            make_hole = is_nul (cbuf, csize);

          bool transition = (make_hole != prev_hole) && psize;
          bool last_chunk = (n_read == csize && ! make_hole) || ! csize;

          if (transition || last_chunk)
            {
              if (! transition)
                psize += csize;

              if (! prev_hole)
                {
                  if (full_write (dest_fd, pbuf, psize) != psize)
                    {
                      error (0, errno, _("error writing %s"),
                             quoteaf (dst_name));
                      return false;
                    }
                }
              else
                {
                  if (! create_hole (dest_fd, dst_name, punch_holes, psize))
                    return false;
                }

              pbuf = cbuf;
              psize = csize;

              if (last_chunk)
                {
                  if (! csize)
                    n_read = 0; /* Finished processing buffer.  */

                  if (transition)
                    csize = 0;  /* Loop again to deal with last chunk.  */
                  else
                    psize = 0;  /* Reset for next read loop.  */
                }
            }
          else  /* Coalesce writes/seeks.  */
            {
              if (psize <= OFF_T_MAX - csize)
                psize += csize;
              else
                {
                  error (0, 0, _("overflow reading %s"), quoteaf (src_name));
                  return false;
                }
            }

          n_read -= csize;
          cbuf += csize;
        }

      *last_write_made_hole = make_hole;

      /* It's tempting to break early here upon a short read from
         a regular file.  That would save the final read syscall
         for each file.  Unfortunately that doesn't work for
         certain files in /proc or /sys with linux kernels.  */
    }

  /* Ensure a trailing hole is created, so that subsequent
     calls of sparse_copy() start at the correct offset.  */
  if (make_hole && ! create_hole (dest_fd, dst_name, punch_holes, psize))
    return false;
  else
    return true;
}

/* Perform the O(1) btrfs clone operation, if possible.
   Upon success, return 0.  Otherwise, return -1 and set errno.  */
static inline int
clone_file (int dest_fd, int src_fd)
{
#ifdef FICLONE
  return ioctl (dest_fd, FICLONE, src_fd);
#else
  (void) dest_fd;
  (void) src_fd;
  errno = ENOTSUP;
  return -1;
#endif
}

/* Write N_BYTES zero bytes to file descriptor FD.  Return true if successful.
   Upon write failure, set errno and return false.  */
static bool
write_zeros (int fd, off_t n_bytes)
{
  static char *zeros;
  static size_t nz = IO_BUFSIZE;

  /* Attempt to use a relatively large calloc'd source buffer for
     efficiency, but if that allocation fails, resort to a smaller
     statically allocated one.  */
  if (zeros == NULL)
    {
      static char fallback[1024];
      zeros = calloc (nz, 1);
      if (zeros == NULL)
        {
          zeros = fallback;
          nz = sizeof fallback;
        }
    }

  while (n_bytes)
    {
      size_t n = MIN (nz, n_bytes);
      if ((full_write (fd, zeros, n)) != n)
        return false;
      n_bytes -= n;
    }

  return true;
}

/* Perform an efficient extent copy, if possible.  This avoids
   the overhead of detecting holes in hole-introducing/preserving
   copy, and thus makes copying sparse files much more efficient.
   Upon a successful copy, return true.  If the initial extent scan
   fails, set *NORMAL_COPY_REQUIRED to true and return false.
   Upon any other failure, set *NORMAL_COPY_REQUIRED to false and
   return false.  */
static bool
extent_copy (int src_fd, int dest_fd, char *buf, size_t buf_size,
             size_t hole_size, off_t src_total_size,
             enum Sparse_type sparse_mode,
             char const *src_name, char const *dst_name,
             bool *require_normal_copy)
{
  struct extent_scan scan;
  off_t last_ext_start = 0;
  off_t last_ext_len = 0;

  /* Keep track of the output position.
     We may need this at the end, for a final ftruncate.  */
  off_t dest_pos = 0;

  extent_scan_init (src_fd, &scan);

  *require_normal_copy = false;
  bool wrote_hole_at_eof = true;
  do
    {
      bool ok = extent_scan_read (&scan);
      if (! ok)
        {
          if (scan.hit_final_extent)
            break;

          if (scan.initial_scan_failed)
            {
              *require_normal_copy = true;
              return false;
            }

          error (0, errno, _("%s: failed to get extents info"),
                 quotef (src_name));
          return false;
        }

      unsigned int i;
      bool empty_extent = false;
      for (i = 0; i < scan.ei_count || empty_extent; i++)
        {
          off_t ext_start;
          off_t ext_len;
          off_t ext_hole_size;

          if (i < scan.ei_count)
            {
              ext_start = scan.ext_info[i].ext_logical;
              ext_len = scan.ext_info[i].ext_length;
            }
          else /* empty extent at EOF.  */
            {
              i--;
              ext_start = last_ext_start + scan.ext_info[i].ext_length;
              ext_len = 0;
            }

          /* Truncate extent to EOF.  Extents starting after EOF are
             treated as zero length extents starting right after EOF.
             Generally this will trigger with an extent starting after
             src_total_size, and result in creating a hole or zeros until EOF.
             Though in a file in which extents have changed since src_total_size
             was determined, we might have an extent spanning that size,
             in which case we'll only copy data up to that size.  */
          if (src_total_size < ext_start + ext_len)
            {
              if (src_total_size < ext_start)
                ext_start = src_total_size;
              ext_len = src_total_size - ext_start;
            }

          ext_hole_size = ext_start - last_ext_start - last_ext_len;

          wrote_hole_at_eof = false;

          if (ext_hole_size)
            {
              if (lseek (src_fd, ext_start, SEEK_SET) < 0)
                {
                  error (0, errno, _("cannot lseek %s"), quoteaf (src_name));
                fail:
                  extent_scan_free (&scan);
                  return false;
                }

              if ((empty_extent && sparse_mode == SPARSE_ALWAYS)
                  || (!empty_extent && sparse_mode != SPARSE_NEVER))
                {
                  if (! create_hole (dest_fd, dst_name,
                                     sparse_mode == SPARSE_ALWAYS,
                                     ext_hole_size))
                    goto fail;
                  wrote_hole_at_eof = true;
                }
              else
                {
                  /* When not inducing holes and when there is a hole between
                     the end of the previous extent and the beginning of the
                     current one, write zeros to the destination file.  */
                  off_t nzeros = ext_hole_size;
                  if (empty_extent)
                    nzeros = MIN (src_total_size - dest_pos, ext_hole_size);

                  if (! write_zeros (dest_fd, nzeros))
                    {
                      error (0, errno, _("%s: write failed"),
                             quotef (dst_name));
                      goto fail;
                    }

                  dest_pos = MIN (src_total_size, ext_start);
                }
            }

          last_ext_start = ext_start;

          /* Treat an unwritten but allocated extent much like a hole.
             I.e., don't read, but don't convert to a hole in the destination,
             unless SPARSE_ALWAYS.  */
          /* For now, do not treat FIEMAP_EXTENT_UNWRITTEN specially,
             because that (in combination with no sync) would lead to data
             loss at least on XFS and ext4 when using 2.6.39-rc3 kernels.  */
          if (0 && (scan.ext_info[i].ext_flags & FIEMAP_EXTENT_UNWRITTEN))
            {
              empty_extent = true;
              last_ext_len = 0;
              if (ext_len == 0) /* The last extent is empty and processed.  */
                empty_extent = false;
            }
          else
            {
              off_t n_read;
              empty_extent = false;
              last_ext_len = ext_len;
              bool read_hole;

              if ( ! sparse_copy (src_fd, dest_fd, buf, buf_size,
                                  sparse_mode == SPARSE_ALWAYS ? hole_size: 0,
                                  true, src_name, dst_name, ext_len, &n_read,
                                  &read_hole))
                goto fail;

              dest_pos = ext_start + n_read;
              if (n_read)
                wrote_hole_at_eof = read_hole;
            }

          /* If the file ends with unwritten extents not accounted for in the
             size, then skip processing them, and the associated redundant
             read() calls which will always return 0.  We will need to
             remove this when we add fallocate() so that we can maintain
             extents beyond the apparent size.  */
          if (dest_pos == src_total_size)
            {
              scan.hit_final_extent = true;
              break;
            }
        }

      /* Release the space allocated to scan->ext_info.  */
      extent_scan_free (&scan);

    }
  while (! scan.hit_final_extent);

  /* When the source file ends with a hole, we have to do a little more work,
     since the above copied only up to and including the final extent.
     In order to complete the copy, we may have to insert a hole or write
     zeros in the destination corresponding to the source file's hole-at-EOF.

     In addition, if the final extent was a block of zeros at EOF and we've
     just converted them to a hole in the destination, we must call ftruncate
     here in order to record the proper length in the destination.  */
  if ((dest_pos < src_total_size || wrote_hole_at_eof)
      && (sparse_mode != SPARSE_NEVER
          ? ftruncate (dest_fd, src_total_size)
          : ! write_zeros (dest_fd, src_total_size - dest_pos)))
    {
      error (0, errno, _("failed to extend %s"), quoteaf (dst_name));
      return false;
    }

  if (sparse_mode == SPARSE_ALWAYS && dest_pos < src_total_size
      && punch_hole (dest_fd, dest_pos, src_total_size - dest_pos) < 0)
    {
      error (0, errno, _("error deallocating %s"), quoteaf (dst_name));
      return false;
    }

  return true;
}

/* FIXME: describe */
/* FIXME: rewrite this to use a hash table so we avoid the quadratic
   performance hit that's probably noticeable only on trees deeper
   than a few hundred levels.  See use of active_dir_map in remove.c  */

static bool _GL_ATTRIBUTE_PURE
is_ancestor (const struct stat *sb, const struct dir_list *ancestors)
{
  while (ancestors != 0)
    {
      if (ancestors->ino == sb->st_ino && ancestors->dev == sb->st_dev)
        return true;
      ancestors = ancestors->parent;
    }
  return false;
}

static bool
errno_unsupported (int err)
{
  return err == ENOTSUP || err == ENODATA;
}

#if USE_XATTR
static void
copy_attr_error (struct error_context *ctx _GL_UNUSED,
                 char const *fmt, ...)
{
  if (!errno_unsupported (errno))
    {
      int err = errno;
      va_list ap;

      /* use verror module to print error message */
      va_start (ap, fmt);
      verror (0, err, fmt, ap);
      va_end (ap);
    }
}

static void
copy_attr_allerror (struct error_context *ctx _GL_UNUSED,
                 char const *fmt, ...)
{
  int err = errno;
  va_list ap;

  /* use verror module to print error message */
  va_start (ap, fmt);
  verror (0, err, fmt, ap);
  va_end (ap);
}

static char const *
copy_attr_quote (struct error_context *ctx _GL_UNUSED, char const *str)
{
  return quoteaf (str);
}

static void
copy_attr_free (struct error_context *ctx _GL_UNUSED,
                char const *str _GL_UNUSED)
{
}

/* Exclude SELinux extended attributes that are otherwise handled,
   and are problematic to copy again.  Also honor attributes
   configured for exclusion in /etc/xattr.conf.
   FIXME: Should we handle POSIX ACLs similarly?
   Return zero to skip.  */
static int
check_selinux_attr (const char *name, struct error_context *ctx)
{
  return STRNCMP_LIT (name, "security.selinux")
         && attr_copy_check_permissions (name, ctx);
}

/* If positive SRC_FD and DST_FD descriptors are passed,
   then copy by fd, otherwise copy by name.  */

static bool
copy_attr (char const *src_path, int src_fd,
           char const *dst_path, int dst_fd, struct cp_options const *x)
{
  int ret;
  bool all_errors = (!x->data_copy_required || x->require_preserve_xattr);
  bool some_errors = (!all_errors && !x->reduce_diagnostics);
  bool selinux_done = (x->preserve_security_context || x->set_security_context);
  struct error_context ctx =
  {
    .error = all_errors ? copy_attr_allerror : copy_attr_error,
    .quote = copy_attr_quote,
    .quote_free = copy_attr_free
  };
  if (0 <= src_fd && 0 <= dst_fd)
    ret = attr_copy_fd (src_path, src_fd, dst_path, dst_fd,
                        selinux_done ? check_selinux_attr : NULL,
                        (all_errors || some_errors ? &ctx : NULL));
  else
    ret = attr_copy_file (src_path, dst_path,
                          selinux_done ? check_selinux_attr : NULL,
                          (all_errors || some_errors ? &ctx : NULL));

  return ret == 0;
}
#else /* USE_XATTR */

static bool
copy_attr (char const *src_path _GL_UNUSED,
           int src_fd _GL_UNUSED,
           char const *dst_path _GL_UNUSED,
           int dst_fd _GL_UNUSED,
           struct cp_options const *x _GL_UNUSED)
{
  return true;
}
#endif /* USE_XATTR */

/* Read the contents of the directory SRC_NAME_IN, and recursively
   copy the contents to DST_NAME_IN.  NEW_DST is true if
   DST_NAME_IN is a directory that was created previously in the
   recursion.   SRC_SB and ANCESTORS describe SRC_NAME_IN.
   Set *COPY_INTO_SELF if SRC_NAME_IN is a parent of
   (or the same as) DST_NAME_IN; otherwise, clear it.
   Propagate *FIRST_DIR_CREATED_PER_COMMAND_LINE_ARG from
   caller to each invocation of copy_internal.  Be careful to
   pass the address of a temporary, and to update
   *FIRST_DIR_CREATED_PER_COMMAND_LINE_ARG only upon completion.
   Return true if successful.  */

static bool
copy_dir (char const *src_name_in, char const *dst_name_in, bool new_dst,
          const struct stat *src_sb, struct dir_list *ancestors,
          const struct cp_options *x,
          bool *first_dir_created_per_command_line_arg,
          bool *copy_into_self)
{
  char *name_space;
  char *namep;
  struct cp_options non_command_line_options = *x;
  bool ok = true;

  name_space = savedir (src_name_in, SAVEDIR_SORT_FASTREAD);
  if (name_space == NULL)
    {
      /* This diagnostic is a bit vague because savedir can fail in
         several different ways.  */
      error (0, errno, _("cannot access %s"), quoteaf (src_name_in));
      return false;
    }

  /* For cp's -H option, dereference command line arguments, but do not
     dereference symlinks that are found via recursive traversal.  */
  if (x->dereference == DEREF_COMMAND_LINE_ARGUMENTS)
    non_command_line_options.dereference = DEREF_NEVER;

  bool new_first_dir_created = false;
  namep = name_space;
  while (*namep != '\0')
    {
      bool local_copy_into_self;
      char *src_name = file_name_concat (src_name_in, namep, NULL);
      char *dst_name = file_name_concat (dst_name_in, namep, NULL);
      bool first_dir_created = *first_dir_created_per_command_line_arg;

      ok &= copy_internal (src_name, dst_name, new_dst, src_sb,
                           ancestors, &non_command_line_options, false,
                           &first_dir_created,
                           &local_copy_into_self, NULL);
      *copy_into_self |= local_copy_into_self;

      free (dst_name);
      free (src_name);

      /* If we're copying into self, there's no point in continuing,
         and in fact, that would even infloop, now that we record only
         the first created directory per command line argument.  */
      if (local_copy_into_self)
        break;

      new_first_dir_created |= first_dir_created;
      namep += strlen (namep) + 1;
    }
  free (name_space);
  *first_dir_created_per_command_line_arg = new_first_dir_created;

  return ok;
}

/* Set the owner and owning group of DEST_DESC to the st_uid and
   st_gid fields of SRC_SB.  If DEST_DESC is undefined (-1), set
   the owner and owning group of DST_NAME instead; for
   safety prefer lchown if the system supports it since no
   symbolic links should be involved.  DEST_DESC must
   refer to the same file as DEST_NAME if defined.
   Upon failure to set both UID and GID, try to set only the GID.
   NEW_DST is true if the file was newly created; otherwise,
   DST_SB is the status of the destination.
   Return 1 if the initial syscall succeeds, 0 if it fails but it's OK
   not to preserve ownership, -1 otherwise.  */

static int
set_owner (const struct cp_options *x, char const *dst_name, int dest_desc,
           struct stat const *src_sb, bool new_dst,
           struct stat const *dst_sb)
{
  uid_t uid = src_sb->st_uid;
  gid_t gid = src_sb->st_gid;

  /* Naively changing the ownership of an already-existing file before
     changing its permissions would create a window of vulnerability if
     the file's old permissions are too generous for the new owner and
     group.  Avoid the window by first changing to a restrictive
     temporary mode if necessary.  */

  if (!new_dst && (x->preserve_mode || x->move_mode || x->set_mode))
    {
      mode_t old_mode = dst_sb->st_mode;
      mode_t new_mode =
        (x->preserve_mode || x->move_mode ? src_sb->st_mode : x->mode);
      mode_t restrictive_temp_mode = old_mode & new_mode & S_IRWXU;

      if ((USE_ACL
           || (old_mode & CHMOD_MODE_BITS
               & (~new_mode | S_ISUID | S_ISGID | S_ISVTX)))
          && qset_acl (dst_name, dest_desc, restrictive_temp_mode) != 0)
        {
          if (! owner_failure_ok (x))
            error (0, errno, _("clearing permissions for %s"),
                   quoteaf (dst_name));
          return -x->require_preserve;
        }
    }

  if (HAVE_FCHOWN && dest_desc != -1)
    {
      if (fchown (dest_desc, uid, gid) == 0)
        return 1;
      if (errno == EPERM || errno == EINVAL)
        {
          /* We've failed to set *both*.  Now, try to set just the group
             ID, but ignore any failure here, and don't change errno.  */
          int saved_errno = errno;
          ignore_value (fchown (dest_desc, -1, gid));
          errno = saved_errno;
        }
    }
  else
    {
      if (lchown (dst_name, uid, gid) == 0)
        return 1;
      if (errno == EPERM || errno == EINVAL)
        {
          /* We've failed to set *both*.  Now, try to set just the group
             ID, but ignore any failure here, and don't change errno.  */
          int saved_errno = errno;
          ignore_value (lchown (dst_name, -1, gid));
          errno = saved_errno;
        }
    }

  if (! chown_failure_ok (x))
    {
      error (0, errno, _("failed to preserve ownership for %s"),
             quoteaf (dst_name));
      if (x->require_preserve)
        return -1;
    }

  return 0;
}

/* Set the st_author field of DEST_DESC to the st_author field of
   SRC_SB. If DEST_DESC is undefined (-1), set the st_author field
   of DST_NAME instead.  DEST_DESC must refer to the same file as
   DEST_NAME if defined.  */

static void
set_author (const char *dst_name, int dest_desc, const struct stat *src_sb)
{
#if HAVE_STRUCT_STAT_ST_AUTHOR
  /* FIXME: Modify the following code so that it does not
     follow symbolic links.  */

  /* Preserve the st_author field.  */
  file_t file = (dest_desc < 0
                 ? file_name_lookup (dst_name, 0, 0)
                 : getdport (dest_desc));
  if (file == MACH_PORT_NULL)
    error (0, errno, _("failed to lookup file %s"), quoteaf (dst_name));
  else
    {
      error_t err = file_chauthor (file, src_sb->st_author);
      if (err)
        error (0, err, _("failed to preserve authorship for %s"),
               quoteaf (dst_name));
      mach_port_deallocate (mach_task_self (), file);
    }
#else
  (void) dst_name;
  (void) dest_desc;
  (void) src_sb;
#endif
}

/* Set the default security context for the process.  New files will
   have this security context set.  Also existing files can have their
   context adjusted based on this process context, by
   set_file_security_ctx() called with PROCESS_LOCAL=true.
   This should be called before files are created so there is no race
   where a file may be present without an appropriate security context.
   Based on CP_OPTIONS, diagnose warnings and fail when appropriate.
   Return FALSE on failure, TRUE on success.  */

bool
set_process_security_ctx (char const *src_name, char const *dst_name,
                          mode_t mode, bool new_dst, const struct cp_options *x)
{
  if (x->preserve_security_context)
    {
      /* Set the default context for the process to match the source.  */
      bool all_errors = !x->data_copy_required || x->require_preserve_context;
      bool some_errors = !all_errors && !x->reduce_diagnostics;
      char *con;

      if (0 <= lgetfilecon (src_name, &con))
        {
          if (setfscreatecon (con) < 0)
            {
              if (all_errors || (some_errors && !errno_unsupported (errno)))
                error (0, errno,
                       _("failed to set default file creation context to %s"),
                       quote (con));
              if (x->require_preserve_context)
                {
                  freecon (con);
                  return false;
                }
            }
          freecon (con);
        }
      else
        {
          if (all_errors || (some_errors && !errno_unsupported (errno)))
            {
              error (0, errno,
                     _("failed to get security context of %s"),
                     quoteaf (src_name));
            }
          if (x->require_preserve_context)
            return false;
        }
    }
  else if (x->set_security_context)
    {
      /* With -Z, adjust the default context for the process
         to have the type component adjusted as per the destination path.  */
      if (new_dst && defaultcon (dst_name, mode) < 0
          && ! ignorable_ctx_err (errno))
        {
          error (0, errno,
                 _("failed to set default file creation context for %s"),
                 quoteaf (dst_name));
        }
    }

  return true;
}

/* Reset the security context of DST_NAME, to that already set
   as the process default if PROCESS_LOCAL is true.  Otherwise
   adjust the type component of DST_NAME's security context as
   per the system default for that path.  Issue warnings upon
   failure, when allowed by various settings in CP_OPTIONS.
   Return FALSE on failure, TRUE on success.  */

bool
set_file_security_ctx (char const *dst_name, bool process_local,
                       bool recurse, const struct cp_options *x)
{
  bool all_errors = (!x->data_copy_required
                     || x->require_preserve_context);
  bool some_errors = !all_errors && !x->reduce_diagnostics;

  if (! restorecon (dst_name, recurse, process_local))
    {
      if (all_errors || (some_errors && !errno_unsupported (errno)))
        error (0, errno, _("failed to set the security context of %s"),
               quoteaf_n (0, dst_name));
      return false;
    }

  return true;
}

/* Change the file mode bits of the file identified by DESC or NAME to MODE.
   Use DESC if DESC is valid and fchmod is available, NAME otherwise.  */

static int
fchmod_or_lchmod (int desc, char const *name, mode_t mode)
{
#if HAVE_FCHMOD
  if (0 <= desc)
    return fchmod (desc, mode);
#endif
  return lchmod (name, mode);
}

#ifndef HAVE_STRUCT_STAT_ST_BLOCKS
# define HAVE_STRUCT_STAT_ST_BLOCKS 0
#endif

/* Use a heuristic to determine whether stat buffer SB comes from a file
   with sparse blocks.  If the file has fewer blocks than would normally
   be needed for a file of its size, then at least one of the blocks in
   the file is a hole.  In that case, return true.  */
static bool
is_probably_sparse (struct stat const *sb)
{
  return (HAVE_STRUCT_STAT_ST_BLOCKS
          && S_ISREG (sb->st_mode)
          && ST_NBLOCKS (*sb) < sb->st_size / ST_NBLOCKSIZE);
}


/* Copy a regular file from SRC_NAME to DST_NAME.
   If the source file contains holes, copies holes and blocks of zeros
   in the source file as holes in the destination file.
   (Holes are read as zeroes by the 'read' system call.)
   When creating the destination, use DST_MODE & ~OMITTED_PERMISSIONS
   as the third argument in the call to open, adding
   OMITTED_PERMISSIONS after copying as needed.
   X provides many option settings.
   Return true if successful.
   *NEW_DST is as in copy_internal.
   SRC_SB is the result of calling XSTAT (aka stat) on SRC_NAME.  */

static bool
copy_reg (char const *src_name, char const *dst_name,
          const struct cp_options *x,
          mode_t dst_mode, mode_t omitted_permissions, bool *new_dst,
          struct stat const *src_sb)
{
  char *buf;
  char *buf_alloc = NULL;
  char *name_alloc = NULL;
  int dest_desc;
  int dest_errno;
  int source_desc;
  mode_t src_mode = src_sb->st_mode;
  struct stat sb;
  struct stat src_open_sb;
  bool return_val = true;
  bool data_copy_required = x->data_copy_required;

  source_desc = open (src_name,
                      (O_RDONLY | O_BINARY
                       | (x->dereference == DEREF_NEVER ? O_NOFOLLOW : 0)));
  if (source_desc < 0)
    {
      error (0, errno, _("cannot open %s for reading"), quoteaf (src_name));
      return false;
    }

  if (fstat (source_desc, &src_open_sb) != 0)
    {
      error (0, errno, _("cannot fstat %s"), quoteaf (src_name));
      return_val = false;
      goto close_src_desc;
    }

  /* Compare the source dev/ino from the open file to the incoming,
     saved ones obtained via a previous call to stat.  */
  if (! SAME_INODE (*src_sb, src_open_sb))
    {
      error (0, 0,
             _("skipping file %s, as it was replaced while being copied"),
             quoteaf (src_name));
      return_val = false;
      goto close_src_desc;
    }

  /* The semantics of the following open calls are mandated
     by the specs for both cp and mv.  */
  if (! *new_dst)
    {
      int open_flags =
        O_WRONLY | O_BINARY | (x->data_copy_required ? O_TRUNC : 0);
      dest_desc = open (dst_name, open_flags);
      dest_errno = errno;

      /* When using cp --preserve=context to copy to an existing destination,
         reset the context as per the default context, which has already been
         set according to the src.
         When using the mutually exclusive -Z option, then adjust the type of
         the existing context according to the system default for the dest.
         Note we set the context here, _after_ the file is opened, lest the
         new context disallow that.  */
      if ((x->set_security_context || x->preserve_security_context)
          && 0 <= dest_desc)
        {
          if (! set_file_security_ctx (dst_name, x->preserve_security_context,
                                       false, x))
            {
              if (x->require_preserve_context)
                {
                  return_val = false;
                  goto close_src_and_dst_desc;
                }
            }
        }

      if (dest_desc < 0 && x->unlink_dest_after_failed_open)
        {
          if (unlink (dst_name) != 0)
            {
              error (0, errno, _("cannot remove %s"), quoteaf (dst_name));
              return_val = false;
              goto close_src_desc;
            }
          if (x->verbose)
            printf (_("removed %s\n\r"), quoteaf (dst_name));

          /* Tell caller that the destination file was unlinked.  */
          *new_dst = true;

          /* Ensure there is no race where a file may be left without
             an appropriate security context.  */
          if (x->set_security_context)
            {
              if (! set_process_security_ctx (src_name, dst_name, dst_mode,
                                              *new_dst, x))
                {
                  return_val = false;
                  goto close_src_desc;
                }
            }
        }
    }

  if (*new_dst)
    {
    open_with_O_CREAT:;

      int open_flags = O_WRONLY | O_CREAT | O_BINARY;
      dest_desc = open (dst_name, open_flags | O_EXCL,
                        dst_mode & ~omitted_permissions);
      dest_errno = errno;

      /* When trying to copy through a dangling destination symlink,
         the above open fails with EEXIST.  If that happens, and
         lstat'ing the DST_NAME shows that it is a symlink, then we
         have a problem: trying to resolve this dangling symlink to
         a directory/destination-entry pair is fundamentally racy,
         so punt.  If x->open_dangling_dest_symlink is set (cp sets
         that when POSIXLY_CORRECT is set in the environment), simply
         call open again, but without O_EXCL (potentially dangerous).
         If not, fail with a diagnostic.  These shenanigans are necessary
         only when copying, i.e., not in move_mode.  */
      if (dest_desc < 0 && dest_errno == EEXIST && ! x->move_mode)
        {
          struct stat dangling_link_sb;
          if (lstat (dst_name, &dangling_link_sb) == 0
              && S_ISLNK (dangling_link_sb.st_mode))
            {
              if (x->open_dangling_dest_symlink)
                {
                  dest_desc = open (dst_name, open_flags,
                                    dst_mode & ~omitted_permissions);
                  dest_errno = errno;
                }
              else
                {
                  error (0, 0, _("not writing through dangling symlink %s"),
                         quoteaf (dst_name));
                  return_val = false;
                  goto close_src_desc;
                }
            }
        }

      /* Improve quality of diagnostic when a nonexistent dst_name
         ends in a slash and open fails with errno == EISDIR.  */
      if (dest_desc < 0 && dest_errno == EISDIR
          && *dst_name && dst_name[strlen (dst_name) - 1] == '/')
        dest_errno = ENOTDIR;
    }
  else
    {
      omitted_permissions = 0;
    }

  if (dest_desc < 0)
    {
      /* If we've just failed due to ENOENT for an ostensibly preexisting
         destination (*new_dst was 0), that's a bit of a contradiction/race:
         the prior stat/lstat said the file existed (*new_dst was 0), yet
         the subsequent open-existing-file failed with ENOENT.  With NFS,
         the race window is wider still, since its meta-data caching tends
         to make the stat succeed for a just-removed remote file, while the
         more-definitive initial open call will fail with ENOENT.  When this
         situation arises, we attempt to open again, but this time with
         O_CREAT.  Do this only when not in move-mode, since when handling
         a cross-device move, we must never open an existing destination.  */
      if (dest_errno == ENOENT && ! *new_dst && ! x->move_mode)
        {
          *new_dst = 1;
          goto open_with_O_CREAT;
        }

      /* Otherwise, it's an error.  */
      error (0, dest_errno, _("cannot create regular file %s"),
             quoteaf (dst_name));
      return_val = false;
      goto close_src_desc;
    }

  if (fstat (dest_desc, &sb) != 0)
    {
      error (0, errno, _("cannot fstat %s"), quoteaf (dst_name));
      return_val = false;
      goto close_src_and_dst_desc;
    }

  /* --attributes-only overrides --reflink.  */
  if (data_copy_required && x->reflink_mode)
    {
      bool clone_ok = clone_file (dest_desc, source_desc) == 0;
      if (clone_ok || x->reflink_mode == REFLINK_ALWAYS)
        {
          if (!clone_ok)
            {
              error (0, errno, _("failed to clone %s from %s"),
                     quoteaf_n (0, dst_name), quoteaf_n (1, src_name));
              return_val = false;
              goto close_src_and_dst_desc;
            }
          data_copy_required = false;
        }
    }

  if (data_copy_required)
    {
      /* Choose a suitable buffer size; it may be adjusted later.  */
      size_t buf_alignment = getpagesize ();
      size_t buf_size = io_blksize (sb);
      size_t hole_size = ST_BLKSIZE (sb);

      fdadvise (source_desc, 0, 0, FADVISE_SEQUENTIAL);

      /* Deal with sparse files.  */
      bool make_holes = false;
      bool sparse_src = is_probably_sparse (&src_open_sb);

      if (S_ISREG (sb.st_mode))
        {
          /* Even with --sparse=always, try to create holes only
             if the destination is a regular file.  */
          if (x->sparse_mode == SPARSE_ALWAYS)
            make_holes = true;

          /* Use a heuristic to determine whether SRC_NAME contains any sparse
             blocks.  If the file has fewer blocks than would normally be
             needed for a file of its size, then at least one of the blocks in
             the file is a hole.  */
          if (x->sparse_mode == SPARSE_AUTO && sparse_src)
            make_holes = true;
        }

      /* If not making a sparse file, try to use a more-efficient
         buffer size.  */
      if (! make_holes)
        {
          /* Compute the least common multiple of the input and output
             buffer sizes, adjusting for outlandish values.  */
          size_t blcm_max = MIN (SIZE_MAX, SSIZE_MAX) - buf_alignment;
          size_t blcm = buffer_lcm (io_blksize (src_open_sb), buf_size,
                                    blcm_max);

          /* Do not bother with a buffer larger than the input file, plus one
             byte to make sure the file has not grown while reading it.  */
          if (S_ISREG (src_open_sb.st_mode) && src_open_sb.st_size < buf_size)
            buf_size = src_open_sb.st_size + 1;

          /* However, stick with a block size that is a positive multiple of
             blcm, overriding the above adjustments.  Watch out for
             overflow.  */
          buf_size += blcm - 1;
          buf_size -= buf_size % blcm;
          if (buf_size == 0 || blcm_max < buf_size)
            buf_size = blcm;
        }

      buf_alloc = xmalloc (buf_size + buf_alignment);
      buf = ptr_align (buf_alloc, buf_alignment);

      if (sparse_src)
        {
          bool normal_copy_required;

          /* Perform an efficient extent-based copy, falling back to the
             standard copy only if the initial extent scan fails.  If the
             '--sparse=never' option is specified, write all data but use
             any extents to read more efficiently.  */
          if (extent_copy (source_desc, dest_desc, buf, buf_size, hole_size,
                           src_open_sb.st_size,
                           make_holes ? x->sparse_mode : SPARSE_NEVER,
                           src_name, dst_name, &normal_copy_required))
            goto preserve_metadata;

          if (! normal_copy_required)
            {
              return_val = false;
              goto close_src_and_dst_desc;
            }
        }

      off_t n_read;
      bool wrote_hole_at_eof;
      if (! sparse_copy (source_desc, dest_desc, buf, buf_size,
                         make_holes ? hole_size : 0,
                         x->sparse_mode == SPARSE_ALWAYS, src_name, dst_name,
                         UINTMAX_MAX, &n_read,
                         &wrote_hole_at_eof))
        {
          return_val = false;
          goto close_src_and_dst_desc;
        }
      else if (wrote_hole_at_eof && ftruncate (dest_desc, n_read) < 0)
        {
          error (0, errno, _("failed to extend %s"), quoteaf (dst_name));
          return_val = false;
          goto close_src_and_dst_desc;
        }
    }

preserve_metadata:
  if (x->preserve_timestamps)
    {
      struct timespec timespec[2];
      timespec[0] = get_stat_atime (src_sb);
      timespec[1] = get_stat_mtime (src_sb);

      if (fdutimens (dest_desc, dst_name, timespec) != 0)
        {
          error (0, errno, _("preserving times for %s"), quoteaf (dst_name));
          if (x->require_preserve)
            {
              return_val = false;
              goto close_src_and_dst_desc;
            }
        }
    }

  /* Set ownership before xattrs as changing owners will
     clear capabilities.  */
  if (x->preserve_ownership && ! SAME_OWNER_AND_GROUP (*src_sb, sb))
    {
      switch (set_owner (x, dst_name, dest_desc, src_sb, *new_dst, &sb))
        {
        case -1:
          return_val = false;
          goto close_src_and_dst_desc;

        case 0:
          src_mode &= ~ (S_ISUID | S_ISGID | S_ISVTX);
          break;
        }
    }

  /* To allow copying xattrs on read-only files, temporarily chmod u+rw.
     This workaround is required as an inode permission check is done
     by xattr_permission() in fs/xattr.c of the GNU/Linux kernel tree.  */
  if (x->preserve_xattr)
    {
      bool access_changed = false;

      if (!(sb.st_mode & S_IWUSR) && geteuid () != ROOT_UID)
        access_changed = fchmod_or_lchmod (dest_desc, dst_name, 0600) == 0;

      if (!copy_attr (src_name, source_desc, dst_name, dest_desc, x)
          && x->require_preserve_xattr)
        return_val = false;

      if (access_changed)
        fchmod_or_lchmod (dest_desc, dst_name, dst_mode & ~omitted_permissions);
    }

  set_author (dst_name, dest_desc, src_sb);

  if (x->preserve_mode || x->move_mode)
    {
      if (copy_acl (src_name, source_desc, dst_name, dest_desc, src_mode) != 0
          && x->require_preserve)
        return_val = false;
    }
  else if (x->set_mode)
    {
      if (set_acl (dst_name, dest_desc, x->mode) != 0)
        return_val = false;
    }
  else if (x->explicit_no_preserve_mode)
    {
      if (set_acl (dst_name, dest_desc, 0666 & ~cached_umask ()) != 0)
        return_val = false;
    }
  else if (omitted_permissions)
    {
      omitted_permissions &= ~ cached_umask ();
      if (omitted_permissions
          && fchmod_or_lchmod (dest_desc, dst_name, dst_mode) != 0)
        {
          error (0, errno, _("preserving permissions for %s"),
                 quoteaf (dst_name));
          if (x->require_preserve)
            return_val = false;
        }
    }

close_src_and_dst_desc:
  if (close (dest_desc) < 0)
    {
      error (0, errno, _("failed to close %s"), quoteaf (dst_name));
      return_val = false;
    }
close_src_desc:
  if (close (source_desc) < 0)
    {
      error (0, errno, _("failed to close %s"), quoteaf (src_name));
      return_val = false;
    }

  free (buf_alloc);
  free (name_alloc);
  return return_val;
}

/* Return true if it's ok that the source and destination
   files are the 'same' by some measure.  The goal is to avoid
   making the 'copy' operation remove both copies of the file
   in that case, while still allowing the user to e.g., move or
   copy a regular file onto a symlink that points to it.
   Try to minimize the cost of this function in the common case.
   Set *RETURN_NOW if we've determined that the caller has no more
   work to do and should return successfully, right away.  */

static bool
same_file_ok (char const *src_name, struct stat const *src_sb,
              char const *dst_name, struct stat const *dst_sb,
              const struct cp_options *x, bool *return_now)
{
  const struct stat *src_sb_link;
  const struct stat *dst_sb_link;
  struct stat tmp_dst_sb;
  struct stat tmp_src_sb;

  bool same_link;
  bool same = SAME_INODE (*src_sb, *dst_sb);

  *return_now = false;

  /* FIXME: this should (at the very least) be moved into the following
     if-block.  More likely, it should be removed, because it inhibits
     making backups.  But removing it will result in a change in behavior
     that will probably have to be documented -- and tests will have to
     be updated.  */
  if (same && x->hard_link)
    {
      *return_now = true;
      return true;
    }

  if (x->dereference == DEREF_NEVER)
    {
      same_link = same;

      /* If both the source and destination files are symlinks (and we'll
         know this here IFF preserving symlinks), then it's usually ok
         when they are distinct.  */
      if (S_ISLNK (src_sb->st_mode) && S_ISLNK (dst_sb->st_mode))
        {
          bool sn = same_name (src_name, dst_name);
          if ( ! sn)
            {
              /* It's fine when we're making any type of backup.  */
              if (x->backup_type != no_backups)
                return true;

              /* Here we have two symlinks that are hard-linked together,
                 and we're not making backups.  In this unusual case, simply
                 returning true would lead to mv calling "rename(A,B)",
                 which would do nothing and return 0.  */
              if (same_link)
                {
                  *return_now = true;
                  return ! x->move_mode;
                }
            }

          return ! sn;
        }

      src_sb_link = src_sb;
      dst_sb_link = dst_sb;
    }
  else
    {
      if (!same)
        return true;

      if (lstat (dst_name, &tmp_dst_sb) != 0
          || lstat (src_name, &tmp_src_sb) != 0)
        return true;

      src_sb_link = &tmp_src_sb;
      dst_sb_link = &tmp_dst_sb;

      same_link = SAME_INODE (*src_sb_link, *dst_sb_link);

      /* If both are symlinks, then it's ok, but only if the destination
         will be unlinked before being opened.  This is like the test
         above, but with the addition of the unlink_dest_before_opening
         conjunct because otherwise, with two symlinks to the same target,
         we'd end up truncating the source file.  */
      if (S_ISLNK (src_sb_link->st_mode) && S_ISLNK (dst_sb_link->st_mode)
          && x->unlink_dest_before_opening)
        return true;
    }

  /* The backup code ensures there's a copy, so it's usually ok to
     remove any destination file.  One exception is when both
     source and destination are the same directory entry.  In that
     case, moving the destination file aside (in making the backup)
     would also rename the source file and result in an error.  */
  if (x->backup_type != no_backups)
    {
      if (!same_link)
        {
          /* In copy mode when dereferencing symlinks, if the source is a
             symlink and the dest is not, then backing up the destination
             (moving it aside) would make it a dangling symlink, and the
             subsequent attempt to open it in copy_reg would fail with
             a misleading diagnostic.  Avoid that by returning zero in
             that case so the caller can make cp (or mv when it has to
             resort to reading the source file) fail now.  */

          /* FIXME-note: even with the following kludge, we can still provoke
             the offending diagnostic.  It's just a little harder to do :-)
             $ rm -f a b c; touch c; ln -s c b; ln -s b a; cp -b a b
             cp: cannot open 'a' for reading: No such file or directory
             That's misleading, since a subsequent 'ls' shows that 'a'
             is still there.
             One solution would be to open the source file *before* moving
             aside the destination, but that'd involve a big rewrite. */
          if ( ! x->move_mode
               && x->dereference != DEREF_NEVER
               && S_ISLNK (src_sb_link->st_mode)
               && ! S_ISLNK (dst_sb_link->st_mode))
            return false;

          return true;
        }

      /* FIXME: What about case insensitive file systems ?  */
      return ! same_name (src_name, dst_name);
    }

#if 0
  /* FIXME: use or remove */

  /* If we're making a backup, we'll detect the problem case in
     copy_reg because SRC_NAME will no longer exist.  Allowing
     the test to be deferred lets cp do some useful things.
     But when creating hardlinks and SRC_NAME is a symlink
     but DST_NAME is not we must test anyway.  */
  if (x->hard_link
      || !S_ISLNK (src_sb_link->st_mode)
      || S_ISLNK (dst_sb_link->st_mode))
    return true;

  if (x->dereference != DEREF_NEVER)
    return true;
#endif

  if (x->move_mode || x->unlink_dest_before_opening)
    {
      /* They may refer to the same file if we're in move mode and the
         target is a symlink.  That is ok, since we remove any existing
         destination file before opening it -- via 'rename' if they're on
         the same file system, via 'unlink (DST_NAME)' otherwise.  */
      if (S_ISLNK (dst_sb_link->st_mode))
        return true;

      /* It's not ok if they're distinct hard links to the same file as
         this causes a race condition and we may lose data in this case.  */
      if (same_link
          && 1 < dst_sb_link->st_nlink
          && ! same_name (src_name, dst_name))
        return ! x->move_mode;
    }

  /* If neither is a symlink, then it's ok as long as they aren't
     hard links to the same file.  */
  if (!S_ISLNK (src_sb_link->st_mode) && !S_ISLNK (dst_sb_link->st_mode))
    {
      if (!SAME_INODE (*src_sb_link, *dst_sb_link))
        return true;

      /* If they are the same file, it's ok if we're making hard links.  */
      if (x->hard_link)
        {
          *return_now = true;
          return true;
        }
    }

  /* At this point, it is normally an error (data loss) to move a symlink
     onto its referent, but in at least one narrow case, it is not:
     In move mode, when
     1) src is a symlink,
     2) dest has a link count of 2 or more and
     3) dest and the referent of src are not the same directory entry,
     then it's ok, since while we'll lose one of those hard links,
     src will still point to a remaining link.
     Note that technically, condition #3 obviates condition #2, but we
     retain the 1 < st_nlink condition because that means fewer invocations
     of the more expensive #3.

     Given this,
       $ touch f && ln f l && ln -s f s
       $ ls -og f l s
       -rw-------. 2  0 Jan  4 22:46 f
       -rw-------. 2  0 Jan  4 22:46 l
       lrwxrwxrwx. 1  1 Jan  4 22:46 s -> f
     this must fail: mv s f
     this must succeed: mv s l */
  if (x->move_mode
      && S_ISLNK (src_sb->st_mode)
      && 1 < dst_sb_link->st_nlink)
    {
      char *abs_src = canonicalize_file_name (src_name);
      if (abs_src)
        {
          bool result = ! same_name (abs_src, dst_name);
          free (abs_src);
          return result;
        }
    }

  /* It's ok to remove a destination symlink.  But that works only
     when creating symbolic links, or when the source and destination
     are on the same file system and when creating hard links or when
     unlinking before opening the destination.  */
  if (x->symbolic_link
      || ((x->hard_link || x->unlink_dest_before_opening)
          && S_ISLNK (dst_sb_link->st_mode)))
    return dst_sb_link->st_dev == src_sb_link->st_dev;

  if (x->dereference == DEREF_NEVER)
    {
      if ( ! S_ISLNK (src_sb_link->st_mode))
        tmp_src_sb = *src_sb_link;
      else if (stat (src_name, &tmp_src_sb) != 0)
        return true;

      if ( ! S_ISLNK (dst_sb_link->st_mode))
        tmp_dst_sb = *dst_sb_link;
      else if (stat (dst_name, &tmp_dst_sb) != 0)
        return true;

      if ( ! SAME_INODE (tmp_src_sb, tmp_dst_sb))
        return true;

      /* FIXME: shouldn't this be testing whether we're making symlinks?  */
      if (x->hard_link)
        {
          *return_now = true;
          return true;
        }
    }

  return false;
}

/* Return true if FILE, with mode MODE, is writable in the sense of 'mv'.
   Always consider a symbolic link to be writable.  */
static bool
writable_destination (char const *file, mode_t mode)
{
  return (S_ISLNK (mode)
          || can_write_any_file ()
          || euidaccess (file, W_OK) == 0);
}

static bool
overwrite_ok (struct cp_options const *x, char const *dst_name,
              struct stat const *dst_sb)
{
  if (! writable_destination (dst_name, dst_sb->st_mode))
    {
      char perms[12];		/* "-rwxrwxrwx " ls-style modes. */
      strmode (dst_sb->st_mode, perms);
      perms[10] = '\0';
      fprintf (stderr,
               (x->move_mode || x->unlink_dest_before_opening
                || x->unlink_dest_after_failed_open)
               ? _("%s: replace %s, overriding mode %04lo (%s)? ")
               : _("%s: unwritable %s (mode %04lo, %s); try anyway? "),
               program_name, quoteaf (dst_name),
               (unsigned long int) (dst_sb->st_mode & CHMOD_MODE_BITS),
               &perms[1]);
    }
  else
    {
      fprintf (stderr, _("%s: overwrite %s? "),
               program_name, quoteaf (dst_name));
    }

  return yesno ();
}

/* Initialize the hash table implementing a set of F_triple entries
   corresponding to destination files.  */
extern void
dest_info_init (struct cp_options *x)
{
  x->dest_info
    = hash_initialize (DEST_INFO_INITIAL_CAPACITY,
                       NULL,
                       triple_hash,
                       triple_compare,
                       triple_free);
}

/* Initialize the hash table implementing a set of F_triple entries
   corresponding to source files listed on the command line.  */
extern void
src_info_init (struct cp_options *x)
{

  /* Note that we use triple_hash_no_name here.
     Contrast with the use of triple_hash above.
     That is necessary because a source file may be specified
     in many different ways.  We want to warn about this
       cp a a d/
     as well as this:
       cp a ./a d/
  */
  x->src_info
    = hash_initialize (DEST_INFO_INITIAL_CAPACITY,
                       NULL,
                       triple_hash_no_name,
                       triple_compare,
                       triple_free);
}

/* When effecting a move (e.g., for mv(1)), and given the name DST_NAME
   of the destination and a corresponding stat buffer, DST_SB, return
   true if the logical 'move' operation should _not_ proceed.
   Otherwise, return false.
   Depending on options specified in X, this code may issue an
   interactive prompt asking whether it's ok to overwrite DST_NAME.  */
static bool
abandon_move (const struct cp_options *x,
              char const *dst_name,
              struct stat const *dst_sb)
{
  assert (x->move_mode);
  return (x->interactive == I_ALWAYS_NO
          || ((x->interactive == I_ASK_USER
               || (x->interactive == I_UNSPECIFIED
                   && x->stdin_tty
                   && ! writable_destination (dst_name, dst_sb->st_mode)))
              && ! overwrite_ok (x, dst_name, dst_sb)));
}

/* Print --verbose output on standard output, e.g. 'new' -> 'old'.
   If BACKUP_DST_NAME is non-NULL, then also indicate that it is
   the name of a backup file.  */
static void
emit_verbose (char const *src, char const *dst, char const *backup_dst_name)
{
  printf ("%s -> %s", quoteaf_n (0, src), quoteaf_n (1, dst));
  if (backup_dst_name)
    printf (_(" (backup: %s)"), quoteaf (backup_dst_name));
  putchar ('\n');
  putchar ('\r');
}

/* A wrapper around "setfscreatecon (NULL)" that exits upon failure.  */
static void
restore_default_fscreatecon_or_die (void)
{
  if (setfscreatecon (NULL) != 0)
    die (EXIT_FAILURE, errno,
         _("failed to restore the default file creation context"));
}

/* Create a hard link DST_NAME to SRC_NAME, honoring the REPLACE, VERBOSE and
   DEREFERENCE settings.  Return true upon success.  Otherwise, diagnose the
   failure and return false.  If SRC_NAME is a symbolic link, then it will not
   be followed unless DEREFERENCE is true.
   If the system doesn't support hard links to symbolic links, then DST_NAME
   will be created as a symbolic link to SRC_NAME.  */
static bool
create_hard_link (char const *src_name, char const *dst_name,
                  bool replace, bool verbose, bool dereference)
{
  int status = force_linkat (AT_FDCWD, src_name, AT_FDCWD, dst_name,
                             dereference ? AT_SYMLINK_FOLLOW : 0,
                             replace);
  if (status < 0)
    {
      error (0, errno, _("cannot create hard link %s to %s"),
             quoteaf_n (0, dst_name), quoteaf_n (1, src_name));
      return false;
    }
  if (0 < status && verbose)
    printf (_("removed %s\n\r"), quoteaf (dst_name));
  return true;
}

/* Return true if the current file should be (tried to be) dereferenced:
   either for DEREF_ALWAYS or for DEREF_COMMAND_LINE_ARGUMENTS in the case
   where the current file is a COMMAND_LINE_ARG; otherwise return false.  */
static inline bool _GL_ATTRIBUTE_PURE
should_dereference (const struct cp_options *x, bool command_line_arg)
{
  return x->dereference == DEREF_ALWAYS
         || (x->dereference == DEREF_COMMAND_LINE_ARGUMENTS
             && command_line_arg);
}

/* Copy the file SRC_NAME to the file DST_NAME.  The files may be of
   any type.  NEW_DST should be true if the file DST_NAME cannot
   exist because its parent directory was just created; NEW_DST should
   be false if DST_NAME might already exist.  A non-null PARENT describes the
   parent directory.  ANCESTORS points to a linked, null terminated list of
   devices and inodes of parent directories of SRC_NAME.  COMMAND_LINE_ARG
   is true iff SRC_NAME was specified on the command line.
   FIRST_DIR_CREATED_PER_COMMAND_LINE_ARG is both input and output.
   Set *COPY_INTO_SELF if SRC_NAME is a parent of (or the
   same as) DST_NAME; otherwise, clear it.
   Return true if successful.  */
static bool
copy_internal (char const *src_name, char const *dst_name,
               bool new_dst,
               struct stat const *parent,
               struct dir_list *ancestors,
               const struct cp_options *x,
               bool command_line_arg,
               bool *first_dir_created_per_command_line_arg,
               bool *copy_into_self,
               bool *rename_succeeded)
{
  struct stat src_sb;
  struct stat dst_sb;
  mode_t src_mode;
  mode_t dst_mode IF_LINT ( = 0);
  mode_t dst_mode_bits;
  mode_t omitted_permissions;
  bool restore_dst_mode = false;
  char *earlier_file = NULL;
  char *dst_backup = NULL;
  bool backup_succeeded = false;
  bool delayed_ok;
  bool copied_as_regular = false;
  bool dest_is_symlink = false;
  bool have_dst_lstat = false;

  if (x->move_mode && rename_succeeded)
    *rename_succeeded = false;

  *copy_into_self = false;

  if (XSTAT (x, src_name, &src_sb) != 0)
    {
      error (0, errno, _("cannot stat %s"), quoteaf (src_name));
      return false;
    }

  src_mode = src_sb.st_mode;

  if (S_ISDIR (src_mode) && !x->recursive)
    {
      error (0, 0, ! x->install_mode /* cp */
                   ? _("-r not specified; omitting directory %s")
                   : _("omitting directory %s"),
             quoteaf (src_name));
      return false;
    }

  /* Detect the case in which the same source file appears more than
     once on the command line and no backup option has been selected.
     If so, simply warn and don't copy it the second time.
     This check is enabled only if x->src_info is non-NULL.  */
  if (command_line_arg)
    {
      if ( ! S_ISDIR (src_sb.st_mode)
           && x->backup_type == no_backups
           && seen_file (x->src_info, src_name, &src_sb))
        {
          error (0, 0, _("warning: source file %s specified more than once"),
                 quoteaf (src_name));
          return true;
        }

      record_file (x->src_info, src_name, &src_sb);
    }

  bool dereference = should_dereference (x, command_line_arg);

  if (!new_dst)
    {
      /* Regular files can be created by writing through symbolic
         links, but other files cannot.  So use stat on the
         destination when copying a regular file, and lstat otherwise.
         However, if we intend to unlink or remove the destination
         first, use lstat, since a copy won't actually be made to the
         destination in that case.  */
      bool use_stat =
        ((S_ISREG (src_mode)
          || (x->copy_as_regular
              && ! (S_ISDIR (src_mode) || S_ISLNK (src_mode))))
         && ! (x->move_mode || x->symbolic_link || x->hard_link
               || x->backup_type != no_backups
               || x->unlink_dest_before_opening));
      if ((use_stat
           ? stat (dst_name, &dst_sb)
           : lstat (dst_name, &dst_sb))
          != 0)
        {
          if (errno != ENOENT)
            {
              error (0, errno, _("cannot stat %s"), quoteaf (dst_name));
              return false;
            }
          else
            {
              new_dst = true;
            }
        }
      else
        { /* Here, we know that dst_name exists, at least to the point
             that it is stat'able or lstat'able.  */
          bool return_now;

          have_dst_lstat = !use_stat;
          if (! same_file_ok (src_name, &src_sb, dst_name, &dst_sb,
                              x, &return_now))
            {
              error (0, 0, _("%s and %s are the same file"),
                     quoteaf_n (0, src_name), quoteaf_n (1, dst_name));
              return false;
            }

          if (!S_ISDIR (src_mode) && x->update)
            {
              /* When preserving timestamps (but not moving within a file
                 system), don't worry if the destination timestamp is
                 less than the source merely because of timestamp
                 truncation.  */
              int options = ((x->preserve_timestamps
                              && ! (x->move_mode
                                    && dst_sb.st_dev == src_sb.st_dev))
                             ? UTIMECMP_TRUNCATE_SOURCE
                             : 0);

              if (0 <= utimecmp (dst_name, &dst_sb, &src_sb, options))
                {
                  /* We're using --update and the destination is not older
                     than the source, so do not copy or move.  Pretend the
                     rename succeeded, so the caller (if it's mv) doesn't
                     end up removing the source file.  */
                  if (rename_succeeded)
                    *rename_succeeded = true;

                  /* However, we still must record that we've processed
                     this src/dest pair, in case this source file is
                     hard-linked to another one.  In that case, we'll use
                     the mapping information to link the corresponding
                     destination names.  */
                  earlier_file = remember_copied (dst_name, src_sb.st_ino,
                                                  src_sb.st_dev);
                  if (earlier_file)
                    {
                      /* Note we currently replace DST_NAME unconditionally,
                         even if it was a newer separate file.  */
                      if (! create_hard_link (earlier_file, dst_name, true,
                                              x->verbose, dereference))
                        {
                          goto un_backup;
                        }
                    }

                  return true;
                }
            }

          /* When there is an existing destination file, we may end up
             returning early, and hence not copying/moving the file.
             This may be due to an interactive 'negative' reply to the
             prompt about the existing file.  It may also be due to the
             use of the --no-clobber option.

             cp and mv treat -i and -f differently.  */
          if (x->move_mode)
            {
              if (abandon_move (x, dst_name, &dst_sb))
                {
                  /* Pretend the rename succeeded, so the caller (mv)
                     doesn't end up removing the source file.  */
                  if (rename_succeeded)
                    *rename_succeeded = true;
                  return true;
                }
            }
          else
            {
              if (! S_ISDIR (src_mode)
                  && (x->interactive == I_ALWAYS_NO
                      || (x->interactive == I_ASK_USER
                          && ! overwrite_ok (x, dst_name, &dst_sb))))
                return true;
            }

          if (return_now)
            return true;

          if (!S_ISDIR (dst_sb.st_mode))
            {
              if (S_ISDIR (src_mode))
                {
                  if (x->move_mode && x->backup_type != no_backups)
                    {
                      /* Moving a directory onto an existing
                         non-directory is ok only with --backup.  */
                    }
                  else
                    {
                      error (0, 0,
                       _("cannot overwrite non-directory %s with directory %s"),
                             quoteaf_n (0, dst_name), quoteaf_n (1, src_name));
                      return false;
                    }
                }

              /* Don't let the user destroy their data, even if they try hard:
                 This mv command must fail (likewise for cp):
                   rm -rf a b c; mkdir a b c; touch a/f b/f; mv a/f b/f c
                 Otherwise, the contents of b/f would be lost.
                 In the case of 'cp', b/f would be lost if the user simulated
                 a move using cp and rm.
                 Note that it works fine if you use --backup=numbered.  */
              if (command_line_arg
                  && x->backup_type != numbered_backups
                  && seen_file (x->dest_info, dst_name, &dst_sb))
                {
                  error (0, 0,
                         _("will not overwrite just-created %s with %s"),
                         quoteaf_n (0, dst_name), quoteaf_n (1, src_name));
                  return false;
                }
            }

          if (!S_ISDIR (src_mode))
            {
              if (S_ISDIR (dst_sb.st_mode))
                {
                  if (x->move_mode && x->backup_type != no_backups)
                    {
                      /* Moving a non-directory onto an existing
                         directory is ok only with --backup.  */
                    }
                  else
                    {
                      error (0, 0,
                         _("cannot overwrite directory %s with non-directory"),
                             quoteaf (dst_name));
                      return false;
                    }
                }
            }

          if (x->move_mode)
            {
              /* Don't allow user to move a directory onto a non-directory.  */
              if (S_ISDIR (src_sb.st_mode) && !S_ISDIR (dst_sb.st_mode)
                  && x->backup_type == no_backups)
                {
                  error (0, 0,
                       _("cannot move directory onto non-directory: %s -> %s"),
                         quotef_n (0, src_name), quotef_n (0, dst_name));
                  return false;
                }
            }

          if (x->backup_type != no_backups
              /* Don't try to back up a destination if the last
                 component of src_name is "." or "..".  */
              && ! dot_or_dotdot (last_component (src_name))
              /* Create a backup of each destination directory in move mode,
                 but not in copy mode.  FIXME: it might make sense to add an
                 option to suppress backup creation also for move mode.
                 That would let one use mv to merge new content into an
                 existing hierarchy.  */
              && (x->move_mode || ! S_ISDIR (dst_sb.st_mode)))
            {
              char *tmp_backup = find_backup_file_name (dst_name,
                                                        x->backup_type);

              /* Detect (and fail) when creating the backup file would
                 destroy the source file.  Before, running the commands
                 cd /tmp; rm -f a a~; : > a; echo A > a~; cp --b=simple a~ a
                 would leave two zero-length files: a and a~.  */
              /* FIXME: but simply change e.g., the final a~ to './a~'
                 and the source will still be destroyed.  */
              if (STREQ (tmp_backup, src_name))
                {
                  const char *fmt;
                  fmt = (x->move_mode
                 ? _("backing up %s would destroy source;  %s not moved")
                 : _("backing up %s would destroy source;  %s not copied"));
                  error (0, 0, fmt,
                         quoteaf_n (0, dst_name),
                         quoteaf_n (1, src_name));
                  free (tmp_backup);
                  return false;
                }

              /* FIXME: use fts:
                 Using alloca for a file name that may be arbitrarily
                 long is not recommended.  In fact, even forming such a name
                 should be discouraged.  Eventually, this code will be rewritten
                 to use fts, so using alloca here will be less of a problem.  */
              ASSIGN_STRDUPA (dst_backup, tmp_backup);
              free (tmp_backup);
              /* In move mode, when src_name and dst_name are on the
                 same partition (FIXME, and when they are non-directories),
                 make the operation atomic: link dest
                 to backup, then rename src to dest.  */
              if (rename (dst_name, dst_backup) != 0)
                {
                  if (errno != ENOENT)
                    {
                      error (0, errno, _("cannot backup %s"),
                             quoteaf (dst_name));
                      return false;
                    }
                  else
                    {
                      dst_backup = NULL;
                    }
                }
              else
                {
                  backup_succeeded = true;
                }
              new_dst = true;
            }
          else if (! S_ISDIR (dst_sb.st_mode)
                   /* Never unlink dst_name when in move mode.  */
                   && ! x->move_mode
                   && (x->unlink_dest_before_opening
                       || (x->preserve_links && 1 < dst_sb.st_nlink)
                       || (x->dereference == DEREF_NEVER
                           && ! S_ISREG (src_sb.st_mode))
                       ))
            {
              if (unlink (dst_name) != 0 && errno != ENOENT)
                {
                  error (0, errno, _("cannot remove %s"), quoteaf (dst_name));
                  return false;
                }
              new_dst = true;
              if (x->verbose)
                printf (_("removed %s\n\r"), quoteaf (dst_name));
            }
        }
    }

  /* Ensure we don't try to copy through a symlink that was
     created by a prior call to this function.  */
  if (command_line_arg
      && x->dest_info
      && ! x->move_mode
      && x->backup_type == no_backups)
    {
      bool lstat_ok = true;
      struct stat tmp_buf;
      struct stat *dst_lstat_sb;

      /* If we called lstat above, good: use that data.
         Otherwise, call lstat here, in case dst_name is a symlink.  */
      if (have_dst_lstat)
        dst_lstat_sb = &dst_sb;
      else
        {
          if (lstat (dst_name, &tmp_buf) == 0)
            dst_lstat_sb = &tmp_buf;
          else
            lstat_ok = false;
        }

      /* Never copy through a symlink we've just created.  */
      if (lstat_ok
          && S_ISLNK (dst_lstat_sb->st_mode)
          && seen_file (x->dest_info, dst_name, dst_lstat_sb))
        {
          error (0, 0,
                 _("will not copy %s through just-created symlink %s"),
                 quoteaf_n (0, src_name), quoteaf_n (1, dst_name));
          return false;
        }
    }

  /* If the source is a directory, we don't always create the destination
     directory.  So --verbose should not announce anything until we're
     sure we'll create a directory. */
  if (x->verbose && !S_ISDIR (src_mode))
    emit_verbose (src_name, dst_name, backup_succeeded ? dst_backup : NULL);

  /* Associate the destination file name with the source device and inode
     so that if we encounter a matching dev/ino pair in the source tree
     we can arrange to create a hard link between the corresponding names
     in the destination tree.

     When using the --link (-l) option, there is no need to take special
     measures, because (barring race conditions) files that are hard-linked
     in the source tree will also be hard-linked in the destination tree.

     Sometimes, when preserving links, we have to record dev/ino even
     though st_nlink == 1:
     - when in move_mode, since we may be moving a group of N hard-linked
        files (via two or more command line arguments) to a different
        partition; the links may be distributed among the command line
        arguments (possibly hierarchies) so that the link count of
        the final, once-linked source file is reduced to 1 when it is
        considered below.  But in this case (for mv) we don't need to
        incur the expense of recording the dev/ino => name mapping; all we
        really need is a lookup, to see if the dev/ino pair has already
        been copied.
     - when using -H and processing a command line argument;
        that command line argument could be a symlink pointing to another
        command line argument.  With 'cp -H --preserve=link', we hard-link
        those two destination files.
     - likewise for -L except that it applies to all files, not just
        command line arguments.

     Also, with --recursive, record dev/ino of each command-line directory.
     We'll use that info to detect this problem: cp -R dir dir.  */

  if (x->recursive && S_ISDIR (src_mode))
    {
      if (command_line_arg)
        earlier_file = remember_copied (dst_name, src_sb.st_ino, src_sb.st_dev);
      else
        earlier_file = src_to_dest_lookup (src_sb.st_ino, src_sb.st_dev);
    }
  else if (x->move_mode && src_sb.st_nlink == 1)
    {
      earlier_file = src_to_dest_lookup (src_sb.st_ino, src_sb.st_dev);
    }
  else if (x->preserve_links
           && !x->hard_link
           && (1 < src_sb.st_nlink
               || (command_line_arg
                   && x->dereference == DEREF_COMMAND_LINE_ARGUMENTS)
               || x->dereference == DEREF_ALWAYS))
    {
      earlier_file = remember_copied (dst_name, src_sb.st_ino, src_sb.st_dev);
    }

  /* Did we copy this inode somewhere else (in this command line argument)
     and therefore this is a second hard link to the inode?  */

  if (earlier_file)
    {
      /* Avoid damaging the destination file system by refusing to preserve
         hard-linked directories (which are found at least in Netapp snapshot
         directories).  */
      if (S_ISDIR (src_mode))
        {
          /* If src_name and earlier_file refer to the same directory entry,
             then warn about copying a directory into itself.  */
          if (same_name (src_name, earlier_file))
            {
              error (0, 0, _("cannot copy a directory, %s, into itself, %s"),
                     quoteaf_n (0, top_level_src_name),
                     quoteaf_n (1, top_level_dst_name));
              *copy_into_self = true;
              goto un_backup;
            }
          else if (same_name (dst_name, earlier_file))
            {
              error (0, 0, _("warning: source directory %s "
                             "specified more than once"),
                     quoteaf (top_level_src_name));
              /* In move mode, if a previous rename succeeded, then
                 we won't be in this path as the source is missing.  If the
                 rename previously failed, then that has been handled, so
                 pretend this attempt succeeded so the source isn't removed.  */
              if (x->move_mode && rename_succeeded)
                *rename_succeeded = true;
              /* We only do backups in move mode, and for non directories.
                 So just ignore this repeated entry.  */
              return true;
            }
          else if (x->dereference == DEREF_ALWAYS
                   || (command_line_arg
                       && x->dereference == DEREF_COMMAND_LINE_ARGUMENTS))
            {
              /* This happens when e.g., encountering a directory for the
                 second or subsequent time via symlinks when cp is invoked
                 with -R and -L.  E.g.,
                 rm -rf a b c d; mkdir a b c d; ln -s ../c a; ln -s ../c b;
                 cp -RL a b d
              */
            }
          else
            {
              error (0, 0, _("will not create hard link %s to directory %s"),
                     quoteaf_n (0, dst_name), quoteaf_n (1, earlier_file));
              goto un_backup;
            }
        }
      else
        {
          if (! create_hard_link (earlier_file, dst_name, true, x->verbose,
                                  dereference))
            goto un_backup;

          return true;
        }
    }

  if (x->move_mode)
    {
      if (rename (src_name, dst_name) == 0)
        {
          if (x->verbose && S_ISDIR (src_mode))
            emit_verbose (src_name, dst_name,
                          backup_succeeded ? dst_backup : NULL);

          if (x->set_security_context)
            {
              /* -Z failures are only warnings currently.  */
              (void) set_file_security_ctx (dst_name, false, true, x);
            }

          if (rename_succeeded)
            *rename_succeeded = true;

          if (command_line_arg)
            {
              /* Record destination dev/ino/name, so that if we are asked
                 to overwrite that file again, we can detect it and fail.  */
              /* It's fine to use the _source_ stat buffer (src_sb) to get the
                 _destination_ dev/ino, since the rename above can't have
                 changed those, and 'mv' always uses lstat.
                 We could limit it further by operating
                 only on non-directories.  */
              record_file (x->dest_info, dst_name, &src_sb);
            }

          return true;
        }

      /* FIXME: someday, consider what to do when moving a directory into
         itself but when source and destination are on different devices.  */

      /* This happens when attempting to rename a directory to a
         subdirectory of itself.  */
      if (errno == EINVAL)
        {
          /* FIXME: this is a little fragile in that it relies on rename(2)
             failing with a specific errno value.  Expect problems on
             non-POSIX systems.  */
          error (0, 0, _("cannot move %s to a subdirectory of itself, %s"),
                 quoteaf_n (0, top_level_src_name),
                 quoteaf_n (1, top_level_dst_name));

          /* Note that there is no need to call forget_created here,
             (compare with the other calls in this file) since the
             destination directory didn't exist before.  */

          *copy_into_self = true;
          /* FIXME-cleanup: Don't return true here; adjust mv.c accordingly.
             The only caller that uses this code (mv.c) ends up setting its
             exit status to nonzero when copy_into_self is nonzero.  */
          return true;
        }

      /* WARNING: there probably exist systems for which an inter-device
         rename fails with a value of errno not handled here.
         If/as those are reported, add them to the condition below.
         If this happens to you, please do the following and send the output
         to the bug-reporting address (e.g., in the output of cp --help):
           touch k; perl -e 'rename "k","/tmp/k" or print "$!(",$!+0,")\n\r"'
         where your current directory is on one partition and /tmp is the other.
         Also, please try to find the E* errno macro name corresponding to
         the diagnostic and parenthesized integer, and include that in your
         e-mail.  One way to do that is to run a command like this
           find /usr/include/. -type f \
             | xargs grep 'define.*\<E[A-Z]*\>.*\<18\>' /dev/null
         where you'd replace '18' with the integer in parentheses that
         was output from the perl one-liner above.
         If necessary, of course, change '/tmp' to some other directory.  */
      if (errno != EXDEV)
        {
          /* There are many ways this can happen due to a race condition.
             When something happens between the initial XSTAT and the
             subsequent rename, we can get many different types of errors.
             For example, if the destination is initially a non-directory
             or non-existent, but it is created as a directory, the rename
             fails.  If two 'mv' commands try to rename the same file at
             about the same time, one will succeed and the other will fail.
             If the permissions on the directory containing the source or
             destination file are made too restrictive, the rename will
             fail.  Etc.  */
          error (0, errno,
                 _("cannot move %s to %s"),
                 quoteaf_n (0, src_name), quoteaf_n (1, dst_name));
          forget_created (src_sb.st_ino, src_sb.st_dev);
          return false;
        }

      /* The rename attempt has failed.  Remove any existing destination
         file so that a cross-device 'mv' acts as if it were really using
         the rename syscall.  Note both src and dst must both be directories
         or not, and this is enforced above.  Therefore we check the src_mode
         and operate on dst_name here as a tighter constraint and also because
         src_mode is readily available here.  */
      if ((S_ISDIR (src_mode) ? rmdir (dst_name) : unlink (dst_name)) != 0
          && errno != ENOENT)
        {
          error (0, errno,
             _("inter-device move failed: %s to %s; unable to remove target"),
                 quoteaf_n (0, src_name), quoteaf_n (1, dst_name));
          forget_created (src_sb.st_ino, src_sb.st_dev);
          return false;
        }

      new_dst = true;
    }

  /* If the ownership might change, or if it is a directory (whose
     special mode bits may change after the directory is created),
     omit some permissions at first, so unauthorized users cannot nip
     in before the file is ready.  */
  dst_mode_bits = (x->set_mode ? x->mode : src_mode) & CHMOD_MODE_BITS;
  omitted_permissions =
    (dst_mode_bits
     & (x->preserve_ownership ? S_IRWXG | S_IRWXO
        : S_ISDIR (src_mode) ? S_IWGRP | S_IWOTH
        : 0));

  delayed_ok = true;

  /* If required, set the default security context for new files.
     Also for existing files this is used as a reference
     when copying the context with --preserve=context.
     FIXME: Do we need to consider dst_mode_bits here?  */
  if (! set_process_security_ctx (src_name, dst_name, src_mode, new_dst, x))
    return false;

  if (S_ISDIR (src_mode))
    {
      struct dir_list *dir;

      /* If this directory has been copied before during the
         recursion, there is a symbolic link to an ancestor
         directory of the symbolic link.  It is impossible to
         continue to copy this, unless we've got an infinite disk.  */

      if (is_ancestor (&src_sb, ancestors))
        {
          error (0, 0, _("cannot copy cyclic symbolic link %s"),
                 quoteaf (src_name));
          goto un_backup;
        }

      /* Insert the current directory in the list of parents.  */

      dir = alloca (sizeof *dir);
      dir->parent = ancestors;
      dir->ino = src_sb.st_ino;
      dir->dev = src_sb.st_dev;

      if (new_dst || !S_ISDIR (dst_sb.st_mode))
        {
          /* POSIX says mkdir's behavior is implementation-defined when
             (src_mode & ~S_IRWXUGO) != 0.  However, common practice is
             to ask mkdir to copy all the CHMOD_MODE_BITS, letting mkdir
             decide what to do with S_ISUID | S_ISGID | S_ISVTX.  */
          if (mkdir (dst_name, dst_mode_bits & ~omitted_permissions) != 0)
            {
              error (0, errno, _("cannot create directory %s"),
                     quoteaf (dst_name));
              goto un_backup;
            }

          /* We need search and write permissions to the new directory
             for writing the directory's contents. Check if these
             permissions are there.  */

          if (lstat (dst_name, &dst_sb) != 0)
            {
              error (0, errno, _("cannot stat %s"), quoteaf (dst_name));
              goto un_backup;
            }
          else if ((dst_sb.st_mode & S_IRWXU) != S_IRWXU)
            {
              /* Make the new directory searchable and writable.  */

              dst_mode = dst_sb.st_mode;
              restore_dst_mode = true;

              if (lchmod (dst_name, dst_mode | S_IRWXU) != 0)
                {
                  error (0, errno, _("setting permissions for %s"),
                         quoteaf (dst_name));
                  goto un_backup;
                }
            }

          /* Record the created directory's inode and device numbers into
             the search structure, so that we can avoid copying it again.
             Do this only for the first directory that is created for each
             source command line argument.  */
          if (!*first_dir_created_per_command_line_arg)
            {
              remember_copied (dst_name, dst_sb.st_ino, dst_sb.st_dev);
              *first_dir_created_per_command_line_arg = true;
            }

          if (x->verbose)
            emit_verbose (src_name, dst_name, NULL);
        }
      else
        {
          omitted_permissions = 0;

          /* For directories, the process global context could be reset for
             descendents, so use it to set the context for existing dirs here.
             This will also give earlier indication of failure to set ctx.  */
          if (x->set_security_context || x->preserve_security_context)
            if (! set_file_security_ctx (dst_name, x->preserve_security_context,
                                         false, x))
              {
                if (x->require_preserve_context)
                  goto un_backup;
              }
        }

      /* Decide whether to copy the contents of the directory.  */
      if (x->one_file_system && parent && parent->st_dev != src_sb.st_dev)
        {
          /* Here, we are crossing a file system boundary and cp's -x option
             is in effect: so don't copy the contents of this directory. */
        }
      else
        {
          /* Copy the contents of the directory.  Don't just return if
             this fails -- otherwise, the failure to read a single file
             in a source directory would cause the containing destination
             directory not to have owner/perms set properly.  */
          delayed_ok = copy_dir (src_name, dst_name, new_dst, &src_sb, dir, x,
                                 first_dir_created_per_command_line_arg,
                                 copy_into_self);
        }
    }
  else if (x->symbolic_link)
    {
      dest_is_symlink = true;
      if (*src_name != '/')
        {
          /* Check that DST_NAME denotes a file in the current directory.  */
          struct stat dot_sb;
          struct stat dst_parent_sb;
          char *dst_parent;
          bool in_current_dir;

          dst_parent = dir_name (dst_name);

          in_current_dir = (STREQ (".", dst_parent)
                            /* If either stat call fails, it's ok not to report
                               the failure and say dst_name is in the current
                               directory.  Other things will fail later.  */
                            || stat (".", &dot_sb) != 0
                            || stat (dst_parent, &dst_parent_sb) != 0
                            || SAME_INODE (dot_sb, dst_parent_sb));
          free (dst_parent);

          if (! in_current_dir)
            {
              error (0, 0,
           _("%s: can make relative symbolic links only in current directory"),
                     quotef (dst_name));
              goto un_backup;
            }
        }
      if (force_symlinkat (src_name, AT_FDCWD, dst_name,
                           x->unlink_dest_after_failed_open)
          < 0)
        {
          error (0, errno, _("cannot create symbolic link %s to %s"),
                 quoteaf_n (0, dst_name), quoteaf_n (1, src_name));
          goto un_backup;
        }
    }

  /* POSIX 2008 states that it is implementation-defined whether
     link() on a symlink creates a hard-link to the symlink, or only
     to the referent (effectively dereferencing the symlink) (POSIX
     2001 required the latter behavior, although many systems provided
     the former).  Yet cp, invoked with '--link --no-dereference',
     should not follow the link.  We can approximate the desired
     behavior by skipping this hard-link creating block and instead
     copying the symlink, via the 'S_ISLNK'- copying code below.

     Note gnulib's linkat module, guarantees that the symlink is not
     dereferenced.  However its emulation currently doesn't maintain
     timestamps or ownership so we only call it when we know the
     emulation will not be needed.  */
  else if (x->hard_link
           && !(! CAN_HARDLINK_SYMLINKS && S_ISLNK (src_mode)
                && x->dereference == DEREF_NEVER))
    {
      if (! create_hard_link (src_name, dst_name,
                              x->unlink_dest_after_failed_open,
                              false, dereference))
        goto un_backup;
    }
  else if (S_ISREG (src_mode)
           || (x->copy_as_regular && !S_ISLNK (src_mode)))
    {
      copied_as_regular = true;
      /* POSIX says the permission bits of the source file must be
         used as the 3rd argument in the open call.  Historical
         practice passed all the source mode bits to 'open', but the extra
         bits were ignored, so it should be the same either way.

         This call uses DST_MODE_BITS, not SRC_MODE.  These are
         normally the same, and the exception (where x->set_mode) is
         used only by 'install', which POSIX does not specify and
         where DST_MODE_BITS is what's wanted.  */
      if (! copy_reg (src_name, dst_name, x, dst_mode_bits & S_IRWXUGO,
                      omitted_permissions, &new_dst, &src_sb))
        goto un_backup;
    }
  else if (S_ISFIFO (src_mode))
    {
      /* Use mknod, rather than mkfifo, because the former preserves
         the special mode bits of a fifo on Solaris 10, while mkfifo
         does not.  But fall back on mkfifo, because on some BSD systems,
         mknod always fails when asked to create a FIFO.  */
      if (mknod (dst_name, src_mode & ~omitted_permissions, 0) != 0)
        if (mkfifo (dst_name, src_mode & ~S_IFIFO & ~omitted_permissions) != 0)
          {
            error (0, errno, _("cannot create fifo %s"), quoteaf (dst_name));
            goto un_backup;
          }
    }
  else if (S_ISBLK (src_mode) || S_ISCHR (src_mode) || S_ISSOCK (src_mode))
    {
      if (mknod (dst_name, src_mode & ~omitted_permissions, src_sb.st_rdev)
          != 0)
        {
          error (0, errno, _("cannot create special file %s"),
                 quoteaf (dst_name));
          goto un_backup;
        }
    }
  else if (S_ISLNK (src_mode))
    {
      char *src_link_val = areadlink_with_size (src_name, src_sb.st_size);
      dest_is_symlink = true;
      if (src_link_val == NULL)
        {
          error (0, errno, _("cannot read symbolic link %s"),
                 quoteaf (src_name));
          goto un_backup;
        }

      int symlink_r = force_symlinkat (src_link_val, AT_FDCWD, dst_name,
                                       x->unlink_dest_after_failed_open);
      int symlink_err = symlink_r < 0 ? errno : 0;
      if (symlink_err && x->update && !new_dst && S_ISLNK (dst_sb.st_mode)
          && dst_sb.st_size == strlen (src_link_val))
        {
          /* See if the destination is already the desired symlink.
             FIXME: This behavior isn't documented, and seems wrong
             in some cases, e.g., if the destination symlink has the
             wrong ownership, permissions, or timestamps.  */
          char *dest_link_val =
            areadlink_with_size (dst_name, dst_sb.st_size);
          if (dest_link_val)
            {
              if (STREQ (dest_link_val, src_link_val))
                symlink_err = 0;
              free (dest_link_val);
            }
        }
      free (src_link_val);
      if (symlink_err)
        {
          error (0, symlink_err, _("cannot create symbolic link %s"),
                 quoteaf (dst_name));
          goto un_backup;
        }

      if (x->preserve_security_context)
        restore_default_fscreatecon_or_die ();

      if (x->preserve_ownership)
        {
          /* Preserve the owner and group of the just-'copied'
             symbolic link, if possible.  */
          if (HAVE_LCHOWN
              && lchown (dst_name, src_sb.st_uid, src_sb.st_gid) != 0
              && ! chown_failure_ok (x))
            {
              error (0, errno, _("failed to preserve ownership for %s"),
                     dst_name);
              goto un_backup;
            }
          else
            {
              /* Can't preserve ownership of symlinks.
                 FIXME: maybe give a warning or even error for symlinks
                 in directories with the sticky bit set -- there, not
                 preserving owner/group is a potential security problem.  */
            }
        }
    }
  else
    {
      error (0, 0, _("%s has unknown file type"), quoteaf (src_name));
      goto un_backup;
    }

  /* With -Z or --preserve=context, set the context for existing files.
     Note this is done already for copy_reg() for reasons described therein.  */
  if (!new_dst && !x->copy_as_regular && !S_ISDIR (src_mode)
      && (x->set_security_context || x->preserve_security_context))
    {
      if (! set_file_security_ctx (dst_name, x->preserve_security_context,
                                   false, x))
        {
           if (x->require_preserve_context)
             goto un_backup;
        }
    }

  if (command_line_arg && x->dest_info)
    {
      /* Now that the destination file is very likely to exist,
         add its info to the set.  */
      struct stat sb;
      if (lstat (dst_name, &sb) == 0)
        record_file (x->dest_info, dst_name, &sb);
    }

  /* If we've just created a hard-link due to cp's --link option,
     we're done.  */
  if (x->hard_link && ! S_ISDIR (src_mode)
      && !(! CAN_HARDLINK_SYMLINKS && S_ISLNK (src_mode)
           && x->dereference == DEREF_NEVER))
    return delayed_ok;

  if (copied_as_regular)
    return delayed_ok;

  /* POSIX says that 'cp -p' must restore the following:
     - permission bits
     - setuid, setgid bits
     - owner and group
     If it fails to restore any of those, we may give a warning but
     the destination must not be removed.
     FIXME: implement the above. */

  /* Adjust the times (and if possible, ownership) for the copy.
     chown turns off set[ug]id bits for non-root,
     so do the chmod last.  */

  if (x->preserve_timestamps)
    {
      struct timespec timespec[2];
      timespec[0] = get_stat_atime (&src_sb);
      timespec[1] = get_stat_mtime (&src_sb);

      if ((dest_is_symlink
           ? utimens_symlink (dst_name, timespec)
           : utimens (dst_name, timespec))
          != 0)
        {
          error (0, errno, _("preserving times for %s"), quoteaf (dst_name));
          if (x->require_preserve)
            return false;
        }
    }

  /* Avoid calling chown if we know it's not necessary.  */
  if (!dest_is_symlink && x->preserve_ownership
      && (new_dst || !SAME_OWNER_AND_GROUP (src_sb, dst_sb)))
    {
      switch (set_owner (x, dst_name, -1, &src_sb, new_dst, &dst_sb))
        {
        case -1:
          return false;

        case 0:
          src_mode &= ~ (S_ISUID | S_ISGID | S_ISVTX);
          break;
        }
    }

  /* Set xattrs after ownership as changing owners will clear capabilities.  */
  if (x->preserve_xattr && ! copy_attr (src_name, -1, dst_name, -1, x)
      && x->require_preserve_xattr)
    return false;

  /* The operations beyond this point may dereference a symlink.  */
  if (dest_is_symlink)
    return delayed_ok;

  set_author (dst_name, -1, &src_sb);

  if (x->preserve_mode || x->move_mode)
    {
      if (copy_acl (src_name, -1, dst_name, -1, src_mode) != 0
          && x->require_preserve)
        return false;
    }
  else if (x->set_mode)
    {
      if (set_acl (dst_name, -1, x->mode) != 0)
        return false;
    }
  else if (x->explicit_no_preserve_mode)
    {
      if (set_acl (dst_name, -1, 0777 & ~cached_umask ()) != 0)
        return false;
    }
  else
    {
      if (omitted_permissions)
        {
          omitted_permissions &= ~ cached_umask ();

          if (omitted_permissions && !restore_dst_mode)
            {
              /* Permissions were deliberately omitted when the file
                 was created due to security concerns.  See whether
                 they need to be re-added now.  It'd be faster to omit
                 the lstat, but deducing the current destination mode
                 is tricky in the presence of implementation-defined
                 rules for special mode bits.  */
              if (new_dst && lstat (dst_name, &dst_sb) != 0)
                {
                  error (0, errno, _("cannot stat %s"), quoteaf (dst_name));
                  return false;
                }
              dst_mode = dst_sb.st_mode;
              if (omitted_permissions & ~dst_mode)
                restore_dst_mode = true;
            }
        }

      if (restore_dst_mode)
        {
          if (lchmod (dst_name, dst_mode | omitted_permissions) != 0)
            {
              error (0, errno, _("preserving permissions for %s"),
                     quoteaf (dst_name));
              if (x->require_preserve)
                return false;
            }
        }
    }

  return delayed_ok;

un_backup:

  if (x->preserve_security_context)
    restore_default_fscreatecon_or_die ();

  /* We have failed to create the destination file.
     If we've just added a dev/ino entry via the remember_copied
     call above (i.e., unless we've just failed to create a hard link),
     remove the entry associating the source dev/ino with the
     destination file name, so we don't try to 'preserve' a link
     to a file we didn't create.  */
  if (earlier_file == NULL)
    forget_created (src_sb.st_ino, src_sb.st_dev);

  if (dst_backup)
    {
      if (rename (dst_backup, dst_name) != 0)
        error (0, errno, _("cannot un-backup %s"), quoteaf (dst_name));
      else
        {
          if (x->verbose)
            printf (_("%s -> %s (unbackup)\n\r"),
                    quoteaf_n (0, dst_backup), quoteaf_n (1, dst_name));
        }
    }
  return false;
}

static bool _GL_ATTRIBUTE_PURE
valid_options (const struct cp_options *co)
{
  assert (co != NULL);
  assert (VALID_BACKUP_TYPE (co->backup_type));
  assert (VALID_SPARSE_MODE (co->sparse_mode));
  assert (VALID_REFLINK_MODE (co->reflink_mode));
  assert (!(co->hard_link && co->symbolic_link));
  assert (!
          (co->reflink_mode == REFLINK_ALWAYS
           && co->sparse_mode != SPARSE_AUTO));
  return true;
}

/* Copy the file SRC_NAME to the file DST_NAME.  The files may be of
   any type.  NONEXISTENT_DST should be true if the file DST_NAME
   is known not to exist (e.g., because its parent directory was just
   created);  NONEXISTENT_DST should be false if DST_NAME might already
   exist.  OPTIONS is ... FIXME-describe
   Set *COPY_INTO_SELF if SRC_NAME is a parent of (or the
   same as) DST_NAME; otherwise, set clear it.
   Return true if successful.  */

extern bool
copy (char const *src_name, char const *dst_name,
      bool nonexistent_dst, const struct cp_options *options,
      bool *copy_into_self, bool *rename_succeeded)
{
  assert (valid_options (options));

  /* Record the file names: they're used in case of error, when copying
     a directory into itself.  I don't like to make these tools do *any*
     extra work in the common case when that work is solely to handle
     exceptional cases, but in this case, I don't see a way to derive the
     top level source and destination directory names where they're used.
     An alternative is to use COPY_INTO_SELF and print the diagnostic
     from every caller -- but I don't want to do that.  */
  top_level_src_name = src_name;
  top_level_dst_name = dst_name;

  bool first_dir_created_per_command_line_arg = false;
  return copy_internal (src_name, dst_name, nonexistent_dst, NULL, NULL,
                        options, true,
                        &first_dir_created_per_command_line_arg,
                        copy_into_self, rename_succeeded);
}

/* Set *X to the default options for a value of type struct cp_options.  */

extern void
cp_options_default (struct cp_options *x)
{
  memset (x, 0, sizeof *x);
#ifdef PRIV_FILE_CHOWN
  {
    priv_set_t *pset = priv_allocset ();
    if (!pset)
      xalloc_die ();
    if (getppriv (PRIV_EFFECTIVE, pset) == 0)
      {
        x->chown_privileges = priv_ismember (pset, PRIV_FILE_CHOWN);
        x->owner_privileges = priv_ismember (pset, PRIV_FILE_OWNER);
      }
    priv_freeset (pset);
  }
#else
  x->chown_privileges = x->owner_privileges = (geteuid () == ROOT_UID);
#endif
}

/* Return true if it's OK for chown to fail, where errno is
   the error number that chown failed with and X is the copying
   option set.  */

extern bool
chown_failure_ok (struct cp_options const *x)
{
  /* If non-root uses -p, it's ok if we can't preserve ownership.
     But root probably wants to know, e.g. if NFS disallows it,
     or if the target system doesn't support file ownership.  */

  return ((errno == EPERM || errno == EINVAL) && !x->chown_privileges);
}

/* Similarly, return true if it's OK for chmod and similar operations
   to fail, where errno is the error number that chmod failed with and
   X is the copying option set.  */

static bool
owner_failure_ok (struct cp_options const *x)
{
  return ((errno == EPERM || errno == EINVAL) && !x->owner_privileges);
}

/* Return the user's umask, caching the result.

   FIXME: If the destination's parent directory has has a default ACL,
   some operating systems (e.g., GNU/Linux's "POSIX" ACLs) use that
   ACL's mask rather than the process umask.  Currently, the callers
   of cached_umask incorrectly assume that this situation cannot occur.  */
extern mode_t
cached_umask (void)
{
  static mode_t mask = (mode_t) -1;
  if (mask == (mode_t) -1)
    {
      mask = umask (0);
      umask (mask);
    }
  return mask;
}
