#!/bin/sh
# Ensure that chgrp -R does not dereference symlinks.

# Copyright (C) 2006-2017 Free Software Foundation, Inc.

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
print_ver_ chgrp
require_membership_in_two_groups_
require_local_dir_

set _ $groups; shift
g2=$2

mkdir d && touch f && ln -s ../f d/s || framework_failure_


g_init=$(stat --printf=%g f)
chgrp -R $g2 d || fail=1
test $(stat --printf=%g f) = $g_init || fail=1

Exit $fail
