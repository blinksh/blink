#!/bin/sh
# Test SELinux-related options.

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
print_ver_ chcon cp ls mv stat

require_root_
require_selinux_
skip_if_mcstransd_is_running_

# Create a regular file, dir, fifo.
touch f || framework_failure_
mkdir d s1 s2 || framework_failure_
mkfifo_or_skip_ p


# special context that works both with and without mcstransd
ctx='root:object_r:tmp_t'
mls_enabled_ && ctx="$ctx:s0"

chcon $ctx f d p ||
  skip_ '"chcon '$ctx' ..." failed'

# inspect that context with both ls -Z and stat.
for i in d f p; do
  c=$(ls -dogZ $i|cut -d' ' -f3); test x$c = x$ctx || fail=1
  c=$(stat --printf %C $i); test x$c = x$ctx || fail=1
done

# ensure that ls -l output includes the ".".
c=$(ls -l f|cut -c11); test "$c" = . || fail=1

# Copy with an invalid context and ensure it fails
# Note this may succeed when root and selinux is in permissive mode
if test "$(getenforce)" = Enforcing; then
  returns_ 1 cp --context='invalid-selinux-context' f f.cp || fail=1
fi

# Copy each to a new directory and ensure that context is preserved.
cp -r --preserve=all d f p s1 || fail=1
for i in d f p; do
  c=$(stat --printf %C s1/$i); test x$c = x$ctx || fail=1
done

# Now, move each to a new directory and ensure that context is preserved.
mv d f p s2 || fail=1
for i in d f p; do
  c=$(stat --printf %C s2/$i); test x$c = x$ctx || fail=1
done

Exit $fail
