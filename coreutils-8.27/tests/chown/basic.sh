#!/bin/sh
# make sure chown --from=... works

# Copyright (C) 2001-2017 Free Software Foundation, Inc.

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
print_ver_ chown
require_root_

touch f || framework_failure_

chown -R --preserve-root 0:1 f

# Make sure the owner and group are 0 and 1 respectively.
set _ $(ls -n f); shift; test "$3:$4" = 0:1 || fail=1

# Make sure the correct diagnostic is output
# Note we output a name even though an id was specified.
chown -v --from=42 43 f > out || fail=1
printf "ownership of 'f' retained as $(id -nu)\n" > exp
compare exp out || fail=1

# Ensure diagnostics work for non existent files.
returns_ 1 chown -v 0 nf > out || fail=1
printf "failed to change ownership of 'nf' to 0\n" > exp
compare exp out || fail=1

chown --from=0:1 2:010 f || fail=1

# And now they should be 2 and 10 respectively.
set _ $(ls -n f); shift; test "$3:$4" = 2:10 || fail=1

ln -s f slink
# Applying chown to a symlink with --no-dereference
# should change only the link.
chown --no-dereference 0:1 slink || fail=1
# owner/group on the symlink should be set
set _ $(ls -n slink); shift; test "$3:$4" = 0:1 || fail=1
# owner/group on the referent should remain unchanged
set _ $(ls -n f);     shift; test "$3:$4" = 2:10 || fail=1

chown --no-dereference --from=0:1 2:010 slink || fail=1
# owner/group on the symlink should be changed
set _ $(ls -n slink); shift; test "$3:$4" = 2:10 || fail=1

Exit $fail
