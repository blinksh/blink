#!/bin/sh
# Ensure that "cp -Rf fifo E" unlinks E and retries.
# Up until coreutils-6.10.171, it would not.

# Copyright (C) 2008-2017 Free Software Foundation, Inc.

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
print_ver_ cp

mkfifo_or_skip_ fifo

touch e || framework-failure


# Without -f, expect it to fail.
cp -R fifo e || fail=1

# With -f, it must succeed.
cp -Rf fifo e || fail=1
test -p fifo || fail=1

Exit $fail
