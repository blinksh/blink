#!/bin/sh
# Make sure that ls -i works properly on symlinks.

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
print_ver_ ls

touch f || framework_failure_
ln -s f slink || framework_failure_


# When listed explicitly:

set x $(ls -Ci f slink); shift
test $# = 4 || fail=1
# The inode numbers should differ.
test "$1" != "$3" || fail=1

set x $(ls -CLi f slink); shift
test $# = 4 || fail=1
# With -L, they must be the same.
test "$1" = "$3" || fail=1

set x $(ls -CHi f slink); shift
test $# = 4 || fail=1
# With -H, they must be the same, too, from the command line.
# Note that POSIX says -H must make ls dereference only
# symlinks (specified on the command line) to directories,
# but the historical BSD meaning of -H is to dereference
# any symlink given on the command line.  For compatibility GNU ls
# implements the BSD semantics.
test "$1" = "$3" || fail=1

# When listed from a directory:

set x $(ls -Ci); shift
test $# = 4 || fail=1
# The inode numbers should differ.
test "$1" != "$3" || fail=1

set x $(ls -CLi); shift
test $# = 4 || fail=1
# With -L, they must be the same.
test "$1" = "$3" || fail=1

set x $(ls -CHi); shift
test $# = 4 || fail=1
# With -H, they must be different from inside a directory.
test "$1" != "$3" || fail=1

Exit $fail
