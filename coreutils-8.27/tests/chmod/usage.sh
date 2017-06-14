#!/bin/sh
# Verify that chmod works correctly with odd option combinations.

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
print_ver_ chmod


# Each line in this list is a set of arguments, followed by :,
# followed by the set of files it will attempt to chmod,
# or empty if the usage is erroneous.
# Many of these test cases are due to Glenn Fowler.
# These test cases assume GNU behavior for "options" like -w.
cases='
  --         :
  -- --      :
  -- -- -- f : -- f
  -- -- -w f : -w f
  -- -- f    : f
  -- -w      :
  -- -w -- f : -- f
  -- -w -w f : -w f
  -- -w f    : f
  -- f       :
  -w         :
  -w --      :
  -w -- -- f : -- f
  -w -- -w f : -w f
  -w -- f    : f
  -w -w      :
  -w -w -- f : f
  -w -w -w f : f
  -w -w f    : f
  -w f       : f
  f          :
  f --       :
  f -w       : f
  f f        :
  u+gr f     :
  ug,+x f    :
'

all_files=$(echo "$cases" | sed 's/.*://'|sort -u)

old_IFS=$IFS
IFS='
'
for case in $cases; do
  IFS=$old_IFS
  args=$(expr "$case" : ' *\(.*[^ ]\) *:')
  files=$(expr "$case" : '.*: *\(.*\)')

  case $files in
  '')
    touch -- $all_files || framework_failure_
    returns_ 1 chmod $args 2>/dev/null || fail=1
    ;;
  ?*)
    touch -- $files || framework_failure_
    chmod $args || fail=1
    for file in $files; do
      # Test for misparsing args by creating all $files but $file.
      # chmod has a bug if it succeeds even though $file is absent.
      rm -f -- $all_files && touch -- $files && rm -- $file \
          || framework_failure_
      returns_ 1 chmod $args 2>/dev/null || fail=1
    done
    ;;
  esac
done

Exit $fail
