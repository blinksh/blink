#!/bin/sh
# Detect printf(3) failure even when it doesn't set stream error indicator

# Copyright (C) 2007-2017 Free Software Foundation, Inc.

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

prog=printf

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ printf

vm=$(get_min_ulimit_v_ env $prog %20f 0) \
  || skip_ "this shell lacks ulimit support"

# Up to coreutils-6.9, "printf %.Nf 0" would encounter an ENOMEM internal
# error from glibc's printf(3) function whenever N was large relative to
# the size of available memory.  As of Oct 2007, that internal stream-
# related failure was not reflected (for any libc I know of) in the usual
# stream error indicator that is tested by ferror.  The result was that
# while the printf command obviously failed (generated no output),
# it mistakenly exited successfully (exit status of 0).

# Testing it is tricky, because there is so much variance
# in quality for this corner of printf(3) implementations.
# Most implementations do attempt to allocate N bytes of storage.
# Using the maximum value for N (2^31-1) causes glibc-2.7 to try to
# allocate almost 2^64 bytes, while freeBSD 6.1's implementation
# correctly outputs almost 2GB worth of 0's, which takes too long.
# We want to test implementations that allocate N bytes, but without
# triggering the above extremes.

# Some other versions of glibc-2.7 have a snprintf function that segfaults
# when an internal (technically unnecessary!) memory allocation fails.

# The compromise is to limit virtual memory to something reasonable,
# and to make an N-byte-allocating-printf require more than that, thus
# triggering the printf(3) misbehavior -- which, btw, is required by ISO C99.

mkfifo_or_skip_ fifo

# Disable MALLOC_PERTURB_, to avoid triggering this bug
# https://bugs.debian.org/481543#77
export MALLOC_PERTURB_=0

# Terminate any background process
cleanup_() { kill $pid 2>/dev/null && wait $pid; }

head -c 10 fifo > out & pid=$!

# Trigger large mem allocation failure
( ulimit -v $vm && env $prog %20000000f 0 2>err-msg > fifo )
exit=$?

# Map this longer, and rarer, diagnostic to the common one.
# printf: cannot perform formatted output: Cannot allocate memory" \
sed 's/cannot perform .*/write error/' err-msg > k && mv k err-msg
err_msg=$(tr '\n' : < err-msg)

# By some bug, on Solaris 11 (5.11 snv_86), err_msg ends up
# containing '1> fifo:printf: write error:'.  Recognize that, too.

case $err_msg in
  "$prog: write error:"*) diagnostic=y ;;
  "1> fifo:$prog: write error:") diagnostic=y ;;
  '') diagnostic=n ;;
  *) diagnostic=unexpected ;;
esac
n_out=$(wc -c < out)

case $n_out:$diagnostic:$exit in
  10:n:0) ;; # ok, succeeds w/no diagnostic: FreeBSD 6.1
  0:y:1)  ;; # ok, glibc-2.8 and newer, when printf(3) fails with ENOMEM

  # With MALLOC_PERTURB_=0, this no longer happens.
  # *:139)     # segfault; known bug at least in debian unstable's libc6 2.7-11
  #    echo 1>&2 "$0: bug in snprintf causes low-mem use of printf to segfault"
  #    fail=77;;

  # 10:y) ;; # Fail: doesn't happen: nobody succeeds with a diagnostic
  # 0:n)  ;; # Fail pre-patch: no output, no diag
  *) fail=1;;
esac

Exit $fail
