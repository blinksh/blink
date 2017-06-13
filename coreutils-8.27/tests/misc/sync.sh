#!/bin/sh
# Test various sync(1) operations

# Copyright (C) 2015-2017 Free Software Foundation, Inc.

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
print_ver_ sync

touch file

# fdatasync+syncfs is nonsensical
returns_ 1 sync --data --file-system || fail=1

# fdatasync needs an operand
returns_ 1 sync -d || fail=1

# Test syncing of file (fsync) (little side effects)
sync file || fail=1

# Ensure multiple args are processed and diagnosed
returns_ 1 sync file nofile || fail=1

# Ensure inaccessible dirs give an appropriate error
mkdir norw || framework_failure_
chmod 0 norw || framework_failure_
if ! test -r norw; then
  sync norw 2>err
  printf "sync: error opening 'norw': Permission denied\n" >exp
  compare exp err || fail=1
fi

if test "$fail" != '1'; then
  # Ensure a fifo doesn't block
  mkfifo_or_skip_ fifo
  returns_ 124 timeout 10 sync fifo && fail=1
fi

Exit $fail
