#!/bin/sh
# Ensure that touch -h works.

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
print_ver_ touch test

ln -s nowhere dangling || framework_failure_
touch file || framework_failure_
ln -s file link || framework_failure_


# These first tests should work on every platform.
# -h does not create files, but it warns.  Use -c to silence warning.
returns_ 1 touch -h no-file 2> err || fail=1
compare /dev/null err && fail=1
touch -h -c no-file 2> err || fail=1
compare /dev/null err || fail=1

# -h works on regular files
touch -h file || fail=1

# -h coupled with -r uses timestamp of the symlink, not the referent.
touch -h -r dangling file || fail=1
test -f nowhere && fail=1

# The remaining tests of -h require kernel support for changing symlink times.
grep '^#define HAVE_UTIMENSAT 1' "$CONFIG_HEADER" > /dev/null ||
grep '^#define HAVE_LUTIMES 1' "$CONFIG_HEADER" > /dev/null ||
  skip_ 'this system lacks the utimensat function'

# Changing time of dangling symlink is okay.
# Skip the test if this fails, but the error text corresponds to
# ENOSYS (possible with old kernel but new glibc).
touch -h dangling 2> err
case $? in
  0) test -f nowhere && fail=1
     compare /dev/null err || fail=1;;
  1) grep 'Function not implemented' err \
       && skip_ 'this system lacks the utimensat function'
     fail=1;;
  *) fail=1;;
esac

# Change the mtime of a symlink.
touch -m -h -d 2009-10-10 link || fail=1
case $(stat --format=%y link) in
  2009-10-10*) ;;
  *) fail=1 ;;
esac
case $(stat --format=%y file) in
  2009-10-10*) fail=1;;
esac

# Test interactions with -.
touch -h - > file || fail=1

# If >&- works, test "touch -ch -" etc.
# >&- apparently does not work in HP-UX 11.23.
# This test is ineffective unless /dev/stdout also works.
# If stdout is open, it is not a symlink.
if env test -w /dev/stdout >/dev/null &&
   env test ! -w /dev/stdout >&-; then
  returns_ 1 touch -h - >&- || fail=1
  touch -h -c - >&- || fail=1
fi

Exit $fail
