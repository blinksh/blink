#!/bin/sh
# Try to remove '.' and '..' recursively.

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

mkdir d || framework_failure_
touch d/a || framework_failure_

# Expected error diagnostic as grep pattern.
exp="^rm: refusing to remove '\.' or '\.\.' directory: skipping '.*'\$"

rmtest()
{
  # Try removing - expecting failure.
  rm -fr "$1" 2> err && fail=1

  # Ensure the expected error diagnostic is output.
  grep "$exp" err || { cat err; fail=1; }

  return $fail
}

rmtest 'd/.'     || fail=1
rmtest 'd/./'    || fail=1
rmtest 'd/.////' || fail=1
rmtest 'd/..'    || fail=1
rmtest 'd/../'   || fail=1


# This test is handled more carefully in r-root.sh
# returns_ 1 rm -fr / 2>/dev/null || fail=1

test -f d/a || fail=1

Exit $fail
