#!/bin/sh
# Test both cp and mv for their behavior with -if and -fi
# The standards (POSIX and SuS) dictate annoyingly inconsistent behavior.

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
print_ver_ cp mv

skip_if_root_

for i in a b c d e f g h; do
  echo $i > $i || framework_failure_
done
chmod 0 b d f h || framework_failure_
echo y > y || framework_failure_

mv -if a b || fail=1
mv -fi c d < y >/dev/null 2>&1 || fail=1

# Before 4.0s, this would not prompt.
cp -if e f < y > out 2>&1 || fail=1

# Make sure out contains the prompt.
case "$(cat out)" in
  "cp: replace 'f', overriding mode 0000 (---------)?"*) ;;
  *) fail=1 ;;
esac

test -f e || fail=1
test -f f || fail=1
compare e f || fail=1

cp -fi g h < y > out 2>&1 || fail=1
test -f g || fail=1
test -f h || fail=1
compare g h || fail=1

Exit $fail
