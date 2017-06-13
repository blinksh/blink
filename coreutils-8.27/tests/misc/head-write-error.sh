#!/bin/sh
# Ensure we diagnose and not continue writing to
# the output if we get a write error.

# Copyright (C) 2014-2017 Free Software Foundation, Inc.

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
print_ver_ head

if ! test -w /dev/full || ! test -c /dev/full; then
  skip_ '/dev/full is required'
fi

# We can't use /dev/zero as that's bypassed in the --lines case
# due to lseek() indicating it has a size of zero.
yes | head -c10M > bigseek || framework_failure_

# This is the single output diagnostic expected,
# (without the possibly varying :strerror(ENOSPC) suffix).
printf '%s\n' "head: error writing 'standard output'" > exp

# Memory is bounded in these cases
for item in lines bytes; do
  for N in 0 1; do
    # pipe case
    yes | returns_ 1 timeout 10s head --$item=-$N > /dev/full 2> errt || fail=1
    sed 's/\(head:.*\):.*/\1/' errt > err
    compare exp err || fail=1

    # seekable case
    returns_ 1 timeout 10s head --$item=-$N bigseek > /dev/full 2> errt \
        || fail=1
    sed 's/\(head:.*\):.*/\1/' errt > err
    compare exp err || fail=1
  done
done

Exit $fail
