#!/bin/sh

# Copyright (C) 2012-2017 Free Software Foundation, Inc.

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
print_ver_ dd
is_local_dir_ . || very_expensive_
require_sparse_support_

# Ensure basic sparse generation works
truncate -s1M sparse
dd bs=32K if=sparse of=sparse.dd conv=sparse
test $(stat -c %s sparse) = $(stat -c %s sparse.dd) || fail=1

# Demonstrate that conv=sparse with oflag=append,
# will do ineffective seeks in the output
printf 'a\000\000b' > file.in
printf 'ab' > exp
dd if=file.in bs=1 conv=sparse oflag=append > out
compare exp out || fail=1

# Demonstrate conv=sparse with conv=notrunc,
# where data in file.out is not overwritten with NULs
printf '____' > out
printf 'a__b' > exp
dd if=file.in bs=1 conv=sparse,notrunc of=out
compare exp out || fail=1

# Ensure we fall back to write if seek fails
dd if=file.in bs=1 conv=sparse | cat > file.out
cmp file.in file.out || fail=1

# Setup for block size tests: create a 3MiB file with a 1MiB
# stretch of NUL bytes in the middle.
rm -f file.in
dd if=/dev/urandom of=file.in bs=1M count=3 iflag=fullblock || fail=1
dd if=/dev/zero    of=file.in bs=1M count=1 seek=1 conv=notrunc || fail=1

kb_alloc() { du -k "$1"|cut -f1; }

# sync out data for async allocators like NFS/BTRFS
# sync file.in || fail=1

# If our just-created input file appears to be too small,
# skip the remaining tests.  On at least Solaris 10 with NFS,
# file.in is reported to occupy <= 1KiB for about 50 seconds
# after its creation.
if test $(kb_alloc file.in) -gt 3000; then

  # Ensure NUL blocks smaller than the block size are not made sparse.
  # Here, with a 2MiB block size, dd's conv=sparse must *not* introduce a hole.
  dd if=file.in of=file.out bs=2M conv=sparse || fail=1

  # Intermittently BTRFS returns 0 allocation for file.out unless synced
  sync file.out || framework_failure_
  test 2500 -lt $(kb_alloc file.out) || fail=1

  # Note we recreate a sparse file first to avoid
  # speculative preallocation seen in XFS, where a write() that
  # extends a file can preallocate some extra space that
  # a subsequent seek will not convert to a hole.
  rm -f file.out
  truncate --size=3M file.out

  # Ensure that this 1MiB string of NULs *is* converted to a hole.
  dd if=file.in of=file.out bs=1M conv=sparse,notrunc
  test $(kb_alloc file.out) -lt 2500 || fail=1

fi

Exit $fail
