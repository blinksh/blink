#!/bin/sh
# Ensure we handle i/o errors correctly in csplit

# Copyright (C) 2015-2017 Free Software Foundation, Inc.

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
print_ver_ csplit
require_gcc_shared_

if ! test -w /dev/full || ! test -c /dev/full; then
  skip_ '/dev/full is required'
fi

# Ensure error messages are in English
LC_ALL=C
export LC_ALL

# Replace fwrite and ferror, always returning an error
cat > k.c <<'EOF' || framework_failure_
#include <stdio.h>
#include <errno.h>

#undef fwrite
#undef fwrite_unlocked

size_t
fwrite (const void *ptr, size_t size, size_t nitems, FILE *stream)
{
  fclose (fopen ("preloaded","w")); /* marker for preloaded interception */
  errno = ENOSPC;
  return 0;
}

size_t
fwrite_unlocked (const void *ptr, size_t size, size_t nitems, FILE *stream)
{
  return fwrite (ptr, size, nitems, stream);
}
EOF

# Get the wording of the OS-dependent ENOSPC message
returns_ 1 seq 1 >/dev/full 2>msgt || framework_failure_
sed 's/seq: write error: //' msgt > msg || framework_failure_

# Create the expected error message
{ printf "%s" "csplit: write error for 'xx01': " ; cat msg ; } > exp \
  || framework_failure_

# compile/link the interception shared library:
gcc_shared_ k.c k.so \
  || skip_ 'failed to build forced-fwrite-failure shared library'

# Split the input, and force fwrite() failure -
# the 'csplit' command should fail with exit code 1
# (checked with 'returns_ 1 ... || fail=1')
seq 10 |
(export LD_PRELOAD=$LD_PRELOAD:./k.so
 returns_ 1 csplit - 1 4 2>out) || fail=1

test -e preloaded || skip_ 'LD_PRELOAD interception failed'

# Ensure we got the expected error message
compare exp out || fail=1

Exit $fail
