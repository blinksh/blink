#!/bin/sh

# Copyright (C) 2000-2017 Free Software Foundation, Inc.

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

working_umask_or_skip_

# Run the setgid check from the just-created directory.
skip_if_setgid_

{
  mkdir foo bar
  mkdir -p a/b/c d e g
  ln -s d/a sym
  touch f
} || framework_failure_

# With 4.0.37 and earlier (back to when?), this would fail
# with the failed assertion from dirname.c due to the trailing slash.
cp -R --parents foo/ bar || fail=1

# Exercise the make_path and re_protect code in cp.c.
# FIXME: compare verbose output with expected output.
cp --verbose -a --parents a/b/c d > /dev/null 2>&1 || fail=1
test -d d/a/b/c || fail=1

# With 6.7 and earlier, cp --parents f/g d would mistakenly create a
# directory d/f, even though f is a regular file.
returns_ 1 cp --parents f/g d 2>/dev/null || fail=1
test -d d/f && fail=1

# Check that re_protect works.
chmod go=w d/a || framework_failure_
cp -a --parents d/a/b/c e || fail=1
cp -a --parents sym/b/c g || fail=1
p=$(ls -ld e/d|cut -b-10); case $p in drwxr-xr-x);; *) fail=1;; esac
p=$(ls -ld e/d/a|cut -b-10); case $p in drwx-w--w-);; *) fail=1;; esac
p=$(ls -ld g/sym|cut -b-10); case $p in drwx-w--w-);; *) fail=1;; esac
p=$(ls -ld e/d/a/b/c|cut -b-10); case $p in drwxr-xr-x);; *) fail=1;; esac
p=$(ls -ld g/sym/b/c|cut -b-10); case $p in drwxr-xr-x);; *) fail=1;; esac

# Before 8.25 cp --parents --no-preserve=mode would copy
# the mode bits from the source directories
{
  mkdir -p np/b &&
  chmod 0700 np &&
  touch np/b/file &&
  chmod 775 np/b/file &&
  mkdir np_dest
} || framework_failure_
cp --parents --no-preserve=mode np/b/file np_dest/ || fail=1
p=$(ls -ld np_dest/np|cut -b-10); case $p in drwxr-xr-x);; *) fail=1;; esac

Exit $fail
