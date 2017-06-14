#!/bin/sh
# see if chgrp can change the group of a symlink

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

set _ $groups; shift
g1=$1
g2=$2

touch f
ln -s f symlink

chgrp -h $g2 symlink 2> /dev/null
set _ $(ls -ln symlink)
g=$5
test "$g" = $g2 ||
  skip_ "your system doesn't support changing the owner or group" \
      "of a symbolic link."


chgrp $g1 f
set _ $(ls -ln f); g=$5; test "$g" = $g1 || fail=1

chgrp -h $g2 symlink || fail=1
set _ $(ls -ln f); g=$5; test "$g" = $g1 || fail=1
set _ $(ls -ln symlink); g=$5; test "$g" = $g2 || fail=1

# This should not change the group of f.
chgrp -h $g2 symlink || fail=1
set _ $(ls -ln f); g=$5; test "$g" = $g1 || fail=1
set _ $(ls -ln symlink); g=$5; test "$g" = $g2 || fail=1

chgrp $g2 f
set _ $(ls -ln f); g=$5; test "$g" = $g2 || fail=1

# This *should* change the group of f.
# Though note that the diagnostic you'd get with -c is misleading in that
# it says the 'group of 'symlink'' has been changed.
chgrp --dereference $g1 symlink
set _ $(ls -ln f); g=$5; test "$g" = $g1 || fail=1
set _ $(ls -ln symlink); g=$5; test "$g" = $g2 || fail=1

Exit $fail
