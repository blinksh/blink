/* core functions for efficient reading sparse files
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

#ifndef EXTENT_SCAN_H
# define EXTENT_SCAN_H

/* Structure used to store information of each extent.  */
struct extent_info
{
  /* Logical offset of an extent.  */
  off_t ext_logical;

  /* Extent length.  */
  off_t ext_length;

  /* Extent flags, use it for FIEMAP only, or set it to zero.  */
  unsigned int ext_flags;
};

/* Structure used to reserve extent scan information per file.  */
struct extent_scan
{
  /* File descriptor of extent scan run against.  */
  int fd;

  /* Next scan start offset.  */
  off_t scan_start;

  /* Flags to use for scan.  */
  unsigned int fm_flags;

  /* How many extent info returned for a scan.  */
  size_t ei_count;

  /* If true, fall back to a normal copy, either set by the
     failure of ioctl(2) for FIEMAP or lseek(2) with SEEK_DATA.  */
  bool initial_scan_failed;

  /* If true, the total extent scan per file has been finished.  */
  bool hit_final_extent;

  /* Extent information: a malloc'd array of ei_count structs.  */
  struct extent_info *ext_info;
};

void extent_scan_init (int src_fd, struct extent_scan *scan);

bool extent_scan_read (struct extent_scan *scan);

static inline void
extent_scan_free (struct extent_scan *scan)
{
  free (scan->ext_info);
  scan->ext_info = NULL;
  scan->ei_count = 0;
}

#endif /* EXTENT_SCAN_H */
