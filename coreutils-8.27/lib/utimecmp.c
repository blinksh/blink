/* utimecmp.c -- compare file timestamps

   Copyright (C) 2004-2007, 2009-2017 Free Software Foundation, Inc.

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

/* Written by Paul Eggert.  */

#include "config.h"

#include "utimecmp.h"

#include <limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include "time.h"
#include <unistd.h>

#include "hash.h"
#include "intprops.h"
#include "stat-time.h"
#include "utimens.h"
#include "verify.h"

#ifndef MAX
# define MAX(a, b) ((a) > (b) ? (a) : (b))
#endif

#define BILLION (1000 * 1000 * 1000)

/* Best possible resolution that utimens can set and stat can return,
   due to system-call limitations.  It must be a power of 10 that is
   no greater than 1 billion.  */
#if HAVE_UTIMENSAT
enum { SYSCALL_RESOLUTION = 1 };
#elif ((HAVE_FUTIMESAT || HAVE_WORKING_UTIMES)                  \
       && (defined HAVE_STRUCT_STAT_ST_ATIM_TV_NSEC             \
           || defined HAVE_STRUCT_STAT_ST_ATIMESPEC_TV_NSEC     \
           || defined HAVE_STRUCT_STAT_ST_ATIMENSEC             \
           || defined HAVE_STRUCT_STAT_ST_ATIM_ST__TIM_TV_NSEC  \
           || defined HAVE_STRUCT_STAT_ST_SPARE1))
enum { SYSCALL_RESOLUTION = 1000 };
#else
enum { SYSCALL_RESOLUTION = BILLION };
#endif

/* Describe a file system and its timestamp resolution in nanoseconds.  */
struct fs_res
{
  /* Device number of file system.  */
  dev_t dev;

  /* An upper bound on the timestamp resolution of this file system,
     ignoring any resolution that cannot be set via utimens.  It is
     represented by an integer count of nanoseconds.  It must be
     either 2 billion, or a power of 10 that is no greater than a
     billion and is no less than SYSCALL_RESOLUTION.  */
  int resolution;

  /* True if RESOLUTION is known to be exact, and is not merely an
     upper bound on the true resolution.  */
  bool exact;
};

/* Hash some device info.  */
static size_t
dev_info_hash (void const *x, size_t table_size)
{
  struct fs_res const *p = x;

  /* Beware signed arithmetic gotchas.  */
  if (TYPE_SIGNED (dev_t) && SIZE_MAX < MAX (INT_MAX, TYPE_MAXIMUM (dev_t)))
    {
      uintmax_t dev = p->dev;
      return dev % table_size;
    }

  return p->dev % table_size;
}

/* Compare two dev_info structs.  */
static bool
dev_info_compare (void const *x, void const *y)
{
  struct fs_res const *a = x;
  struct fs_res const *b = y;
  return a->dev == b->dev;
}

/* Return -1, 0, 1 based on whether the destination file (with name
   DST_NAME and status DST_STAT) is older than SRC_STAT, the same age
   as SRC_STAT, or newer than SRC_STAT, respectively.

   DST_NAME may be NULL if OPTIONS is 0.

   If OPTIONS & UTIMECMP_TRUNCATE_SOURCE, do the comparison after SRC is
   converted to the destination's timestamp resolution as filtered through
   utimens.  In this case, return -2 if the exact answer cannot be
   determined; this can happen only if the timestamps are very close and
   there is some trouble accessing the file system (e.g., the user does not
   have permission to futz with the destination's timestamps).  */

