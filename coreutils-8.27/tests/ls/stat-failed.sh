#!/bin/sh
# Verify that ls works properly when it fails to stat a file that is
# not mentioned on the command line.

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
skip_if_root_

LS_MINOR_PROBLEM=1

mkdir d || framework_failure_
ln -s / d/s || framework_failure_
chmod 600 d || framework_failure_


returns_ 1 ls -Log d > out || fail=1

# Linux 2.6.32 client with Isilon OneFS always returns d_type==DT_DIR ('d')
# Newer Linux 3.10.0 returns the more correct DT_UNKNOWN ('?')
grep '^[l?]?' out || skip_ 'unrecognized d_type returned'

cat <<\EOF > exp || framework_failure_
total 0
?????????? ? ?            ? s
EOF

sed 's/^l/?/' out | compare exp - || fail=1

# Ensure that the offsets in --dired output are accurate.
rm -f out exp
returns_ $LS_MINOR_PROBLEM ls --dired -l d > out || fail=1

cat <<\EOF > exp || framework_failure_
  total 0
  ?????????? ? ? ? ?            ? s
//DIRED// 44 45
//DIRED-OPTIONS// --quoting-style=literal
EOF

sed 's/^  l/  ?/' out | compare exp - || fail=1

Exit $fail
