#!/bin/sh
# In coreutils-8.12, rm,du,chmod, etc. would use too much memory
# when processing a directory with many entries (as in > 100,000).

# Copyright (C) 2011-2017 Free Software Foundation, Inc.

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
print_ver_ rm du chmod
expensive_

mkdir d2 \
  && touch d2/f || framework_failure_

# Restrict memory.  Each of these coreutils-8.12 programs would fail
# with a diagnostic like "rm: fts_read failed: Cannot allocate memory".
vm=$(get_min_ulimit_v_ du -sh d2) \
  || skip_ "this shell lacks ulimit support"

# With many files in a single directory...
mkdir d || framework_failure_
seq --format="d/%06g" 200000 | xargs touch || framework_failure_

# Allow 35MiB more memory as for the trivial case above.
(ulimit -v $(($vm + 35000)) && du -sh d) || fail=1

vm=$(get_min_ulimit_v_ chmod -R 700 d2) \
  || skip_ "this shell lacks ulimit support"
(ulimit -v $(($vm + 35000)) && chmod -R 700 d) || fail=1

vm=$(get_min_ulimit_v_ rm -rf d2) \
  || skip_ "this shell lacks ulimit support"
(ulimit -v $(($vm + 35000)) && rm -rf d) || fail=1

Exit $fail
