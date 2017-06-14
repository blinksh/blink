#!/bin/sh
# exercise 'sort -h' in locales where thousands separator is blank

# Copyright (C) 2016-2017 Free Software Foundation, Inc.

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

TEST_LOCALE='sv_SE'

test "$(LC_ALL="$TEST_LOCALE" locale thousands_sep)" = ' ' ||
  skip_ 'The Swedish locale with blank thousands separator is unavailable.'

tee exp1 exp3 > in << _EOF_
1       1k      1 M     4 003   1M
2k      2M      2 k     4 002   2
3M      3       3 G     4 001   3k
_EOF_

cat > exp2 << _EOF_
3M      3       3 G     4 001   3k
1       1k      1 M     4 003   1M
2k      2M      2 k     4 002   2
_EOF_

cat > exp5 << _EOF_
3M      3       3 G     4 001   3k
2k      2M      2 k     4 002   2
1       1k      1 M     4 003   1M
_EOF_

for i in 1 2 3 5; do
  LC_ALL="$TEST_LOCALE" sort -h -k $i "in" > "out${i}" || fail=1
  compare "exp${i}" "out${i}" || fail=1
done

Exit $fail
