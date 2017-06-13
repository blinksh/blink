#!/bin/sh
# Exercise stdbuf functionality

# Copyright (C) 2009-2017 Free Software Foundation, Inc.

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
print_ver_ stdbuf

getlimits_

# stdbuf fails when the absolute top build dir name contains e.g.,
# space, TAB, NL
lf='
'
case $abs_top_builddir in
  *[\\\"\#\$\&\'\`$lf\ \	]*)
    skip_ "unsafe absolute build directory name: $abs_top_builddir";;
esac

# Use a fifo rather than a pipe in the tests below
# so that the producer (uniq) will wait until the
# consumer (dd) opens the fifo therefore increasing
# the chance that dd will read the data from each
# write separately.
mkfifo_or_skip_ fifo


# Verify input parameter checking
stdbuf -o1 true || fail=1 # verify size syntax
stdbuf -oK true || fail=1 # verify size syntax
stdbuf -o0 true || fail=1 # verify unbuffered syntax
stdbuf -oL true || fail=1 # verify line buffered syntax

# Capital 'L' required
# Internal error is a particular status
returns_ 125 stdbuf -ol true || fail=1

returns_ 125 stdbuf -o$SIZE_OFLOW true || fail=1 # size too large
returns_ 125 stdbuf -iL true || fail=1 # line buffering stdin disallowed
returns_ 125 stdbuf true || fail=1 # a buffering mode must be specified
stdbuf -i0 -o0 -e0 true || fail=1 #check all files
returns_ 126 stdbuf -o1 . || fail=1 # invalid command
returns_ 127 stdbuf -o1 no_such || fail=1 # no such command

# Terminate any background processes
cleanup_() { kill $pid 2>/dev/null && wait $pid; }

# Ensure line buffering stdout takes effect
stdbuf_linebuffer()
{
  local delay="$1"

  printf '1\n' > exp
  > out || framework_failure_
  dd count=1 if=fifo > out 2> err & pid=$!
  (printf '1\n'; sleep $delay; printf '2\n') | stdbuf -oL uniq > fifo
  wait $pid
  compare exp out
}

retry_delay_ stdbuf_linebuffer .1 6 || fail=1

stdbuf_unbuffer()
{
  local delay="$1"

  # Ensure un buffering stdout takes effect
  printf '1\n' > exp
  > out || framework_failure_
  dd count=1 if=fifo > out 2> err & pid=$!
  (printf '1\n'; sleep $delay; printf '2\n') | stdbuf -o0 uniq > fifo
  wait $pid
  compare exp out
}

retry_delay_ stdbuf_unbuffer .1 6 || fail=1

# Ensure un buffering stdin takes effect
#  The following works for me, but is racy.  I.e., we're depending
#  on dd to run and close the fifo before the second write by uniq.
#  If we add a sleep, then we're just testing -oL
    # printf '3\n' > exp
    # dd count=1 if=fifo > /dev/null 2> err &
    # printf '1\n\2\n3\n' | (stdbuf -i0 -oL uniq > fifo; cat) > out
    # wait # for dd to complete
    # compare exp out || fail=1
#  One could remove the need for dd (used to close the fifo to get uniq to quit
#  early), if head -n1 read stdin char by char. Note uniq | head -c2 doesn't
#  suffice due to the buffering implicit in the pipe.  sed currently does read
#  stdin char by char, so we can test with 'sed 1q'.  However I'm wary about
#  adding this dependency on a program outside of coreutils.
    # printf '2\n' > exp
    # printf '1\n2\n' | (stdbuf -i0 sed 1q >/dev/null; cat) > out
    # compare exp out || fail=1

# Ensure block buffering stdout takes effect
# We don't currently test block buffering failures as
# this doesn't work on GLIBC-2.7 or GLIBC-2.9 at least.
   # stdbuf_blockbuffer()
   # {
   #   local delay="$1"
   #
   #   printf '1\n2\n' > exp
   #   dd count=1 if=fifo > out 2> err &
   #   (printf '1\n'; sleep $delay; printf '2\n') | stdbuf -o4 uniq > fifo
   #   wait # for dd to complete
   #   compare exp out
   # }
   #
   # retry_delay_ stdbuf_blockbuffer .1 6 || fail=1

Exit $fail
