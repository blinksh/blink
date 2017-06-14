#!/bin/sh
# stat --format tests

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
print_ver_ stat


# ensure that stat properly handles a format string ending with %
for i in $(seq 50); do
  fmt=$(printf "%${i}s" %)
  out=$(stat --form="$fmt" .)
  test "$out" = "$fmt" || fail=1
done


# ensure QUOTING_STYLE is honored by %N
touch "'" || framework_failure_
# Default since v8.25
stat -c%N \' >> out || fail=1
# Default before v8.25
QUOTING_STYLE=locale stat -c%N \' >> out || fail=1
cat <<\EOF >exp
"'"
'\''
EOF
compare exp out || fail=1


Exit $fail
