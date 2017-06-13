#!/bin/sh
# exercise du's --max-depth=N option

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
print_ver_ du

mkdir -p a/b/c/d/e || framework_failure_
printf 'a/b/c\na/b\na\n' > exp || framework_failure_

du --max-depth=2 a > out 2>err || fail=1

# Remove the sizes.  They vary between file systems.
cut -f2- out > k && mv k out
compare exp out || fail=1
compare /dev/null err || fail=1

# Repeat, but use -d 1.
printf 'a/b\na\n' > exp || framework_failure_
du -d 1 a > out 2>err || fail=1
cut -f2- out > k && mv k out
compare exp out || fail=1
compare /dev/null err || fail=1

Exit $fail
