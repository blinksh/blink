#!/bin/sh
# Demonstrate using a combination of --reference and --date to
# set the time of a file back by an arbitrary amount.

# Copyright (C) 2004-2017 Free Software Foundation, Inc.

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
print_ver_ touch

TZ=UTC0 touch --date='2004-01-16 12:00 +0000' f || framework_failure_


# Set times back by 5 days.
touch --ref f --date='-5 days' f || fail=1

TZ=UTC0 ls -og --time-style=+%Y-%m-%d f > out.1 || fail
sed 's/ f$//;s/.* //' out.1 > out

cat <<\EOF > exp || fail=1
2004-01-11
EOF

compare exp out || fail=1

Exit $fail
