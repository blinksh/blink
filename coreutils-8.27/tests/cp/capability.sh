#!/bin/sh
# Ensure cp --preserves copies capabilities

# Copyright (C) 2010-2017 Free Software Foundation, Inc.

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
require_root_
working_umask_or_skip_


grep '^#define HAVE_CAP 1' $CONFIG_HEADER > /dev/null \
  || skip_ "configured without libcap support"

(setcap --help) 2>&1 |grep 'usage: setcap' > /dev/null \
  || skip_ "setcap utility not found"
(getcap --help) 2>&1 |grep 'usage: getcap' > /dev/null \
  || skip_ "getcap utility not found"


touch file || framework_failure_
chown $NON_ROOT_USERNAME file || framework_failure_

setcap 'cap_net_bind_service=ep' file ||
  skip_ "setcap doesn't work"
getcap file | grep cap_net_bind_service >/dev/null ||
  skip_ "getcap doesn't work"

cp --preserve=xattr file copy1 || fail=1

# Before coreutils 8.5 the capabilities would not be preserved,
# as the owner was set _after_ copying xattrs, thus clearing any capabilities.
cp --preserve=all   file copy2 || fail=1

for file in copy1 copy2; do
  getcap $file | grep cap_net_bind_service >/dev/null || fail=1
done

Exit $fail
