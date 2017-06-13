#!/bin/sh
# Test df's behavior when the mount list contains duplicate entries.
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

# We use --local here so as to not activate
# potentially very many remote mounts.
df --local --output=target >LOCAL_FS || skip_ 'df fails'
grep '^/$' LOCAL_FS || skip_ 'no root file system found'

# Get real targets to substitute for /NONROOT and /REMOTE below.
export CU_NONROOT_FS=$(grep /. LOCAL_FS | head -n1)
export CU_REMOTE_FS=$(grep /. LOCAL_FS | tail -n+2 | head -n1)

unique_entries=1
test -z "$CU_NONROOT_FS" || unique_entries=$(expr $unique_entries + 1)
test -z "$CU_REMOTE_FS" || unique_entries=$(expr $unique_entries + 2)

grep '^#define HAVE_MNTENT_H 1' $CONFIG_HEADER > /dev/null \
      || skip_ "no mntent.h available to confirm the interface"

grep '^#define HAVE_GETMNTENT 1' $CONFIG_HEADER > /dev/null \
      || skip_ "getmntent is not used on this system"

# Simulate an mtab file to test various cases.
cat > k.c <<EOF || framework_failure_
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
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

#define STREQ(a, b) (strcmp (a, b) == 0)

struct mntent *getmntent (FILE *fp)
{
  static char *nonroot_fs;
  static char *remote_fs;
  static int done;

  /* Prove that LD_PRELOAD works. */
  if (!done)
    {
      fclose (fopen ("x", "w"));
      ++done;
    }

  static struct mntent mntents[] = {
    {.mnt_fsname="/short",  .mnt_dir="/invalid/mount/dir",       .mnt_opts=""},
    {.mnt_fsname="fsname",  .mnt_dir="/",                        .mnt_opts=""},
    {.mnt_fsname="/fsname", .mnt_dir="/.",                       .mnt_opts=""},
    {.mnt_fsname="/fsname", .mnt_dir="/",                        .mnt_opts=""},
    {.mnt_fsname="virtfs",  .mnt_dir="/NONROOT", .mnt_type="t1", .mnt_opts=""},
    {.mnt_fsname="virtfs2", .mnt_dir="/NONROOT", .mnt_type="t2", .mnt_opts=""},
    {.mnt_fsname="netns",   .mnt_dir="net:[1234567]",            .mnt_opts=""},
    {.mnt_fsname="rem:ote1",.mnt_dir="/REMOTE",                  .mnt_opts=""},
    {.mnt_fsname="rem:ote1",.mnt_dir="/REMOTE",                  .mnt_opts=""},
    {.mnt_fsname="rem:ote2",.mnt_dir="/REMOTE",                  .mnt_opts=""},
  };

  if (done == 1)
    {
      nonroot_fs = getenv ("CU_NONROOT_FS");
      if (!nonroot_fs || !*nonroot_fs)
        nonroot_fs = "/"; /* merge into / entries.  */

      remote_fs = getenv ("CU_REMOTE_FS");
    }

  if (done == 1 && !getenv ("CU_TEST_DUPE_INVALID"))
    done++;  /* skip the first entry.  */

  while (done++ <= 10)
    {
      if (!mntents[done-2].mnt_type)
        mntents[done-2].mnt_type = "-";
      if (!mntents[done-2].mnt_opts)
        mntents[done-2].mnt_opts = "-";
      if (STREQ (mntents[done-2].mnt_dir, "/NONROOT"))
        mntents[done-2].mnt_dir = nonroot_fs;
      if (STREQ (mntents[done-2].mnt_dir, "/REMOTE"))
        {
          if (!remote_fs || !*remote_fs)
            continue;
          else
            mntents[done-2].mnt_dir = remote_fs;
        }
      return &mntents[done-2];
    }

  return NULL;
}
EOF

# Then compile/link it:
gcc_shared_ k.c k.so \
  || framework_failure_ 'failed to build shared library'

# Test if LD_PRELOAD works:
LD_PRELOAD=$LD_PRELOAD:./k.so df
test -f x || skip_ "internal test failure: maybe LD_PRELOAD doesn't work?"

# The fake mtab file should only contain entries
# having the same device number; thus the output should
# consist of a header and unique entries.
LD_PRELOAD=$LD_PRELOAD:./k.so df -T >out || fail=1
test $(wc -l <out) -eq $(expr 1 + $unique_entries) || { fail=1; cat out; }

# With --total we should suppress the duplicate but separate remote file system
LD_PRELOAD=$LD_PRELOAD:./k.so df --total >out || fail=1
test "$CU_REMOTE_FS" && elide_remote=1 || elide_remote=0
test $(wc -l <out) -eq $(expr 2 + $unique_entries - $elide_remote) ||
  { fail=1; cat out; }

# Ensure we don't fail when unable to stat (currently) unavailable entries
LD_PRELOAD=$LD_PRELOAD:./k.so CU_TEST_DUPE_INVALID=1 df -T >out || fail=1
test $(wc -l <out) -eq $(expr 1 + $unique_entries) || { fail=1; cat out; }

# df should also prefer "/fsname" over "fsname"
if test "$unique_entries" = 2; then
  test $(grep -c '/fsname' <out) -eq 1 || { fail=1; cat out; }
  # ... and "/fsname" with '/' as Mounted on over '/.'
  test $(grep -cF '/.' <out) -eq 0 || { fail=1; cat out; }
fi

# df should use the last seen devname (mnt_fsname) and devtype (mnt_type)
test $(grep -c 'virtfs2.*t2' <out) -eq 1 || { fail=1; cat out; }

# Ensure that filtering duplicates does not affect -a processing.
LD_PRELOAD=$LD_PRELOAD:./k.so df -a >out || fail=1
total_fs=6; test "$CU_REMOTE_FS" && total_fs=$(expr $total_fs + 3)
test $(wc -l <out) -eq $total_fs || { fail=1; cat out; }
# Ensure placeholder "-" values used for the eclipsed "virtfs"
test $(grep -c 'virtfs *-' <out) -eq 1 || { fail=1; cat out; }

# Ensure that filtering duplicates does not affect
# argument processing (now without the fake getmntent()).
df '.' '.' >out || fail=1
test $(wc -l <out) -eq 3 || { fail=1; cat out; }

Exit $fail
