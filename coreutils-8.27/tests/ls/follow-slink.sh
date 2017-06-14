#!/bin/sh
# make sure ls -L always follows symlinks

# Copyright (C) 2000-2017 Free Software Foundation, Inc.

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

LS_FAILURE=2

# Isolate output files from directory being listed
mkdir dir dir/sub dir1 || framework_failure_
cd dir || framework_failure_
ln -s link link || framework_failure_
ln -s ../../dir1 sub/link-to-dir || framework_failure_

# Make sure the symlink was created.
# 'ln -s link link' succeeds, but creates no file on
# systems running some DJGPP-2.03 libc.
ls -F link > /dev/null || framework_failure_


# When explicitly listing a broken link, the command must fail.
returns_ $LS_FAILURE ls -L link 2> /dev/null || fail=1

# When encountering a broken link implicitly, Solaris 9 and OpenBSD 3.4
# list the link, provided no further information about the link needed
# to be printed.  Since POSIX does not specify one way or the other, we
# opt for compatibility (this was broken in 5.3.0 through 5.94).
LC_ALL=C ls -L > ../out-L || fail=1
LC_ALL=C ls -FLR sub > ../out-FLR-sub || fail=1

cd .. || fail=1

cat <<\EOF > exp-L
link
sub
EOF

cat <<\EOF > exp-FLR-sub
sub:
link-to-dir/

sub/link-to-dir:
EOF

compare exp-L out-L || fail=1
compare exp-FLR-sub out-FLR-sub || fail=1

Exit $fail
