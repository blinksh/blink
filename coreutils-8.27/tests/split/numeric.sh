#!/bin/sh
# Show that split --numeric-suffixes[=from] works.

# Copyright (C) 2012-2017 Free Software Foundation, Inc.

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
print_ver_ split

# Check default start from 0
printf '1\n2\n3\n4\n5\n' > in || framework_failure_
split --numeric-suffixes --lines=2 in || fail=1
cat <<\EOF > exp-1
1
2
EOF
cat <<\EOF > exp-2
3
4
EOF
cat <<\EOF > exp-3
5
EOF
compare exp-1 x00 || fail=1
compare exp-2 x01 || fail=1
compare exp-3 x02 || fail=1

# Check --numeric-suffixes=X
split --numeric-suffixes=1 --lines=2 in || fail=1
cat <<\EOF > exp-1
1
2
EOF
cat <<\EOF > exp-2
3
4
EOF
cat <<\EOF > exp-3
5
EOF
compare exp-1 x01 || fail=1
compare exp-2 x02 || fail=1
compare exp-3 x03 || fail=1

# Check that split failed when suffix length is not large enough for
# the numerical suffix start value
returns_ 1 split -a 3 --numeric-suffixes=1000 in 2>/dev/null || fail=1

# check invalid --numeric-suffixes start values are flagged
returns_ 1 split --numeric-suffixes=-1 in 2> /dev/null || fail=1
returns_ 1 split --numeric-suffixes=one in 2> /dev/null || fail=1

Exit $fail
