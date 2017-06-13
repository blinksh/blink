#!/bin/sh
# Show that we've eliminated most of ls' failing getxattr syscalls,
# regardless of how many files are in a directory we list.
# This test is skipped on systems that lack LD_PRELOAD support; that's fine.
# Similarly, on a system that lacks getxattr altogether, skipping it is fine.

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
print_ver_ ls
require_gcc_shared_

# Replace each getxattr and lgetxattr call with a call to these stubs.
# Count those and write the total number of calls to the file "x"
# via a global destructor.
cat > k.c <<'EOF' || framework_failure_
#include <errno.h>
#include <stdio.h>
#include <sys/types.h>

static unsigned long int n_calls;

static void __attribute__ ((destructor))
print_call_count (void)
{
  FILE *fp = fopen ("x", "w"); if (!fp) return;
  fprintf (fp, "%lu\n", n_calls); fclose (fp);
}

static ssize_t incr () { ++n_calls; errno = ENOTSUP; return -1; }
ssize_t getxattr (const char *path, const char *name, void *value, size_t size)
{ return incr (); }
ssize_t lgetxattr(const char *path, const char *name, void *value, size_t size)
{ return incr (); }
EOF

# Then compile/link it:
gcc_shared_ k.c k.so \
  || framework_failure_ 'failed to build shared library'

# Create a few files:
seq 20 | xargs touch || framework_failure_

# Finally, run the test:
LD_PRELOAD=$LD_PRELOAD:./k.so ls --color=always -l . || fail=1

test -f x || skip_ "internal test failure: maybe LD_PRELOAD doesn't work?"

# Ensure that there were no more than 3 *getxattr calls.
n_calls=$(cat x)
test "$n_calls" -le 3 || fail=1

Exit $fail
