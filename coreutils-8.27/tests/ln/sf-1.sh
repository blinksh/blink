#!/bin/sh
# Test "ln -sf".

# Copyright (C) 1997-2017 Free Software Foundation, Inc.

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
print_ver_ ln

echo foo > a || framework_failure_

# Check that a target directory of '.' is supported
# and that indirectly specifying the same target and link name
# through that is detected.
ln -s . b || framework_failure_
ln -sf a b > err 2>&1 && fail=1
case $(cat err) in
  *'are the same file') ;;
  *) fail=1 ;;
esac

# Ensure we replace symlinks that don't or can't link to an existing target.
# coreutils-8.22 would fail to replace {ENOTDIR,ELOOP,ENAMETOOLONG}_link below.
name_max_plus1=$(expr $(stat -f -c %l .) + 1)
test $name_max_plus1 -gt 1 || skip_ 'Error determining NAME_MAX'
long_name=$(printf '%0*d' $name_max_plus1 0)
for f in '' f; do
  ln -s$f missing ENOENT_link || fail=1
  ln -s$f a/b ENOTDIR_link || fail=1
  ln -s$f ELOOP_link ELOOP_link || fail=1
  ln -s$f "$long_name" ENAMETOOLONG_link || fail=1
done

Exit $fail
