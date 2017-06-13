#!/bin/sh
# Make sure ls properly handles dangling symlinks vs. ls's -L, -H, options.

# Copyright (C) 2003-2017 Free Software Foundation, Inc.

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

LS_MINOR_PROBLEM=1
LS_FAILURE=2

ln -s no-such-file dangle || framework_failure_
mkdir -p dir/sub || framework_failure_
ln -s dir slink-to-dir || framework_failure_
mkdir d || framework_failure_
ln -s no-such d/dangle || framework_failure_
printf '? dangle\n' > subdir_Li_exp || framework_failure_
printf 'total 0\n? dangle\n' > subdir_Ls_exp || framework_failure_

# This must exit nonzero.
returns_ $LS_FAILURE ls -L dangle > /dev/null 2>&1 || fail=1
# So must this.
returns_ $LS_FAILURE ls -H dangle > /dev/null 2>&1 || fail=1

# This must exit successfully.
ls dangle >> out || fail=1

ls slink-to-dir >> out 2>&1 || fail=1
ls -H slink-to-dir >> out 2>&1 || fail=1
ls -L slink-to-dir >> out 2>&1 || fail=1

cat <<\EOF > exp
dangle
sub
sub
sub
EOF

compare exp out || fail=1

# Ensure that ls -Li prints "?" as the inode of a dangling symlink.
rm -f out
returns_ $LS_MINOR_PROBLEM ls -Li d > out 2>/dev/null || fail=1
compare subdir_Li_exp out || fail=1

# Ensure that ls -Ls prints "?" as the allocation of a dangling symlink.
rm -f out
returns_ $LS_MINOR_PROBLEM ls -Ls d > out 2>/dev/null || fail=1
compare subdir_Ls_exp out || fail=1

Exit $fail
