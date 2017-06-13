#!/bin/sh
# Ensure "install -C" compares owner and group.

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
require_root_
skip_if_setgid_
skip_if_nondefault_group_

u1=1
u2=2
g1=1
g2=2


echo test > a || framework_failure_
echo "'a' -> 'b'" > out_installed_first
echo "removed 'b'
'a' -> 'b'" > out_installed_second
> out_empty

# destination file does not exist
ginstall -Cv -o$u1 -g$g1 a b > out || fail=1
compare out out_installed_first || fail=1

# destination file exists
ginstall -Cv -o$u1 -g$g1 a b > out || fail=1
compare out out_empty || fail=1

# destination file exists but -C is not given
ginstall -v -o$u1 -g$g1 a b > out || fail=1
compare out out_installed_second || fail=1

# destination file exists but owner differs
ginstall -Cv -o$u2 -g$g1 a b > out || fail=1
compare out out_installed_second || fail=1
ginstall -Cv -o$u2 -g$g1 a b > out || fail=1
compare out out_empty || fail=1

# destination file exists but group differs
ginstall -Cv -o$u2 -g$g2 a b > out || fail=1
compare out out_installed_second || fail=1
ginstall -Cv -o$u2 -g$g2 a b > out || fail=1
compare out out_empty || fail=1

# destination file exists but owner differs from getuid ()
ginstall -Cv -o$u2 a b > out || fail=1
compare out out_installed_second || fail=1
ginstall -Cv a b > out || fail=1
compare out out_installed_second || fail=1
ginstall -Cv a b > out || fail=1
compare out out_empty || fail=1

# destination file exists but group differs from getgid ()
ginstall -Cv -g$g2 a b > out || fail=1
compare out out_installed_second || fail=1
ginstall -Cv a b > out || fail=1
compare out out_installed_second || fail=1
ginstall -Cv a b > out || fail=1
compare out out_empty || fail=1

Exit $fail
