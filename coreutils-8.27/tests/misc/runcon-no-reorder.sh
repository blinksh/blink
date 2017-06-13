#!/bin/sh
# Ensure that runcon does not reorder its arguments.

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
print_ver_ runcon

diag='runcon: runcon may be used only on a SELinux kernel'
echo "$diag" > exp || framework_failure_


# This test works even on systems without SELinux.
# On such a system it fails with the above diagnostic, which is fine.
# Before the no-reorder change, it would have failed with a diagnostic
# about -j being an invalid option.
runcon $(id -Z) true -j 2> out && > exp

# When run on a system with no /selinux/context (i.e., in a chroot),
# it chcon fails with this: "runcon: invalid context: \
# root:system_r:unconfined_t:s0-s0:c0.c1023: No such file or directory"
# That diagnostic is ok, too, so map it to the more common one.
case $(cat out) in
  'runcon: invalid context: '*) echo "$diag" > out;;
esac

compare exp out || fail=1

Exit $fail
