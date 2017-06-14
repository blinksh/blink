#!/bin/sh
# inotify-based tail -f didn't flush its initial output before blocking

# Copyright (C) 2009-2017 Free Software Foundation, Inc.

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
print_ver_ tail

# Speedup the non inotify case
fastpoll='-s.1 --max-unchanged-stats=1'

# Terminate any background tail process
cleanup_() { kill $pid 2>/dev/null && wait $pid; }

echo line > in || framework_failure_
# Output should be buffered since we're writing to file
# so we're depending on the flush to write out
tail $fastpoll -f in > out & pid=$!

# Wait for 3.1s for the file to be flushed.
tail_flush()
{
  local delay="$1"
  sleep $delay
  test -s out
}
retry_delay_ tail_flush .1 5 || fail=1

cleanup_

Exit $fail