int
utimecmp (char const *dst_name,
          struct stat const *dst_stat,
          struct stat const *src_stat,
          int options)
{
  /* Things to watch out for:

     The code uses a static hash table internally and is not safe in the
     presence of signals, multiple threads, etc.  However, memory pressure
     that prevents use of the hash table is not fatal - we just fall back
     to redoing the computations on every call in that case.

     int and long int might be 32 bits.  Many of the calculations store
     numbers up to 2 billion, and multiply by 10; they have to avoid
     multiplying 2 billion by 10, as this exceeds 32-bit capabilities.

     time_t might be unsigned.  */

  verify (TYPE_IS_INTEGER (time_t));

  /* Destination and source timestamps.  */
  time_t dst_s = dst_stat->st_mtime;
  time_t src_s = src_stat->st_mtime;
  int dst_ns = get_stat_mtime_ns (dst_stat);
  int src_ns = get_stat_mtime_ns (src_stat);

  if (options & UTIMECMP_TRUNCATE_SOURCE)
    {
      /* Look up the timestamp resolution for the destination device.  */

      /* Hash table for caching information learned about devices.  */
      static Hash_table *ht;

      /* Information about the destination file system.  */
      static struct fs_res *new_dst_res;
      struct fs_res *dst_res = NULL;
      struct fs_res tmp_dst_res;

      /* timestamp resolution in nanoseconds.  */
      int res;

      /* Quick exit, if possible.  Since the worst resolution is 2
         seconds, anything that differs by more than that does not
         needs source truncation.  */
      if (dst_s == src_s && dst_ns == src_ns)
        return 0;
      if (dst_s <= src_s - 2)
        return -1;
      if (src_s <= dst_s - 2)
        return 1;

      /* Try to do a hash lookup, but fall back to stack variables and
         recomputation on low memory situations.  */
      if (! ht)
        ht = hash_initialize (16, NULL, dev_info_hash, dev_info_compare, free);
      if (ht)
        {
          if (! new_dst_res)
            {
              new_dst_res = malloc (sizeof *new_dst_res);
              if (!new_dst_res)
                goto low_memory;
              new_dst_res->resolution = 2 * BILLION;
              new_dst_res->exact = false;
            }
          new_dst_res->dev = dst_stat->st_dev;
          dst_res = hash_insert (ht, new_dst_res);
          if (! dst_res)
            goto low_memory;

          if (dst_res == new_dst_res)
            {
              /* NEW_DST_RES is now in use in the hash table, so allocate a
                 new entry next time.  */
              new_dst_res = NULL;
            }
        }
      else
        {
        low_memory:
          if (ht)
            {
              tmp_dst_res.dev = dst_stat->st_dev;
              dst_res = hash_lookup (ht, &tmp_dst_res);
            }
          if (!dst_res)
            {
              dst_res = &tmp_dst_res;
              dst_res->resolution = 2 * BILLION;
              dst_res->exact = false;
            }
        }

      res = dst_res->resolution;

#ifdef _PC_TIMESTAMP_RESOLUTION
      /* If the system will tell us the resolution, we're set!  */
      if (! dst_res->exact)
        {
          res = pathconf (dst_name, _PC_TIMESTAMP_RESOLUTION);
          if (0 < res)
            {
              dst_res->resolution = res;
              dst_res->exact = true;
            }
        }
#endif

      if (! dst_res->exact)
        {
          /* This file system's resolution is not known exactly.
             Deduce it, and store the result in the hash table.  */

          time_t dst_a_s = dst_stat->st_atime;
          time_t dst_c_s = dst_stat->st_ctime;
          time_t dst_m_s = dst_s;
          int dst_a_ns = get_stat_atime_ns (dst_stat);
          int dst_c_ns = get_stat_ctime_ns (dst_stat);
          int dst_m_ns = dst_ns;

          /* Set RES to an upper bound on the file system resolution
             (after truncation due to SYSCALL_RESOLUTION) by inspecting
             the atime, ctime and mtime of the existing destination.
             We don't know of any file system that stores atime or
             ctime with a higher precision than mtime, so it's valid to
             look at them too.  */
          {
            bool odd_second = (dst_a_s | dst_c_s | dst_m_s) & 1;

            if (SYSCALL_RESOLUTION == BILLION)
              {
                if (odd_second | dst_a_ns | dst_c_ns | dst_m_ns)
                  res = BILLION;
              }
            else
              {
                int a = dst_a_ns;
                int c = dst_c_ns;
                int m = dst_m_ns;

                /* Write it this way to avoid mistaken GCC warning
                   about integer overflow in constant expression.  */
                int SR10 = SYSCALL_RESOLUTION;  SR10 *= 10;

                if ((a % SR10 | c % SR10 | m % SR10) != 0)
                  res = SYSCALL_RESOLUTION;
                else
                  for (res = SR10, a /= SR10, c /= SR10, m /= SR10;
                       (res < dst_res->resolution
                        && (a % 10 | c % 10 | m % 10) == 0);
                       res *= 10, a /= 10, c /= 10, m /= 10)
                    if (res == BILLION)
                      {
                        if (! odd_second)
                          res *= 2;
                        break;
                      }
              }

            dst_res->resolution = res;
          }

          if (SYSCALL_RESOLUTION < res)
            {
              struct timespec timespec[2];
              struct stat dst_status;

              /* Ignore source timestamp information that must necessarily
                 be lost when filtered through utimens.  */
              src_ns -= src_ns % SYSCALL_RESOLUTION;

              /* If the timestamps disagree widely enough, there's no need
                 to interrogate the file system to deduce the exact
                 timestamp resolution; return the answer directly.  */
              {
                time_t s = src_s & ~ (res == 2 * BILLION ? 1 : 0);
                if (src_s < dst_s || (src_s == dst_s && src_ns <= dst_ns))
                  return 1;
                if (dst_s < s
                    || (dst_s == s && dst_ns < src_ns - src_ns % res))
                  return -1;
              }

              /* Determine the actual timestamp resolution for the
                 destination file system (after truncation due to
                 SYSCALL_RESOLUTION) by setting the access timestamp of the
                 destination to the existing access time, except with
                 trailing nonzero digits.  */

              timespec[0].tv_sec = dst_a_s;
              timespec[0].tv_nsec = dst_a_ns;
              timespec[1].tv_sec = dst_m_s | (res == 2 * BILLION);
              timespec[1].tv_nsec = dst_m_ns + res / 9;

              /* Set the modification time.  But don't try to set the
                 modification time of symbolic links; on many hosts this sets
                 the time of the pointed-to file.  */
              if ((S_ISLNK (dst_stat->st_mode)
                   ? lutimens (dst_name, timespec)
                   : utimens (dst_name, timespec)) != 0)
                return -2;

              /* Read the modification time that was set.  */
              {
                int stat_result = (S_ISLNK (dst_stat->st_mode)
                                   ? lstat (dst_name, &dst_status)
                                   : stat (dst_name, &dst_status));

                if (stat_result
                    | (dst_status.st_mtime ^ dst_m_s)
                    | (get_stat_mtime_ns (&dst_status) ^ dst_m_ns))
                  {
                    /* The modification time changed, or we can't tell whether
                       it changed.  Change it back as best we can.  */
                    timespec[1].tv_sec = dst_m_s;
                    timespec[1].tv_nsec = dst_m_ns;
                    if (S_ISLNK (dst_stat->st_mode))
                      lutimens (dst_name, timespec);
                    else
                      utimens (dst_name, timespec);
                  }

                if (stat_result != 0)
                  return -2;
              }

              /* Determine the exact resolution from the modification time
                 that was read back.  */
              {
                int old_res = res;
                int a = (BILLION * (dst_status.st_mtime & 1)
                         + get_stat_mtime_ns (&dst_status));

                res = SYSCALL_RESOLUTION;

                for (a /= res; a % 10 == 0; a /= 10)
                  {
                    if (res == BILLION)
                      {
                        res *= 2;
                        break;
                      }
                    res *= 10;
                    if (res == old_res)
                      break;
                  }
              }
            }

          dst_res->resolution = res;
          dst_res->exact = true;
        }

      /* Truncate the source's timestamp according to the resolution.  */
      src_s &= ~ (res == 2 * BILLION ? 1 : 0);
      src_ns -= src_ns % res;
    }

  /* Compare the timestamps and return -1, 0, 1 accordingly.  */
  return (dst_s < src_s ? -1
          : dst_s > src_s ? 1
          : dst_ns < src_ns ? -1
          : dst_ns > src_ns);
}
