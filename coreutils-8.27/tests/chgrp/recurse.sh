#!/bin/sh
# ad-hoc tests of chgrp with -R and -H or -L and symlinks

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
print_ver_ chgrp
require_membership_in_two_groups_
require_local_dir_

set _ $groups; shift
g1=$1
g2=$2


# chgrp -R should not traverse a symlink to a directory.
mkdir d e
touch d/dd e/ee
ln -s ../e d/s
chgrp -R $g1 e/ee || fail=1
# This should not should change the group of e/ee
chgrp -R $g2 d
set _ $(ls -ln e/ee); g=$5; test "$g" = $g1 || fail=1
# This must change the group of e/ee, since -L makes
# chgrp traverse the symlink from d/s into e.
chgrp -L -R $g2 d
set _ $(ls -ln e/ee); g=$5; test "$g" = $g2 || fail=1

# This must *not* change the group of e/ee
chgrp -H -R $g1 d
set _ $(ls -ln e/ee); g=$5; test "$g" = $g2 || fail=1

ln -s d link

# This shouldn't change the group of e/ee either.
chgrp -H -R $g1 link || fail=1
set _ $(ls -ln e/ee); g=$5; test "$g" = $g2 || fail=1
# But it *should* change d/dd.
set _ $(ls -ln d/dd); g=$5; test "$g" = $g1 || fail=1

Exit $fail
