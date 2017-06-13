#!/usr/bin/perl -Tw
# Ensure that rm gives the expected diagnostic when failing to remove a file
# owned by some other user in a directory with the sticky bit set.

# Copyright (C) 2002-2017 Free Software Foundation, Inc.

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

use strict;

(my $ME = $0) =~ s|.*/||;

my $uid = $<;
# skip if root
$uid == 0
  and CuSkip::skip "$ME: can't run this test as root: skipping this test";

my $verbose = $ENV{VERBOSE} && $ENV{VERBOSE} eq 'yes';

# Ensure that the diagnostics are in English.
$ENV{LC_ALL} = 'C';

# Set up a safe, well-known environment
$ENV{IFS}  = '';

# Taint checking requires a sanitized $PATH.  This script performs no $PATH
# search, so on most Unix-based systems, it is fine simply to clear $ENV{PATH}.
# However, on Cygwin, it's used to find cygwin1.dll, so set it.
$ENV{PATH} = '/bin:/usr/bin';

my @dir_list = qw(/tmp /var/tmp /usr/tmp);
my $rm = "$ENV{abs_top_builddir}/src/rm";

# Untaint for upcoming popen.
$rm =~ m!^([-+\@\w./]+)$!
  or CuSkip::skip "$ME: unusual absolute builddir name; skipping this test\n";
$rm = $1;

# Find a directory with the sticky bit set.
my $found_dir;
my $found_file;
foreach my $dir (@dir_list)
  {
    if (-d $dir && -k _ && -r _ && -w _ && -x _)
      {
        $found_dir = 1;

        # Find a non-directory there that is owned by some other user.
        opendir DIR_HANDLE, $dir
          or die "$ME: couldn't open $dir: $!\n";

        foreach my $f (readdir DIR_HANDLE)
          {
            # Consider only names containing "safe" characters.
            $f =~ /^([-\@\w.]+)$/
              or next;
            $f = $1;    # untaint $f

            my $target_file = "$dir/$f";
            $verbose
              and warn "$ME: considering $target_file\n";

            # Skip files owned by self, symlinks, and directories.
            # It's not technically necessary to skip symlinks, but it's simpler.
            # SVR4-like systems (e.g., Solaris 9) let you unlink files that
            # you can write, so skip writable files too.
            -l $target_file || -o _ || -d _ || -w _
              and next;

            $found_file = 1;

            # Invoke rm on this file and ensure that we get the
            # expected exit code and diagnostic.
            my $cmd = "$rm -f -- $target_file";
            open RM, "$cmd 2>&1 |"
              or die "$ME: cannot execute '$cmd'\n";

            my $line = <RM>;

            close RM;
            my $rc = $?;
            # This test opportunistically looks for files that can't
            # be removed but those files may already have been removed
            # by their owners by the time we get to them.  It is a
            # race condition.  If so then the rm is successful and our
            # test is thwarted.  Detect this case and ignore.
            if ($rc == 0)
              {
                next if ! -e $target_file;
                die "$ME: unexpected exit status from '$cmd';\n"
                  . "  got 0, expected 1\n";
              }
            if (0x80 < $rc)
              {
                my $status = $rc >> 8;
                $status == 1
                  or die "$ME: unexpected exit status from '$cmd';\n"
                    . "  got $status, expected 1\n";
              }
            else
              {
                # Terminated by a signal.
                my $sig_num = $rc & 0x7F;
                die "$ME: command '$cmd' died with signal $sig_num\n";
              }

            my $exp = "rm: cannot remove '$target_file':";
            $line
              or die "$ME: no output from '$cmd';\n"
                . "expected something like '$exp ...'\n";

            # Transform the actual diagnostic so that it starts with "rm:".
            # Depending on your system, it might be "rm:" already, or
            # "../../src/rm:".
            $line =~ s,^\Q$rm\E:,rm:,;

            my $regex = quotemeta $exp;
            $line =~ /^$regex/
              or die "$ME: unexpected diagnostic from '$cmd';\n"
                . "  got      $line"
                . "  expected $exp ...\n";

            last;
          }

        closedir DIR_HANDLE;
        $found_file
          and last;
      }
  }

$found_dir
  or CuSkip::skip "$ME: couldn't find a directory with the sticky bit set;"
    . " skipping this test\n";

$found_file
  or CuSkip::skip "$ME: couldn't find a file not owned by you\n"
    . " in any of the following directories:\n  @dir_list\n"
    . "...so, skipping this test\n";
