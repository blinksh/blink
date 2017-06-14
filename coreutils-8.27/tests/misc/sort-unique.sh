#!/bin/sh
# Test 'sort -u'.

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

cat > in <<\EOF
1
2
1
3
EOF

cat > exp <<\EOF
1
2
3
EOF

for LOC in C "$LOCALE_FR" "$LOCALE_FR_UTF8"; do
  test -z "$LOC" && continue

  LC_ALL=$LOC sort -u in > out || { fail=1; break; }
  compare exp out || { fail=1; break; }
done

Exit $fail
