#!/bin/sh
# Trigger a failed assertion in coreutils-8.9 and earlier.

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
print_ver_ du
require_trap_signame_

# We use a python-inotify script, so...
python -m pyinotify -h > /dev/null \
  || skip_ 'python inotify package not installed'

# Move a directory "up" while du is processing its sub-directories.
# While du is processing a hierarchy .../B/C/D/... this script
# detects when du opens D/, and then moves C/ "up" one level
# so that it is a sibling of B/.
# Given the inherent race condition, we have to add enough "weight"
# under D/ so that in most cases, the monitor performs the single
# rename syscall before du finishes processing the subtree under D/.

cat <<'EOF' > inotify-watch-for-dir-access.py
#!/usr/bin/env python
import pyinotify as pn
import os,sys

dir = sys.argv[1]
dest_parent = os.path.dirname(os.path.dirname(dir))
dest = os.path.join(dest_parent, os.path.basename(dir))

class ProcessDir(pn.ProcessEvent):

    def process_IN_OPEN(self, event):
        os.rename(dir, dest)
        sys.exit(0)

    def process_default(self, event):
        pass

wm = pn.WatchManager()
notifier = pn.Notifier(wm)
wm.watch_transient_file(dir, pn.IN_OPEN, ProcessDir)
sys.stdout.write('started\n')
sys.stdout.flush()
notifier.loop()
EOF
chmod a+x inotify-watch-for-dir-access.py

t=T/U
mkdir d2 || framework_failure_
long=d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/z
# One iteration of this loop creates a tree with which
# du sometimes completes its traversal before the above rename.
# Five iterations was not enough in 2 of 7 "make -j20 check" runs on a
# 6/12-core system.  However, using "10", I saw no failure in 20 trials.
# Using 10 iterations was not enough, either.
# Using 50, I saw no failure in 200 trials.
for i in $(seq 50); do
  mkdir -p $t/3/a/b/c/$i/$long || framework_failure_
done

# Terminate any background cp process
cleanup_() { kill $pid 2>/dev/null && wait $pid; }

# Prohibit suspension, which could otherwise cause a timeout-induced FP failure.
trap '' TSTP

timeout 6 ./inotify-watch-for-dir-access.py $t/3/a/b > start-msg & pid=$!

# Wait for the watcher to start...
nonempty() { sleep $1; test -s start-msg; }
retry_delay_ nonempty .1 5 || fail=1

# The above watches for an IN_OPEN event on $t/3/a/b,
# and when it triggers, moves the parent, $t/3/a, up one level
# so it's directly under $t.

# Before coreutils-8.10, du would abort.
returns_ 1 du -a $t d2 2> err || fail=1

# check for the new diagnostic
printf "du: fts_read failed: $t/3/a/b: No such file or directory\n" > exp \
  || fail=1
compare exp err || fail=1

Exit $fail
