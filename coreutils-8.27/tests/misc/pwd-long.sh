#!/bin/sh
# -*- perl -*-
# Ensure that pwd works even when run from a very deep directory.

# Copyright (C) 2006-2017 Free Software Foundation, Inc.

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
print_ver_ pwd

require_readable_root_
require_perl_

ARGV_0=$0
export ARGV_0

# Don't use CuTmpdir here, since File::Temp's use of rmtree can't
# remove the deep tree we create.
$PERL -Tw -I"$abs_srcdir/tests" -MCuSkip -- - <<\EOF

# Show that pwd works even when the length of the resulting
# directory name is longer than PATH_MAX.
use strict;

(my $ME = $ENV{ARGV_0}) =~ s|.*/||;

sub normalize_to_cwd_relative ($$$)
{
  my ($dir, $dev, $ino) = @_;
  my $slash = -1;
  my $next_slash;
  while (1)
    {
      $slash = index $dir, '/', $slash + 1;
      $slash <= -1
        and die "$ME: $dir does not contain old CWD\n";
      my $dir_prefix = $slash ? substr ($dir, 0, $slash) : '/';
      my ($d, $i) = (stat $dir_prefix)[0, 1];
      defined $d && defined $i
        or die "$ME: $dir_prefix: stat failed: $!\n";
      $d eq $dev && $i eq $ino
        and return substr $dir, $slash + 1;
    }
}

# Set up a safe, well-known environment
$ENV{IFS}  = '';

# Taint checking requires a sanitized $PATH.  This script performs no $PATH
# search, so on most Unix-based systems, it is fine simply to clear $ENV{PATH}.
# However, on Cygwin, it's used to find cygwin1.dll, so set it.
$ENV{PATH} = '/bin:/usr/bin';

# Save CWD's device and inode numbers.
my ($dev, $ino) = (stat '.')[0, 1];

# Construct the expected "."-relative part of pwd's output.
my $z = 'z' x 31;
my $n = 256;
my $expected = "/$z" x $n;
# Remove the leading "/".
substr ($expected, 0, 1) = '';

my $i = 0;
do
  {
    mkdir $z, 0700
      or CuSkip::skip "$ME: skipping this test; cannot create long "
        . "directory name at depth $i: $!\n";
    chdir $z
  }
until (++$i == $n);

my $abs_top_builddir = $ENV{abs_top_builddir};
$abs_top_builddir
  or die "$ME: envvar abs_top_builddir not defined\n";
my $build_src_dir = "$abs_top_builddir/src";
$build_src_dir =~ m!^([-+.:/\w]+)$!
  or CuSkip::skip "$ME: skipping this test; odd build source directory name:\n"
    . "$build_src_dir\n";
$build_src_dir = $1;

my $pwd_binary = "$build_src_dir/pwd";

-x $pwd_binary
  or die "$ME: $pwd_binary is not an executable file\n";
chomp (my $actual = qx!$pwd_binary!);

# Convert the absolute name from pwd into a $CWD-relative name.
# This is necessary in order to avoid a spurious failure when run
# from a directory in a bind-mounted partition.  What happens is
# pwd reads a ".." that contains two or more entries with identical
# dev,ino that match the ones we're looking for, and it chooses a
# name that does not correspond to the one already recorded in $CWD.
$actual = normalize_to_cwd_relative $actual, $dev, $ino;

if ($expected ne $actual)
  {
    my $e_len = length $expected;
    my $a_len = length $actual;
    warn "expected len: $e_len\n";
    warn "actual len:   $a_len\n";
    warn "expected: $expected\n";
    warn "actual: $actual\n";
    exit 1;
  }
EOF

fail=$?

Exit $fail
