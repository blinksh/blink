#!/bin/sh
# Make sure stty can parse most of its options - in pairs [expensive].

# Copyright (C) 1998-2017 Free Software Foundation, Inc.

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
print_ver_ stty

expensive_

# Make sure there's a tty on stdin.
require_controlling_input_terminal_
require_trap_signame_

trap '' TTOU # Ignore SIGTTOU

# Get the reversible settings from stty.c.
stty_reversible_init_

saved_state=.saved-state
stty --save > $saved_state || fail=1
stty $(cat $saved_state) || fail=1

# Build a list of all boolean options stty accepts on this system.
# Don't depend on terminal width.  Put each option on its own line,
# remove all non-boolean ones, remove 'parenb' and 'cread' explicitly,
# then remove any leading hyphens.
sed_del='/^speed/d;/^rows/d;/^columns/d;/ = /d;s/parenb//;s/cread//'
options=$(stty -a | tr -s ';' '\n' | sed "s/^ //;$sed_del;s/-//g")

# Take them in pairs, with and without the leading '-'.
for opt1 in $options; do
  for opt2 in $options; do

    stty $opt1 $opt2 || fail=1

    if stty_reversible_query_ "$opt1" ; then
      stty -$opt1 $opt2 || fail=1
    fi
    if stty_reversible_query_ "$opt2" ; then
      stty $opt1 -$opt2 || fail=1
    fi
    if stty_reversible_query_ "$opt1" \
        && stty_reversible_query_ "$opt2" ; then
      stty -$opt1 -$opt2 || fail=1
    fi
  done
done

stty $(cat $saved_state)

Exit $fail
