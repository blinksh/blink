#!/bin/sh
# Verify that internal failure in chroot gives exact status.

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
print_ver_ chroot pwd

# These tests verify exact status of internal failure; since none of
# them actually run a command, we don't need root privileges
returns_ 125 chroot || fail=1 # missing argument
returns_ 125 chroot --- / true || fail=1 # unknown option

# chroot("/") succeeds for non-root users on some systems, but not all.
if chroot / true ; then
  can_chroot_root=1
  returns_ 2 chroot / sh -c 'exit 2' || fail=1 # exit status propagation
  returns_ 126 chroot / .  || fail=1# invalid command
  returns_ 127 chroot / no_such || fail=1 # no such command
else
  test $? = 125 || fail=1
  can_chroot_root=0
fi

# Ensure that --skip-chdir fails with a non-"/" argument.
cat <<\EOF > exp || framework_failure_
chroot: option --skip-chdir only permitted if NEWROOT is old '/'
Try 'chroot --help' for more information.
EOF
chroot --skip-chdir . env pwd >out 2>err && fail=1
compare /dev/null out || fail=1
compare exp err || fail=1

# Ensure we chdir("/") appropriately when NEWROOT is old "/".
if test $can_chroot_root = 1; then
  ln -s / isroot || framework_failure_
  for dir in '/' '/.' '/../' isroot; do
    # Verify that chroot(1) succeeds and performs chdir("/")
    # (chroot(1) of coreutils-8.23 failed to run the latter).
    curdir=$(chroot "$dir" env pwd) || fail=1
    test "$curdir" = '/' || fail=1

    # Test the "--skip-chdir" option.
    curdir=$(chroot --skip-chdir "$dir" env pwd) || fail=1
    test "$curdir" = '/' && fail=1
  done
fi

Exit $fail
