/* fsusage.h -- declarations for file system space usage info

   Copyright (C) 1991-1992, 1997, 2003-2006, 2009-2017 Free Software
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

/* Space usage statistics for a file system.  Blocks are 512-byte. */

#if !defined FSUSAGE_H_
# define FSUSAGE_H_

# include <stdint.h>
# include <stdbool.h>

struct fs_usage
{
  uintmax_t fsu_blocksize;      /* Size of a block.  */
  uintmax_t fsu_blocks;         /* Total blocks. */
  uintmax_t fsu_bfree;          /* Free blocks available to superuser. */
  uintmax_t fsu_bavail;         /* Free blocks available to non-superuser. */
  bool fsu_bavail_top_bit_set;  /* 1 if fsu_bavail represents a value < 0.  */
  uintmax_t fsu_files;          /* Total file nodes. */
  uintmax_t fsu_ffree;          /* Free file nodes. */
};

int get_fs_usage (char const *file, char const *disk, struct fs_usage *fsp);

#endif
