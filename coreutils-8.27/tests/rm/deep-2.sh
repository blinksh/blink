#!/bin/sh
# Ensure rm -r DIR does not prompt for very long full relative names in DIR.

# Copyright (C) 2008-2017 Free Software Foundation, Inc.

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
require_perl_

# Root can run this test, but it always succeeds, since for root, all
# files are writable, and write_protected_non_symlink never reaches
# the offending euidaccess_stat call.
skip_if_root_

# ecryptfs for example uses some of the file name space
# for encrypting filenames, so we must check dynamically.
name_max=$(stat -f -c %l .)
test "$name_max" -ge '200' || skip_ "NAME_MAX=$name_max is not sufficient"

mkdir x || framework_failure_
cd x || framework_failure_

# Construct a hierarchy containing a relative file with a long name
: ${PERL=perl}
$PERL \
    -e 'my $d = "x" x 200; foreach my $i (1..52)' \
    -e '  { mkdir ($d, 0700) && chdir $d or die "$!" }' \
  || framework_failure_

cd .. || framework_failure_
echo n > no || framework_failure_

rm ---presume-input-tty -r x < no > out || fail=1

# expect empty output
compare /dev/null out || fail=1

# the directory must have been removed
test -d x && fail=1

Exit $fail
