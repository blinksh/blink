#!/bin/sh
# A directory may not replace an existing file.

# Copyright (C) 2001-2017 Free Software Foundation, Inc.

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

mkdir dir || framework_failure_
touch file || framework_failure_


# In 4.0.35, this cp invocation silently succeeded.
returns_ 1 cp -R dir file 2>/dev/null || fail=1

# Make sure file is not replaced with a directory.
# In 4.0.35, it was.
test -f file || fail=1

Exit $fail
