#!/bin/sh
# Test df's behaviour when the mount list cannot be read.
# This test is skipped on systems that lack LD_PRELOAD support; that's fine.

# Copyright (C) 2012-2017 Free Software Foundation, Inc.

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
print_ver_ df
require_gcc_shared_

# Protect against inaccessible remote mounts etc.
timeout 10 df || skip_ "df fails"

grep '^#define HAVE_MNTENT_H 1' $CONFIG_HEADER > /dev/null \
      || skip_ "no mntent.h available to confirm the interface"

grep '^#define HAVE_GETMNTENT 1' $CONFIG_HEADER > /dev/null \
      || skip_ "getmntent is not used on this system"

# Simulate "mtab" failure.
cat > k.c <<EOF || framework_failure_
#define _GNU_SOURCE
#include <stdio.h>
#include <errno.h>
#include <mntent.h>
#include <string.h>
#include <dlfcn.h>

#define STREQ(a, b) (strcmp (a, b) == 0)

FILE* fopen(const char *path, const char *mode)
{
  static FILE* (*fopen_func)(char const *, char const *);

  /* get reference to original (libc provided) fopen */
  if (!fopen_func)
    {
      fopen_func = (FILE*(*)(char const *, char const *))
                   dlsym(RTLD_NEXT, "fopen");
      if (!fopen_func)
        {
          fprintf (stderr, "Failed to find fopen()\n");
          errno = ESRCH;
          return NULL;
        }
    }

  /* Returning ENOENT here will get read_file_system_list()
     to fall back to using getmntent() below.  */
  if (STREQ (path, "/proc/self/mountinfo"))
    {
      errno = ENOENT;
      return NULL;
    }
  else
    return fopen_func(path, mode);
}

struct mntent *getmntent (FILE *fp)
{
  /* Prove that LD_PRELOAD works. */
  static int done = 0;
  if (!done)
    {
      fclose (fopen ("x", "w"));
      ++done;
    }
  /* Now simulate the failure. */
  errno = ENOENT;
  return NULL;
}
EOF

# Then compile/link it:
gcc_shared_ k.c k.so \
  || framework_failure_ 'failed to build shared library'

cleanup_() { unset LD_PRELOAD; }

export LD_PRELOAD=$LD_PRELOAD:./k.so

# Test if LD_PRELOAD works:
df 2>/dev/null
test -f x || skip_ "internal test failure: maybe LD_PRELOAD doesn't work?"

# These tests are supposed to succeed:
df '.' || fail=1
df -i '.' || fail=1
df -T '.' || fail=1
df -Ti '.' || fail=1
df --total '.' || fail=1

# These tests are supposed to fail:
returns_ 1 df || fail=1
returns_ 1 df -i || fail=1
returns_ 1 df -T || fail=1
returns_ 1 df -Ti || fail=1
returns_ 1 df --total || fail=1

returns_ 1 df -a || fail=1
returns_ 1 df -a '.' || fail=1

returns_ 1 df -l || fail=1
returns_ 1 df -l '.' || fail=1

returns_ 1 df -t hello || fail=1
returns_ 1 df -t hello '.' || fail=1

returns_ 1 df -x hello || fail=1
returns_ 1 df -x hello '.' || fail=1

Exit $fail
