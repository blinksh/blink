#!/bin/sh
# Ensure "install -C" compares SELinux context.

# Copyright (C) 2008-2017 Free Software Foundation, Inc.

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
print_ver_ ginstall
require_selinux_
skip_if_nondefault_group_

echo test > a || framework_failure_
chcon -u system_u a || skip_ "chcon doesn't work"

echo "'a' -> 'b'" > out_installed_first
echo "removed 'b'
'a' -> 'b'" > out_installed_second
> out_empty

# destination file does not exist
ginstall -Cv --preserve-context a b > out || fail=1
compare out out_installed_first || fail=1

# destination file exists
ginstall -Cv --preserve-context a b > out || fail=1
compare out out_empty || fail=1

# destination file exists but -C is not given
ginstall -v --preserve-context a b > out || fail=1
compare out out_installed_second || fail=1

# destination file exists but SELinux context differs
chcon -u unconfined_u a || skip_ "chcon doesn't work"
ginstall -Cv --preserve-context a b > out || fail=1
compare out out_installed_second || fail=1
ginstall -Cv --preserve-context a b > out || fail=1
compare out out_empty || fail=1

Exit $fail
