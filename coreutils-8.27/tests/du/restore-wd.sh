#!/bin/sh
# due to a bug in glibc's ftw.c, in some cases, nftw w/FTW_CHDIR
# would not restore the working directory.

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
print_ver_ du

mkdir a b || framework_failure_


# With du from coreutils-4.5.5 and 4.5.6, this would fail with
# du: 'b': No such file or directory

du a b > out || fail=1

Exit $fail
