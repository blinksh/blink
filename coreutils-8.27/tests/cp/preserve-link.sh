#!/bin/sh
# Exercise the fix for https://bugs.gnu.org/8419

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
print_ver_ cp

same_inode()
{
  local u v
  u=$(stat --format %i "$1") &&
    v=$(stat --format %i "$2") && test "$u" = "$v"
}

create_source_tree()
{
  rm -Rf s
  mkdir s || framework_failure_

  # a missing link in dest will be created
  touch s/f || framework_failure_
  ln s/f s/linkm || framework_failure_

  # an existing link in dest will be maintained
  ln s/f s/linke || framework_failure_

  # a separate older file in dest will be overwritten
  ln s/f s/fileo || framework_failure_

  # a separate newer file in dest will be overwritten!
  ln s/f s/fileu || framework_failure_
}

create_target_tree()
{
  f=$1 # which of f or linkm to create in t/

  rm -Rf t
  mkdir -p t/s/ || framework_failure_

  # a missing link in dest must be created
  touch t/s/$f || framework_failure_

  # an existing link must be maintained
  ln t/s/$f t/s/linke || framework_failure_

  # a separate older file in dest will be overwritten
  touch -d '-1 hour' t/s/fileo || framework_failure_

  # a separate newer file in dest will be overwritten!
  touch -d '+1 hour' t/s/fileu || framework_failure_
}


# Note we repeat this, creating either one of
# two hard linked files from source in the dest, so as to
# test both paths in $(cp) for creating the hard links.
# The path taken by cp is dependent on which cp encounters
# first in the source, which is non deterministic currently
# (I'm guessing that results are sorted by inode and
# beauses they're the same here, and due to the sort
# being unstable, either can be processed first).
create_source_tree

for f in f linkm; do
  create_target_tree $f

  # Copy all the hard links across.  With cp from coreutils-8.12
  # and prior, it would sometimes mistakenly copy rather than link.
  cp -au s t || fail=1

  same_inode t/s/f t/s/linkm || fail=1
  same_inode t/s/f t/s/linke || fail=1
  same_inode t/s/f t/s/fileo || fail=1
  same_inode t/s/f t/s/fileu || fail=1
done

Exit $fail
