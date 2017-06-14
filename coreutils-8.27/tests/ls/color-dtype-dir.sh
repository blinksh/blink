#!/bin/sh
# Ensure "ls --color" properly colors other-writable and sticky directories.
# Before coreutils-6.2, this test would fail, coloring all three
# directories the same as the first one -- but only on a file system
# with dirent.d_type support.

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
print_ver_ ls

# Don't let a different umask perturb the results.
umask 22

mkdir d other-writable sticky || framework_failure_
chmod o+w other-writable || framework_failure_
chmod o+t sticky || framework_failure_


TERM=xterm ls --color=always > out || fail=1
cat -A out > o1 || fail=1
mv o1 out || fail=1

cat <<\EOF > exp || fail=1
^[[0m^[[01;34md^[[0m$
^[[34;42mother-writable^[[0m$
out$
^[[37;44msticky^[[0m$
EOF

compare exp out || fail=1

rm exp

# Turn off colors for other-writable dirs and ensure
# we fall back to the color for standard directories.

LS_COLORS="ow=:" ls --color=always > out || fail=1
cat -A out > o1 || fail=1
mv o1 out || fail=1

cat <<\EOF > exp || fail=1
^[[0m^[[01;34md^[[0m$
^[[01;34mother-writable^[[0m$
out$
^[[37;44msticky^[[0m$
EOF

compare exp out || fail=1

Exit $fail
