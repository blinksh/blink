#!/bin/sh
# Make sure that 'tail -f' returns immediately if a file doesn't exist
# while 'tail -F' waits for it to appear.

# Copyright (C) 2003-2017 Free Software Foundation, Inc.

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
print_ver_ tail

grep '^#define HAVE_INOTIFY 1' "$CONFIG_HEADER" >/dev/null \
  && HAVE_INOTIFY=1

inotify_failed_re='inotify (resources exhausted|cannot be used)'

touch here || framework_failure_
{ touch unreadable && chmod a-r unreadable; } || framework_failure_

# Terminate any background tail process
cleanup_() { kill $pid 2>/dev/null && wait $pid; }

# speedup non inotify case
fastpoll='-s.1 --max-unchanged-stats=1'

for mode in '' '---disable-inotify'; do
  returns_ 124 timeout 10 tail $fastpoll -f $mode not_here && fail=1

  if test ! -r unreadable; then # can't test this when root
    returns_ 124 timeout 10 tail $fastpoll -f $mode unreadable && fail=1
  fi

  returns_ 124 timeout .1 tail $fastpoll -f $mode here 2>tail.err || fail=1

  # 'tail -F' must wait in any case.

  returns_ 124 timeout .1 tail $fastpoll -F $mode here 2>>tail.err || fail=1

  if test ! -r unreadable; then # can't test this when root
    returns_ 124 timeout .1 tail $fastpoll -F $mode unreadable || fail=1
  fi

  returns_ 124 timeout .1 tail $fastpoll -F $mode not_here || fail=1

  grep -Ev "$inotify_failed_re" tail.err > x
  mv x tail.err
  compare /dev/null tail.err || fail=1
  >tail.err
done

if test "$HAVE_INOTIFY" && test -z "$mode" && is_local_dir_ .; then
  # Ensure -F never follows a descriptor after rename
  # either with tiny or significant delays between operations
  tail_F()
  {
    local delay="$1"

    > k && > tail.out && > tail.err || framework_failure_
    tail $fastpoll -F $mode k >tail.out 2>tail.err & pid=$!
    sleep $delay
    mv k l
    sleep $delay
    touch k
    mv k l
    sleep $delay
    echo NO >> l
    sleep $delay
    cleanup_
    rm -f k l

    test -s tail.out \
      && ! grep -E "$inotify_failed_re" tail.err >/dev/null
  }

  retry_delay_ tail_F 0 1 && { cat tail.out; fail=1; }
  retry_delay_ tail_F .2 1 && { cat tail.out; fail=1; }
fi

Exit $fail
