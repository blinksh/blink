#!/bin/sh
# Make sure that cp -dR dereferences a symlink arg if its name is
# written with a trailing slash.

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
print_ver_ cp

mkdir dir || framework_failure_
ln -s dir symlink || framework_failure_

cp -dR symlink/ s || fail=1
set $(ls -l s)

# Prior to fileutils-4.0q, the following would have output ...'s -> dir'
# because the trailing slash was removed unconditionally (now you have to
# use the new --strip-trailing-slash option) causing cp to reproduce the
# symlink.  Now, the trailing slash is interpreted by the stat library
# call and so cp ends up dereferencing the symlink and copying the directory.
test "$*" = 'total 0' && : || fail=1

Exit $fail
