#!/bin/sh
# Exercise cp --link's behavior regarding the dereferencing of symbolic links.

# Copyright (C) 2013-2017 Free Software Foundation, Inc.

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

if { grep '^#define HAVE_LINKAT 1' "$CONFIG_HEADER" > /dev/null \
     && grep '#undef LINKAT_SYMLINK_NOTSUP' "$CONFIG_HEADER" > /dev/null; } \
   || grep '^#define LINK_FOLLOWS_SYMLINKS 0' "$CONFIG_HEADER" > /dev/null; then
  # With this config cp will attempt to linkat() to hardlink a symlink.
  # So now double check the current file system supports this operation.
  ln -s testtarget test_sl || framework_failure_
  ln -P test_sl test_hl_sl || framework_failure_
  ino_sl="$(stat -c '%i' test_sl)" || framework_failure_
  ino_hl="$(stat -c '%i' test_hl_sl)" || framework_failure_
  test "$ino_sl" = "$ino_hl" && can_hardlink_to_symlink=1
fi

mkdir dir              || framework_failure_
> file                 || framework_failure_
ln -s dir     dirlink  || framework_failure_
ln -s file    filelink || framework_failure_
ln -s nowhere danglink || framework_failure_

# printf format of the output line.
outformat='%s|result=%s|inode=%s|type=%s|error=%s\n'

for src in dirlink filelink danglink; do
  # Get symlink's target.
  tgt=$(readlink $src) || framework_failure_
  # Get inodes and file type of the symlink (src) and its target (tgt).
  # Note: this will fail for 'danglink'; catch it.
  ino_src="$(stat -c '%i' $src)" || framework_failure_
  typ_src="$(stat -c '%F' $src)" || framework_failure_
  ino_tgt="$(stat -c '%i' $tgt 2>/dev/null)" || ino_tgt=
  typ_tgt="$(stat -c '%F' $tgt 2>/dev/null)" || typ_tgt=

  for o in '' -L -H -P; do

    # Skip the -P case where we don't or can't hardlink symlinks
    ! test "$can_hardlink_to_symlink" && test "$o" = '-P' && continue

    for r in '' -R; do

      command="cp --link $o $r $src dst"
      $command 2> err
      result=$?

      # Get inode and file type of the destination (which may fail, too).
      ino_dst="$(stat -c '%i' dst 2>/dev/null)" || ini_dst=
      typ_dst="$(stat -c '%F' dst 2>/dev/null)" || typ_dst=

      # Print the actual result in a certain format.
      printf "$outformat" \
        "$command"   \
        "$result"   \
        "$ino_dst"  \
        "$typ_dst"  \
        "$(cat err)"  \
        > out

      # What was expected?
      if [ "$o" = "-P" ]; then
        # cp --link should not dereference if -P is given.
        exp_result=0
        exp_inode=$ino_src
        exp_ftype=$typ_src
        exp_error=
      elif [ "$src" = 'danglink' ]; then
        # Dereferencing should fail for the 'danglink'.
        exp_result=1
        exp_inode=
        exp_ftype=
        exp_error="cp: cannot stat 'danglink': No such file or directory"
      elif [ "$src" = 'dirlink' ] && [ "$r" != '-R' ]; then
        # Dereferencing should fail for the 'dirlink' without -R.
        exp_result=1
        exp_inode=
        exp_ftype=
        exp_error="cp: -r not specified; omitting directory 'dirlink'"
      elif [ "$src" = 'dirlink' ]; then
        # cp --link -R 'dirlink' should create a new directory.
        exp_result=0
        exp_inode=$ino_dst
        exp_ftype=$typ_dst
        exp_error=
      else
        # cp --link 'filelink' should create a hard link to the target.
        exp_result=0
        exp_inode=$ino_tgt
        exp_ftype=$typ_tgt
        exp_error=
      fi

      # Print the expected result in a certain format.
      printf "$outformat" \
        "$command"   \
        "$exp_result" \
        "$exp_inode"  \
        "$exp_ftype"  \
        "$exp_error"  \
        > exp

      compare exp out || { ls -lid $src $tgt dst; fail=1; }

      rm -rf dst err exp out || framework_failure_
    done
  done
done

Exit $fail
