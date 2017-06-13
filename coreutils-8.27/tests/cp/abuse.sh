#!/bin/sh
# ensure that cp does not write through a just-copied symlink

# Copyright (C) 2007-2017 Free Software Foundation, Inc.

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

mkdir a b c || framework_failure_
ln -s ../t a/1 || framework_failure_
echo payload > b/1 || framework_failure_

echo "cp: will not copy 'b/1' through just-created symlink 'c/1'" \
  > exp || framework_failure_

# Check both cases: a dangling symlink, and one pointing to a writable file.

for i in dangling-dest existing-dest; do
  test $i = existing-dest && echo i > t
  test $i = dangling-dest && rm -f t

  cp -dR a/1 b/1 c 2> out && fail=1

  compare exp out || fail=1

  # When the destination is a dangling symlink,
  # ensure that cp does not create it.
  test $i = dangling-dest \
    && test -f t && fail=1

  # When the destination symlink points to a writable file,
  # ensure that cp does not change it.
  test $i = existing-dest \
    && case $(cat t) in i);; *) fail=1;; esac
done

Exit $fail
