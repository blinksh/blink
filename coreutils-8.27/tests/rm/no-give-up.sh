#!/bin/sh
# With rm from coreutils-5.2.1 and earlier, 'rm -r' would mistakenly
# give up too early under some conditions.

# Copyright (C) 2004-2017 Free Software Foundation, Inc.

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
print_ver_ rm
require_root_

mkdir d || framework_failure_
touch d/f || framework_failure_
chown -R $NON_ROOT_USERNAME d || framework_failure_

# Ensure that non-root can access files in root-owned ".".
chmod go=x . || framework_failure_


# This must fail, since '.' is not writable by $NON_ROOT_USERNAME.
returns_ 1 chroot --skip-chdir --user=$NON_ROOT_USERNAME / env PATH="$PATH" \
  rm -rf d 2>/dev/null || fail=1

# d must remain.
test -d d || fail=1

# f must have been removed.
test -f d/f && fail=1

Exit $fail
