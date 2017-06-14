#!/bin/sh
# Ensure that cat -E produces same output as cat, module '$'s,
# even when applied to a file in /proc.

# Copyright (C) 2006-2017 Free Software Foundation, Inc.

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
print_ver_ cat


f=/proc/cpuinfo
test -f $f \
  || skip_ "no $f"


# Yes, parts of /proc/cpuinfo might change between cat runs.
# If that happens, consider choosing a file that's less likely to change,
# or just filter out the changing lines.  The sed filter should help
# to avoid any spurious numeric differences.
cat -E $f | sed 's/[0-9][0-9]*/D/g' | tr -d '$' > out || fail=1
cat    $f | sed 's/[0-9][0-9]*/D/g' | tr -d '$' > exp || fail=1

compare exp out || fail=1

Exit $fail
