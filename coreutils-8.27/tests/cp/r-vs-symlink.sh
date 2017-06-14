#!/bin/sh
# cp -r should not create symlinks.  Fixed in fileutils-4.1.5.

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

# Restored old behavior (whereby cp -r preserves symlinks) in 4.1.6,
# though now such usage evokes a warning:
# cp: 'slink': WARNING: using -r to copy symbolic links is not portable

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ cp

echo abc > foo || framework_failure_
ln -s foo slink || framework_failure_
ln -s no-such-file no-file || framework_failure_


# This would fail in 4.1.5, not in 4.1.6.
cp -r no-file junk 2>/dev/null || fail=1

cp -r slink bar 2>/dev/null || fail=1
set x $(ls -l bar); shift; mode=$1
case $mode in
  l*) ;;
  *) fail=1;;
esac

Exit $fail
