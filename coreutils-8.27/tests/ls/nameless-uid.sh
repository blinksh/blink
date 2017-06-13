#!/bin/sh
# Ensure that ls -l works on files with nameless uid and/or gid

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
print_ver_ ls

require_root_
require_perl_

nameless_uid=$($PERL -e '
  foreach my $i (1000..16*1024) { getpwuid $i or (print "$i\n"), exit }
')

if test x$nameless_uid = x; then
  skip_ "couldn't find a nameless UID"
fi

touch f || framework_failure_
chown $nameless_uid f || framework_failure_


set -- $(ls -o f) || fail=1
test $3 = $nameless_uid || fail=1

Exit $fail
