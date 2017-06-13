#!/bin/sh
# Ensure that rm -rf unremovable-non-dir gives a diagnostic.
# Test both a regular file and a symlink -- it makes a difference to rm.
# With the symlink, rm from coreutils-6.9 would fail with a misleading
# ELOOP diagnostic.

# Copyright (C) 2006-2017 Free Software Foundation, Inc.

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
print_ver_ rm
skip_if_root_

ok=0
mkdir d           &&
  touch d/f       &&
  ln -s f d/slink &&
  chmod a-w d     &&
  ok=1
test $ok = 1 || framework_failure_

mkdir e           &&
  ln -s f e/slink &&
  chmod a-w e     &&
  ok=1
test $ok = 1 || framework_failure_


rm -rf d/f 2> out && fail=1
cat <<\EOF > exp
rm: cannot remove 'd/f': Permission denied
EOF
compare exp out || fail=1

# This used to fail with ELOOP.
rm -rf e 2> out && fail=1
cat <<\EOF > exp
rm: cannot remove 'e/slink': Permission denied
EOF
compare exp out || fail=1

Exit $fail
