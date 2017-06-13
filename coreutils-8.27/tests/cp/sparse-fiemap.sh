#!/bin/sh
# Test cp --sparse=always through fiemap copy

# Copyright (C) 2010-2017 Free Software Foundation, Inc.

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ cp
require_perl_

# The test was seen to fail on ext3 so exclude that type
# (or any file system where the type can't be determined)
touch fiemap_chk
if fiemap_capable_ fiemap_chk && ! df -t ext3 . >/dev/null; then
  : # Current partition has working extents.  Good!
else
  skip_ "current file system has insufficient FIEMAP support"

  # It's not;  we need to create one, hence we need root access.
  require_root_

  cwd=$PWD
  cleanup_() { cd /; umount "$cwd/mnt"; }

  skip=0
  # Create an ext4 loopback file system
  dd if=/dev/zero of=blob bs=32k count=1000 || skip=1
  mkdir mnt
  mkfs -t ext4 -F blob ||
    skip_ "failed to create ext4 file system"
  mount -oloop blob mnt   || skip=1
  cd mnt                  || skip=1
  echo test > f           || skip=1
  test -s f               || skip=1

  test $skip = 1 &&
    skip_ "insufficient mount/ext4 support"
fi

# =================================================
# Ensure that we exercise the FIEMAP-copying code enough
# to provoke at least two iterations of the do...while loop
# in which it calls ioctl (fd, FS_IOC_FIEMAP,...
# This also verifies that non-trivial extents are preserved.

# Extract logical block number and length pairs from filefrag -v output.
# The initial sed is to remove the "eof" from the normally-empty "flags" field.
# Similarly, remove flags values like "unknown,delalloc,eof".
# That is required when that final extent has no number in the "expected" field.
f()
{
  sed 's/ [a-z,][a-z,]*$//' $@ \
    | $AWK '/^ *[0-9]/ {printf "%d %d ", $2, (NF>=6 ? $6 : (NF<5 ? $NF : $5)) }
            END {print ""}'
}

for i in $(seq 1 2 21); do
  for j in 1 2 31 100; do
    $PERL -e '$n = '$i' * 1024; *F = *STDOUT;' \
          -e 'for (1..'$j') { sysseek (*F, $n, 1)' \
          -e '&& syswrite (*F, chr($_)x$n) or die "$!"}' > j1 || fail=1

    # Note there is an implicit sync performed by cp on Linux kernels
    # before 2.6.39 to work around bugs in EXT4 and BTRFS.
    # Note also the -s parameter to the filefrag commands below
    # for the same reasons.
    cp --sparse=always j1 j2 || fail=1

    cmp j1 j2 || fail_ "data loss i=$i j=$j"
    if ! filefrag -vs j1 | grep -F extent >/dev/null; then
      test $skip != 1 && warn_ 'skipping part; you lack filefrag'
      skip=1
    else
      # Here is sample filefrag output:
      #   $ perl -e 'BEGIN{$n=16*1024; *F=*STDOUT}' \
      #          -e 'for (1..5) { sysseek(*F,$n,1)' \
      #          -e '&& syswrite *F,"."x$n or die "$!"}' > j
      #   $ filefrag -v j
      #   File system type is: ef53
      #   File size of j is 163840 (40 blocks, blocksize 4096)
      #    ext logical physical expected length flags
      #      0       4  6258884               4
      #      1      12  6258892  6258887      4
      #      2      20  6258900  6258895      4
      #      3      28  6258908  6258903      4
      #      4      36  6258916  6258911      4 eof
      #   j: 6 extents found

      # exclude the physical block numbers; they always differ
      filefrag -v j1 > ff1 || framework_failure_
      filefrag -vs j2 > ff2 || framework_failure_
      { f ff1; f ff2; } | $PERL $abs_srcdir/tests/filefrag-extent-compare \
        || {
             warn_ ignoring filefrag-reported extent map differences
             # Show the differing extent maps.
             head -n99 ff1 ff2
           }
    fi
    test $fail = 1 && break 2
  done
done

Exit $fail
