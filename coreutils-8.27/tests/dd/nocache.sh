#!/bin/sh
# Ensure dd handles the 'nocache' flag

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
print_ver_ dd

# This should not call posix_fadvise
dd iflag=nocache oflag=nocache if=/dev/null of=/dev/null || fail=1

# We should get an error for trying to process a pipe
dd count=0 | returns_ 1 dd iflag=nocache count=0 || fail=1

# O_DIRECT is orthogonal to drop cache so mutually exclusive
returns_ 1 dd iflag=nocache,direct if=/dev/null || fail=1

# The rest ensure that the documented uses cases
# proceed without error
for f in ifile ofile; do
  dd if=/dev/zero of=$f conv=fdatasync count=100 || framework_failure_
done

# Advise to drop cache for whole file
if ! dd if=ifile iflag=nocache count=0 2>err; then
  # We could check for 'Operation not supported' in err here,
  # but that was seen to be brittle. HPUX returns ENOTTY for example.
  # So assume that if this basic operation fails, it's due to lack
  # of support by the system.
  warn_ 'skipping part; this file system lacks support for posix_fadvise()'
  skip=1
fi

if test "$skip" != 1; then
  # Ensure drop cache for whole file
  dd of=ofile oflag=nocache conv=notrunc,fdatasync count=0 || fail=1

  # Drop cache for part of file
  dd if=ifile iflag=nocache skip=10 count=10 of=/dev/null || fail=1

  # Stream data just using readahead cache
  dd if=ifile of=ofile iflag=nocache oflag=nocache || fail=1
fi

Exit $fail
