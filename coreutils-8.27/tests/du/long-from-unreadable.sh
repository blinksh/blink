#!/bin/sh
# Show fts fails on old-fashioned systems.

# Copyright (C) 2006-2017 Free Software Foundation, Inc.

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

# Show that fts (hence du, chmod, chgrp, chown) fails when all of the
# following are true:
#   - '.' is not readable
#   - operating on a hierarchy containing a relative name longer than PATH_MAX
#   - run on a system where gnulib's openat emulation must resort to using
#       save_cwd and restore_cwd (which fail if '.' is not readable).
# Thus, the following du invocation should succeed on newer Linux and
# Solaris systems, yet it must fail on systems lacking both openat and
# /proc support.  However, before coreutils-6.0 this test would fail even
# on Linux+PROC_FS systems because its fts implementation would revert
# unnecessarily to using FTS_NOCHDIR mode in this corner case.

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ du

# ecryptfs for example uses some of the file name space
# for encrypting filenames, so we must check dynamically.
name_max=$(stat -f -c %l .)
test "$name_max" -ge '200' || skip_ "NAME_MAX=$name_max is not sufficient"

proc_file=/proc/self/fd
if test ! -d $proc_file; then
  skip_ 'This test would fail, since your system lacks /proc support.'
fi

dir=$(printf '%200s\n' ' '|tr ' ' x)

# Construct a hierarchy containing a relative file with a name
# longer than PATH_MAX.
# for i in $(seq 52); do
#   mkdir $dir || framework_failure_
#   cd $dir || framework_failure_
# done
# cd $tmp || framework_failure_

# Sheesh.  Bash 3.1.5 can't create this hierarchy.  I get
#   cd: error retrieving current directory: getcwd:
#     cannot access parent directories:
# (all on one line).

cwd=$(pwd)
# Use perl instead:
: ${PERL=perl}
$PERL \
    -e 'my $d = '$dir'; foreach my $i (1..52)' \
    -e '  { mkdir ($d, 0700) && chdir $d or die "$!" }' \
  || framework_failure_

mkdir inaccessible || framework_failure_
cd inaccessible || framework_failure_
chmod 0 . || framework_failure_

du -s "$cwd/$dir" > /dev/null || fail=1

Exit $fail
