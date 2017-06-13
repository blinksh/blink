#!/bin/sh
# Ensure that cp -a --link maintains timestamps if possible

# Copyright (C) 2011-2017 Free Software Foundation, Inc.

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

# Check that the timestamps of the symlink are copied
# if we're using hardlink to symlink emulation.
touch file
ln -s file link || framework_failure_
touch -m -h -d 2011-01-01 link ||
  skip_ "Your system doesn't support updating symlink timestamps"
case $(stat --format=%y link) in
  2011-01-01*) ;;
  *) skip_ "Your system doesn't support updating symlink timestamps" ;;
esac

# link.cp is probably a hardlink, but may also be a symlink
# In either case the timestamp should match the original.
cp -al link link.cp || fail=1
case $(stat --format=%y link.cp) in
  2011-01-01*) ;;
  *) fail=1 ;;
esac

Exit $fail
