#!/bin/sh
# Ensure dd recognizes failure to write to stderr.

# Copyright (C) 2009-2017 Free Software Foundation, Inc.

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
print_ver_ dd

p=$abs_top_builddir


# Ensure this exits successfully, even though stderr is closed,
# because it generates no stderr output.
dd --help >/dev/null 2>&- || fail=1

# If 2>&- works, ensure this fails, because stderr is closed and it
# *does* generate output.  2>&- apparently does not work in HP-UX 11.23.
# This test is ineffective unless /dev/stderr also works.
# This exposes a failure present in 6.11 through 7.5.
if "$p/src/test" -w /dev/stderr 2>/dev/null &&
   "$p/src/test" ! -w /dev/stderr 2>&-; then
  : | returns_ 1 dd 2>&- || fail=1
fi

# Likewise for /dev/full, if /dev/full works.
if test -w /dev/full && test -c /dev/full; then
  : | returns_ 1 dd 2>/dev/full || fail=1
fi

Exit $fail
