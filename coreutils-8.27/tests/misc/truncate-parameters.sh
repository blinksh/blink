#!/bin/sh
# Validate truncate parameter combinations

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
print_ver_ truncate


# must specify at least 1 file
returns_ 1 truncate --size=0 || fail=1

# must specify size. don't default to 0
returns_ 1 truncate file || fail=1

# mixture of absolute size & reference not allowed
returns_ 1 truncate --size=0 --reference=file file || fail=1

# blocks without size is not valid
returns_ 1 truncate --io-blocks --reference=file file || fail=1

# must specify valid numbers
returns_ 1 truncate --size="invalid" file || fail=1

# spaces not significant around size
returns_ 1 truncate --size="> -1" file || fail=1
truncate --size=" >1" file || fail=1 #file now 1
truncate --size=" +1" file || fail=1 #file now 2
test $(stat --format %s file) = 2 || fail=1

# reference allowed with relative size
truncate --size=" +1" -r file file || fail=1 #file now 3
test $(stat --format %s file) = 3 || fail=1

# reference allowed alone also
truncate -r file file || fail=1 #file still 3
test $(stat --format %s file) = 3 || fail=1
truncate -r file file2 || fail=1 #file2 now 3
test $(stat --format %s file2) = 3 || fail=1

Exit $fail
