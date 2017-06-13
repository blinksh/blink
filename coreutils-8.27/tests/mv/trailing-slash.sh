#!/bin/sh
# On some operating systems, e.g. SunOS-4.1.1_U1 on sun3x,
# rename() doesn't accept trailing slashes.
# Also, ensure that "mv dir non-exist-dir/" works.
# Also, ensure that "cp dir non-exist-dir/" works.

# Copyright (C) 2004-2017 Free Software Foundation, Inc.

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
print_ver_ mv

mkdir foo || framework_failure_


mv foo/ bar || fail=1

# mv and cp would misbehave for coreutils versions [5.3.0..5.97], 6.0 and 6.1
for cmd in mv 'cp -r'; do
  for opt in '' -T -u; do
    rm -rf d e || framework_failure_
    mkdir d    || framework_failure_

    $cmd $opt d e/ || fail=1
    if test "$cmd" = mv; then
      test -d d && fail=1
    else
      test -d d || fail=1
    fi
    test -d e || fail=1
  done
done

# We would like the erroneous-looking "mv any non-dir/" to fail,
# but with the current implementation, it depends on how the
# underlying rename syscall handles the trailing slash.
# It does fail, as desired, on recent Linux and Solaris systems.
#touch a a2
#returns_ 1 mv a a2/ || fail=1

# Test for a cp-specific diagnostic introduced after coreutils-8.7:
printf '%s\n' \
  "cp: cannot create regular file 'no-such/': Not a directory" \
> expected-err
touch b
cp b no-such/ 2> err

# Map "No such file..." diagnostic to the expected "Not a directory"
sed 's/No such file or directory/Not a directory/' err > k && mv k err

compare expected-err err || fail=1

Exit $fail
