#!/bin/sh
# Test cp handles extents correctly

# Copyright (C) 2011-2017 Free Software Foundation, Inc.

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

require_sparse_support_

touch fiemap_chk || framework_failure_
fiemap_capable_ fiemap_chk ||
  skip_ 'this file system lacks FIEMAP support'
rm fiemap_chk

fallocate --help >/dev/null || skip_ 'The fallocate utility is required'
touch falloc.test || framework_failure_
fallocate -l 1 -o 1 -n falloc.test ||
  skip_ 'this file system lacks FALLOCATE support'
rm falloc.test

# We don't currently handle unwritten extents specially
if false; then
# Require more space than we'll actually use, so that
# tests run in parallel do not run out of space.
# Otherwise, with inadequate space, simply running the following
# fallocate command would induce a temporary disk-full condition,
# which would cause failure of unrelated tests run in parallel.
require_file_system_bytes_free_ 800000000

fallocate -l 1MiB num.test ||
  skip_ "this fallocate doesn't support numbers with IEX suffixes"

fallocate -l 600MiB space.test ||
  skip_ 'this test needs at least 600MiB free space'

# Disable this test on old BTRFS (e.g. Fedora 14)
# which reports ordinary extents for unwritten ones.
filefrag space.test || skip_ 'the 'filefrag' utility is missing'
filefrag -v space.test | grep -F 'unwritten' > /dev/null ||
  skip_ 'this file system does not report empty extents as "unwritten"'

rm space.test

# Ensure we read a large empty file quickly
fallocate -l 300MiB empty.big || framework_failure_
timeout 3 cp --sparse=always empty.big cp.test || fail=1
test $(stat -c %s empty.big) = $(stat -c %s cp.test) || fail=1
rm empty.big cp.test
fi

# Ensure we handle extents beyond file size correctly.
# Note until we support fallocate, we will not maintain
# the file allocation.  FIXME: amend this test if fallocate is supported.
# Note currently this only uses fiemap logic when the allocation (-l)
# is smaller than the size, thus identifying the file as sparse.
# Note the '-l 1' case is an effective noop, and just checks
# a file with a trailing hole is copied correctly.
for sparse_mode in always auto never; do
  for alloc in '-l 4194304' '-l 1048576 -o 4194304' '-l 1'; do
    dd count=10 if=/dev/urandom iflag=fullblock of=unwritten.withdata
    truncate -s 2MiB unwritten.withdata || framework_failure_
    fallocate $alloc -n unwritten.withdata || framework_failure_
    cp --sparse=$sparse_mode unwritten.withdata cp.test || fail=1
    test $(stat -c %s unwritten.withdata) = $(stat -c %s cp.test) || fail=1
    cmp unwritten.withdata cp.test || fail=1
    rm unwritten.withdata cp.test || framework_failure_
  done
done

Exit $fail
