#!/bin/sh
# Ensure that several programs work fine, even with stdout initially closed.
# This is effectively a test of closeout.c's close_stdout function.

# Copyright (C) 2004-2017 Free Software Foundation, Inc.

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

p=$abs_top_builddir


# Ensure these exit successfully, even though stdout is closed,
# because they generate no output.
touch a
cp a b >&- || fail=1
test -f b || fail=1
chmod o-w . >&- || fail=1
ln a c >&- || fail=1
rm c >&- || fail=1
mkdir d >&- || fail=1
mv d e >&- || fail=1
rmdir e >&- || fail=1
touch e >&- || fail=1
sleep 0 >&- || fail=1
"$p/src/true" >&- || fail=1
"$p/src/printf" '' >&- || fail=1

# If >&- works, ensure these fail, because stdout is closed and they
# *do* generate output.  >&- apparently does not work in HP-UX 11.23.
# This test is ineffective unless /dev/stdout also works.
if "$p/src/test" -w /dev/stdout >/dev/null &&
   "$p/src/test" ! -w /dev/stdout >&-; then
  returns_ 1 "$p/src/printf" 'foo' >&- 2>/dev/null || fail=1
  returns_ 1 cp --verbose a b >&- 2>/dev/null || fail=1
  rm -Rf tmpfile-?????? || fail=1
  returns_ 1 mktemp tmpfile-XXXXXX >&- 2>/dev/null || fail=1
  returns_ 1 mktemp tmpfile-XXXXXX -q >&- 2>/dev/null || fail=1
  case $(echo tmpfile-??????) in 'tmpfile-??????') ;; *) fail=1 ;; esac
fi

# Likewise for /dev/full, if /dev/full works.
if test -w /dev/full && test -c /dev/full; then
  returns_ 1 "$p/src/printf" 'foo' >/dev/full 2>/dev/null || fail=1
  returns_ 1 cp --verbose a b >/dev/full 2>/dev/null || fail=1
  rm -Rf tmpdir-?????? || fail=1
  returns_ 1 mktemp -d tmpdir-XXXXXX >/dev/full 2>/dev/null || fail=1
  returns_ 1 mktemp -d -q tmpdir-XXXXXX >/dev/full 2>/dev/null || fail=1
  case $(echo tmpfile-??????) in 'tmpfile-??????') ;; *) fail=1 ;; esac
fi

Exit $fail
