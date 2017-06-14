#!/bin/sh
# Ensure we handle file systems returning no SELinux context,
# which triggered a segmentation fault in coreutils-8.22.
# This test is skipped on systems that lack LD_PRELOAD support; that's fine.
# Similarly, on a system that lacks lgetfilecon altogether, skipping it is fine.

# Copyright (C) 2014-2017 Free Software Foundation, Inc.

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
print_ver_ cp
require_gcc_shared_
require_selinux_

# Replace each getfilecon and lgetfilecon call with a call to these stubs.
cat > k.c <<'EOF' || framework_failure_
#include <stdio.h>
#include <selinux/selinux.h>
#include <errno.h>

int getfilecon (const char *path, char **con)
{
  /* Leave a marker so we can identify if the function was intercepted.  */
  fclose(fopen("preloaded", "w"));

  errno=ENODATA;
  return -1;
}

int lgetfilecon (const char *path, char **con)
{ return getfilecon (path, con); }
EOF

# Then compile/link it:
gcc_shared_ k.c k.so \
  || skip_ 'failed to build SELinux shared library'

touch file_src

# New file with SELinux context optionally included
LD_PRELOAD=$LD_PRELOAD:./k.so cp -a file_src file_dst || fail=1

# Existing file with SELinux context optionally included
LD_PRELOAD=$LD_PRELOAD:./k.so cp -a file_src file_dst || fail=1

# ENODATA should give an immediate error when required to preserve ctx
# This is debatable, and maybe we should not fail when no context available?
( export LD_PRELOAD=$LD_PRELOAD:./k.so
  returns_ 1 cp --preserve=context file_src file_dst ) || fail=1

test -e preloaded || skip_ 'LD_PRELOAD interception failed'

Exit $fail
