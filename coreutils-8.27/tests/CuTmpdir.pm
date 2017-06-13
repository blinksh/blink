package CuTmpdir;
# create, then chdir into a temporary sub-directory

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

use strict;
use warnings;

use File::Temp;
use File::Find;

our $ME = $0 || "<???>";

my $dir;

sub skip_test($)
{
  warn "$ME: skipping test: unsafe working directory name: '$_[0]'\n";
  exit 77;
}

sub chmod_1
{
  my $name = $_;

  # Skip symlinks and non-directories.
  -l $name || !-d _
    and return;

  chmod 0700, $name;
}

sub chmod_tree
{
  # When tempdir fails, it croaks, which leaves $dir undefined.
  defined $dir
    or return;

  # Perform the equivalent of find "$dir" -type d -print0|xargs -0 chmod -R 700.
  my $options = {untaint => 1, wanted => \&chmod_1};
  find ($options, $dir);
}

sub import {
  my $prefix = $_[1];

  $ME eq '-' && defined $prefix
    and $ME = $prefix;

  if ($prefix !~ /^\//)
    {
      eval 'use Cwd';
      my $cwd = $@ ? '.' : Cwd::getcwd();
      $prefix = "$cwd/$prefix";
    }

  # Untaint for the upcoming mkdir.
  $prefix =~ m!^([-+\@\w./]+)$!
    or skip_test $prefix;
  $prefix = $1;

  my $original_pid = $$;

  my $on_sig_remove_tmpdir = sub {
    my ($sig) = @_;
    if ($$ == $original_pid and defined $dir)
      {
        chmod_tree;
        # Older versions of File::Temp lack this method.
        exists &File::Temp::cleanup
          and &File::Temp::cleanup;
      }
    $SIG{$sig} = 'DEFAULT';
    kill $sig, $$;
  };

  foreach my $sig (qw (INT TERM HUP))
    {
      $SIG{$sig} = $on_sig_remove_tmpdir;
    }

  $dir = File::Temp::tempdir("$prefix.tmp-XXXX", CLEANUP => 1 );
  chdir $dir
    or warn "$ME: failed to chdir to $dir: $!\n";
}

END {
  # Move cwd out of the directory we're about to remove.
  # This is required on some systems, and by some versions of File::Temp.
  chdir '..'
    or warn "$ME: failed to chdir to .. from $dir: $!\n";

  my $saved_errno = $?;
  chmod_tree;
  $? = $saved_errno;
}

1;
