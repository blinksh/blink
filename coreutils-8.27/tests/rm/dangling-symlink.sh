#!/bin/sh
# rm should not prompt before removing a dangling symlink.
# Likewise for a non-dangling symlink.
# But for fileutils-4.1.9, it would do the former and
# for fileutils-4.1.10 the latter.

# Copyright (C) 2002-2017 Free Software Foundation, Inc.

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
print_ver_ rm

ln -s no-file dangle
ln -s / symlink

# Terminate any background processes
cleanup_() { kill $pid 2>/dev/null && wait $pid; }

rm ---presume-input-tty dangle symlink & pid=$!
# The buggy rm (fileutils-4.1.9) would hang here, waiting for input.

# Wait up to 6.3s for rm to remove the files
check_files_removed() {
  local present=0
  sleep $1
  ls -l dangle > /dev/null 2>&1 && present=1
  ls -l symlink > /dev/null 2>&1 && present=1
  test $present = 0
}
retry_delay_ check_files_removed .1 6 || fail=1

cleanup_

Exit $fail
