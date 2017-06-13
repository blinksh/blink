/* I/O block size definitions for coreutils
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

/* Include this file _after_ system headers if possible.  */

/* sys/stat.h will already have been included by system.h. */
#include "stat-size.h"


/* As of May 2014, 128KiB is determined to be the minimium
   blksize to best minimize system call overhead.
   This can be tested with this script:

   for i in $(seq 0 10); do
     bs=$((1024*2**$i))
     printf "%7s=" $bs
     timeout --foreground -sINT 2 \
       dd bs=$bs if=/dev/zero of=/dev/null 2>&1 \
         | sed -n 's/.* \([0-9.]* [GM]B\/s\)/\1/p'
   done

   With the results shown for these systems:
   system #1: 1.7GHz pentium-m with 400MHz DDR2 RAM, arch=i686
   system #2: 2.1GHz i3-2310M with 1333MHz DDR3 RAM, arch=x86_64
   system #3: 3.2GHz i7-970 with 1333MHz DDR3, arch=x86_64
   system #4: 2.20GHz Xeon E5-2660 with 1333MHz DDR3, arch=x86_64
   system #5: 2.30GHz i7-3615QM with 1600MHz DDR3, arch=x86_64
   system #6: 1.30GHz i5-4250U with 1-channel 1600MHz DDR3, arch=x86_64
   system #7: 3.55GHz IBM,8231-E2B with 1066MHz DDR3, POWER7 revision 2.1

                per-system transfer rate (GB/s)
   blksize   #1    #2    #3    #4    #5    #6    #7
   ------------------------------------------------------------------------
      1024  .73   1.7   2.6   .64   1.0   2.5   1.3
      2048  1.3   3.0   4.4   1.2   2.0   4.4   2.5
      4096  2.4   5.1   6.5   2.3   3.7   7.4   4.8
      8192  3.5   7.3   8.5   4.0   6.0  10.4   9.2
     16384  3.9   9.4  10.1   6.3   8.3  13.3  16.8
     32768  5.2   9.9  11.1   8.1  10.7  13.2  28.0
     65536  5.3  11.2  12.0  10.6  12.8  16.1  41.4
    131072  5.5  11.8  12.3  12.1  14.0  16.7  54.8
    262144  5.7  11.6  12.5  12.3  14.7  16.4  40.0
    524288  5.7  11.4  12.5  12.1  14.7  15.5  34.5
   1048576  5.8  11.4  12.6  12.2  14.9  15.7  36.5


   Note that this is to minimize system call overhead.
   Other values may be appropriate to minimize file system
   or disk overhead.  For example on my current GNU/Linux system
   the readahead setting is 128KiB which was read using:

   file="."
   device=$(df --output=source --local "$file" | tail -n1)
   echo $(( $(blockdev --getra $device) * 512 ))

   However there isn't a portable way to get the above.
   In the future we could use the above method if available
   and default to io_blksize() if not.
 */
enum { IO_BUFSIZE = 128*1024 };
static inline size_t
io_blksize (struct stat sb)
{
  return MAX (IO_BUFSIZE, ST_BLKSIZE (sb));
}
