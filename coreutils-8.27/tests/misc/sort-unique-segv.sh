#!/bin/sh
# parallel sort with --unique (-u) would segfault

# Copyright (C) 2010-2017 Free Software Foundation, Inc.

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
print_ver_ sort

grep '^#define HAVE_PTHREAD_T 1' "$CONFIG_HEADER" > /dev/null ||
  skip_ 'requires pthreads'

cat <<\EOF > in || framework_failure_







z
zzzzzz
zzzzzzz
zzzzzzz
zzzzzzz
zzzzzzzzz
zzzzzzzzzzz
zzzzzzzzzzzz
EOF

sort --parallel=1 -u in > exp || fail=1

sort --parallel=2 -u -S 10b < in > out || fail=1
compare exp out || fail=1

Exit $fail
