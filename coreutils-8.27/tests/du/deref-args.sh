#!/bin/sh
# Ensure that --dereference-args (-D) gives reasonable names.
# This test would fail for coreutils-5.0.91.

# Copyright (C) 2003-2017 Free Software Foundation, Inc.

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
print_ver_ du

mkdir -p dir/a || framework_failure_
ln -s dir slink || framework_failure_
printf %65536s x > 64k || framework_failure_
ln -s 64k slink-to-64k || framework_failure_


du -D slink | sed 's/^[0-9][0-9]*	//' > out
# Ensure that the trailing slash is preserved and handled properly.
du -D slink/ | sed 's/^[0-9][0-9]*	//' >> out

# Ensure that -D makes du dereference even symlinks to non-directories.
# Be sure to use --apparent-size.  Otherwise, we'd get varying block counts
# depending on file system type (e.g. 68 on ext3 vs. 64 on tmpfs and 72
# on SELinux-enabled systems).
du --apparent-size --block-size=1K -D slink-to-64k >> out
cat <<\EOF > exp
slink/a
slink
slink/a
slink/
64	slink-to-64k
EOF

compare exp out || fail=1

Exit $fail
