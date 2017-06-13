/* extent-scan.c -- core functions for scanning extents
   Copyright (C) 2010-2017 Free Software Foundation, Inc.

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

   Written by Jie Liu (jeff.liu@oracle.com).  */

#include <config.h>
#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/utsname.h>
#include <assert.h>

#include "system.h"
#include "extent-scan.h"
#include "fiemap.h"
#include "xstrtol.h"


/* Work around Linux kernel issues on BTRFS and EXT4.  */
static bool
extent_need_sync (void)
{
  /* For now always return true, to be on the safe side.
     If/when FIEMAP semantics are well defined (before SEEK_HOLE support
     is usable) and kernels implementing them are in use, we may relax
     this once again.  */
  return true;

#if FIEMAP_BEHAVIOR_IS_DEFINED_AND_USABLE
  static int need_sync = -1;

  if (need_sync == -1)
    {
      struct utsname name;
      need_sync = 0; /* No workaround by default.  */

# ifdef __linux__
      if (uname (&name) != -1 && STRNCMP_LIT (name.release, "2.6.") == 0)
        {
           unsigned long val;
           if (xstrtoul (name.release + 4, NULL, 10, &val, NULL) == LONGINT_OK)
             {
               if (val < 39)
                 need_sync = 1;
             }
        }
# endif
    }

  return need_sync;
#endif
}

/* Allocate space for struct extent_scan, initialize the entries if
   necessary and return it as the input argument of extent_scan_read().  */
extern void
extent_scan_init (int src_fd, struct extent_scan *scan)
{
  scan->fd = src_fd;
  scan->ei_count = 0;
  scan->ext_info = NULL;
  scan->scan_start = 0;
  scan->initial_scan_failed = false;
  scan->hit_final_extent = false;
  scan->fm_flags = extent_need_sync () ? FIEMAP_FLAG_SYNC : 0;
}

#ifdef __linux__
# ifndef FS_IOC_FIEMAP
#  define FS_IOC_FIEMAP _IOWR ('f', 11, struct fiemap)
# endif
/* Call ioctl(2) with FS_IOC_FIEMAP (available in linux 2.6.27) to
   obtain a map of file extents excluding holes.  */
extern bool
extent_scan_read (struct extent_scan *scan)
{
  unsigned int si = 0;
  struct extent_info *last_ei = scan->ext_info;

  while (true)
    {
      union { struct fiemap f; char c[4096]; } fiemap_buf;
      struct fiemap *fiemap = &fiemap_buf.f;
      struct fiemap_extent *fm_extents = &fiemap->fm_extents[0];
      enum { count = (sizeof fiemap_buf - sizeof *fiemap)/sizeof *fm_extents };
      verify (count > 1);

      /* This is required at least to initialize fiemap->fm_start,
         but also serves (in mid 2010) to appease valgrind, which
         appears not to know the semantics of the FIEMAP ioctl. */
      memset (&fiemap_buf, 0, sizeof fiemap_buf);

      fiemap->fm_start = scan->scan_start;
      fiemap->fm_flags = scan->fm_flags;
      fiemap->fm_extent_count = count;
      fiemap->fm_length = FIEMAP_MAX_OFFSET - scan->scan_start;

      /* Fall back to the standard copy if call ioctl(2) failed for
         the first time.  */
      if (ioctl (scan->fd, FS_IOC_FIEMAP, fiemap) < 0)
        {
          if (scan->scan_start == 0)
            scan->initial_scan_failed = true;
          return false;
        }

      /* If 0 extents are returned, then no more scans are needed.  */
      if (fiemap->fm_mapped_extents == 0)
        {
          scan->hit_final_extent = true;
          return scan->scan_start != 0;
        }

      assert (scan->ei_count <= SIZE_MAX - fiemap->fm_mapped_extents);
      scan->ei_count += fiemap->fm_mapped_extents;
      {
        /* last_ei points into a buffer that may be freed via xnrealloc.
           Record its offset and adjust after allocation.  */
        size_t prev_idx = last_ei - scan->ext_info;
        scan->ext_info = xnrealloc (scan->ext_info, scan->ei_count,
                                    sizeof (struct extent_info));
        last_ei = scan->ext_info + prev_idx;
      }

      unsigned int i = 0;
      for (i = 0; i < fiemap->fm_mapped_extents; i++)
        {
          assert (fm_extents[i].fe_logical
                  <= OFF_T_MAX - fm_extents[i].fe_length);

          verify (sizeof last_ei->ext_flags >= sizeof fm_extents->fe_flags);

          if (si && last_ei->ext_flags
              == (fm_extents[i].fe_flags & ~FIEMAP_EXTENT_LAST)
              && (last_ei->ext_logical + last_ei->ext_length
                  == fm_extents[i].fe_logical))
            {
              /* Merge previous with last.  */
              last_ei->ext_length += fm_extents[i].fe_length;
              /* Copy flags in case different.  */
              last_ei->ext_flags = fm_extents[i].fe_flags;
            }
          else if ((si == 0 && scan->scan_start > fm_extents[i].fe_logical)
                   || (si && (last_ei->ext_logical + last_ei->ext_length
                              > fm_extents[i].fe_logical)))
            {
              /* BTRFS before 2.6.38 could return overlapping extents
                 for sparse files.  We adjust the returned extents
                 rather than failing, as otherwise it would be inefficient
                 to detect this on the initial scan.  */
              uint64_t new_logical;
              uint64_t length_adjust;
              if (si == 0)
                new_logical = scan->scan_start;
              else
                {
                  /* We could return here if scan->scan_start == 0
                     but don't so as to minimize special cases.  */
                  new_logical = last_ei->ext_logical + last_ei->ext_length;
                }
              length_adjust = new_logical - fm_extents[i].fe_logical;
              /* If an extent is contained within the previous one, fail.  */
              if (length_adjust < fm_extents[i].fe_length)
                {
                  if (scan->scan_start == 0)
                    scan->initial_scan_failed = true;
                  return false;
                }
              fm_extents[i].fe_logical = new_logical;
              fm_extents[i].fe_length -= length_adjust;
              /* Process the adjusted extent again.  */
              i--;
              continue;
            }
          else
            {
              last_ei = scan->ext_info + si;
              last_ei->ext_logical = fm_extents[i].fe_logical;
              last_ei->ext_length = fm_extents[i].fe_length;
              last_ei->ext_flags = fm_extents[i].fe_flags;
              si++;
            }
        }

      if (last_ei->ext_flags & FIEMAP_EXTENT_LAST)
        scan->hit_final_extent = true;

      /* If we have enough extents, discard the last as it might
         be merged with one from the next scan.  */
      if (si > count && !scan->hit_final_extent)
        last_ei = scan->ext_info + --si - 1;

      /* We don't bother reallocating any trailing slots.  */
      scan->ei_count = si;

      if (scan->hit_final_extent)
        break;
      else
        scan->scan_start = last_ei->ext_logical + last_ei->ext_length;

      if (si >= count)
        break;
    }

  return true;
}
#else
extern bool
extent_scan_read (struct extent_scan *scan _GL_UNUSED)
{
  scan->initial_scan_failed = true;
  errno = ENOTSUP;
  return false;
}
#endif
