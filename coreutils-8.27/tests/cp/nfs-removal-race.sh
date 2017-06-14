#!/bin/sh
# Running cp S D on an NFS client while another client has just removed D
# would lead (w/coreutils-8.16 and earlier) to cp's initial stat call
# seeing (via stale NFS cache) that D exists, so that cp would then call
# open without the O_CREAT flag.  Yet, the open must actually consult
# the server, which confesses that D has been deleted, thus causing the
# open call to fail with ENOENT.
#
# This test simulates that situation by intercepting stat for a nonexistent
# destination, D, and making the stat fill in the result struct for another
# file and return 0.
#
# This test is skipped on systems that lack LD_PRELOAD support; that's fine.
# Similarly, on a system that lacks <dlfcn.h> or __xstat, skipping it is fine.

# Copyright (C) 2012-2017 Free Software Foundation, Inc.

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

# Replace each stat call with a call to this wrapper.
cat > k.c <<'EOF' || framework_failure_
#define _GNU_SOURCE
#include <stdio.h>
#include <sys/types.h>
#include <dlfcn.h>

#define __xstat __xstat_orig

#include <sys/stat.h>
#include <stddef.h>

#undef __xstat

int
__xstat (int ver, const char *path, struct stat *st)
{
  static int (*real_stat)(int ver, const char *path, struct stat *st) = NULL;
  fclose(fopen("preloaded", "w"));
  if (!real_stat)
    real_stat = dlsym (RTLD_NEXT, "__xstat");
  /* When asked to stat nonexistent "d",
     return results suggesting it exists. */
  return real_stat (ver, *path == 'd' && path[1] == 0 ? "d2" : path, st);
}
EOF

# Then compile/link it:
gcc_shared_ k.c k.so \
  || framework_failure_ 'failed to build shared library'

touch d2 || framework_failure_
echo xyz > src || framework_failure_

# Finally, run the test:
LD_PRELOAD=$LD_PRELOAD:./k.so cp src d || fail=1

test -f preloaded || skip_ 'LD_PRELOAD was ineffective?'

compare src d || fail=1
Exit $fail
