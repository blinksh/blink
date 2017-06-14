#!/bin/sh
# prior to coreutils-4.5.3, du -D didn't work in some cases
# Based on an example from Andreas Schwab and/or Michal Svec.
# Also, up to coreutils-8.5, du -L sometimes incorrectly
# counted the space of the followed symlinks.

# Copyright (C) 2002-2017 Free Software Foundation, Inc.

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

mkdir -p a/sub || framework_failure_
ln -s a/sub slink || framework_failure_
touch b || framework_failure_
ln -s .. a/sub/dotdot || framework_failure_
ln -s nowhere dangle || framework_failure_


# This used to fail with the following diagnostic:
# du: 'b': No such file or directory
du -sD slink b > /dev/null 2>&1 || fail=1

# This used to fail to report the dangling symlink.
returns_ 1 du -L dangle > /dev/null 2>&1 || fail=1

# du -L used to mess up, either by counting the symlink's disk space itself
# (-L should follow symlinks, not count their space)
# or (briefly in July 2010) by omitting the entry for "a".
du_L_output=$(du -L a) || fail=1
du_lL_output=$(du -lL a) || fail=1
du_x_output=$(du --exclude=dotdot a) || fail=1
test "X$du_L_output" = "X$du_x_output" || fail=1
test "X$du_lL_output" = "X$du_x_output" || fail=1

Exit $fail
