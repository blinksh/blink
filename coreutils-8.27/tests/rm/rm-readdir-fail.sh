#!/bin/sh
# Test rm's behaviour when the directory cannot be read.
# This test is skipped on systems that lack LD_PRELOAD support.

# Copyright (C) 2016-2017 Free Software Foundation, Inc.

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
print_ver_ rm
require_gcc_shared_

mkdir -p dir/notempty || framework_failure_

# Simulate "readdir" failure.
cat > k.c <<\EOF || framework_failure_
#define _GNU_SOURCE

/* Setup so we don't have to worry about readdir64.  */
#ifndef __LP64__
# define _FILE_OFFSET_BITS 64
#endif

#include <dlfcn.h>
#include <dirent.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

struct dirent *readdir (DIR *dirp)
{
  static struct dirent *(*real_readdir)(DIR *dirp);
  if (! real_readdir && ! (real_readdir = dlsym (RTLD_NEXT, "readdir")))
    {
      fprintf (stderr, "Failed to find readdir()\n");
      errno = ESRCH;
      return NULL;
    }
  struct dirent* d;
  if (! (d = real_readdir (dirp)))
    {
      fprintf (stderr, "Failed to get dirent\n");
      errno = ENOENT;
      return NULL;
    }

  /* Flag that LD_PRELOAD and above functions work.  */
  static int count = 1;
  if (count == 1)
    fclose (fopen ("preloaded", "w"));

  /* Return some entries to trigger partial read failure,
     ensuring we don't return ignored '.' or '..'  */
  char const *readdir_partial = getenv ("READDIR_PARTIAL");
  if (readdir_partial && *readdir_partial && count <= 3)
    {
      count++;
      d->d_name[0]='0'+count; d->d_name[1]='\0';
#ifdef _DIRENT_HAVE_D_NAMLEN
      d->d_namlen = 2;
#endif
      errno = 0;
      return d;
    };

  /* Fail.  */
  errno = ENOENT;
  return NULL;
}
EOF

# Then compile/link it:
gcc_shared_ k.c k.so \
  || framework_failure_ 'failed to build shared library'

# Test if LD_PRELOAD works:
export READDIR_PARTIAL
for READDIR_PARTIAL in '' '1'; do
  rm -f preloaded
  (export LD_PRELOAD=$LD_PRELOAD:./k.so
   returns_ 1 rm -Rf dir 2>>errt) || fail=1
  if ! test -f preloaded; then
    cat err
    skip_ "internal test failure: maybe LD_PRELOAD doesn't work?"
  fi
done

# First case is failure to read any items from dir, then assume empty.
# Generally that will be diagnosed when rm tries to rmdir().
# Second case is more general error where we fail immediately
# (with ENOENT in this case but it could be anything).
cat <<EOF > exp
rm: cannot remove 'dir'
rm: traversal failed: dir
EOF
sed 's/\(rm:.*\):.*/\1/' errt > err || framework_failure_
compare exp err || fail=1

Exit $fail
