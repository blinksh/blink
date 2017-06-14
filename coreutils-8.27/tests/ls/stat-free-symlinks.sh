#!/bin/sh
# ensure that ls does not stat a symlink in an unusual case

# Copyright (C) 2007-2017 Free Software Foundation, Inc.

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
print_ver_ ls
require_strace_ stat

touch x || framework_failure_
chmod a+x x || framework_failure_
ln -s x link-to-x || framework_failure_


# ls from coreutils 6.9 would unnecessarily stat a symlink in an unusual case:
# When not coloring orphan and missing entries, and without ln=target,
# ensure that ls -F (or -d, or -l: i.e., when not dereferencing)
# does not stat a symlink to directory, and does still color that
# symlink and an executable file properly.

LS_COLORS='or=0:mi=0:ex=01;32:ln=01;35' \
  strace -qe stat ls -F --color=always x link-to-x > out.tmp 2> err || fail
# Elide info messages strace can send to stdout of the form:
#   [ Process PID=1234 runs in 32 bit mode. ]
sed '/Process PID=/d' out.tmp > out

# With coreutils 6.9 and earlier, this file would contain a
# line showing ls had called stat on "x".
grep '^stat("x"' err && fail=1

# Check that output is colorized, as requested, too.
{
  printf '\033[0m\033[01;35mlink-to-x\033[0m@\n'
  printf '\033[01;32mx\033[0m*\n'
} > exp || fail=1

compare exp out || fail=1

Exit $fail
