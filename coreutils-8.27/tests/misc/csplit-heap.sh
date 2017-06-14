#!/bin/sh
# ensure that csplit uses a bounded amount of memory

# Copyright (C) 2010-2017 Free Software Foundation, Inc.

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

# Determine basic amount of memory needed.
{ echo y; echo n; } > f || framework_failure_
vm=$(get_min_ulimit_v_ csplit -z f %n%1) \
  || skip_ "this shell lacks ulimit support"

(
 ulimit -v $(($vm + 1000)) \
   && { yes | head -n2500000; echo n; } | csplit -z - %n%1
) || fail=1

Exit $fail
