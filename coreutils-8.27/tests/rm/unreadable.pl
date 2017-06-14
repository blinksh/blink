#!/usr/bin/perl
# Test "rm" and unreadable directories.

# Copyright (C) 1998-2017 Free Software Foundation, Inc.

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

(my $program_name = $0) =~ s|.*/||;

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my $d = "dir-$$";
my $mkdir = {PRE => sub {mkdir $d,0100 or die "$d: $!\n"}};
my $prog = 'rm';
my $uid = $<;

my @Tests =
    (
     # test-name options input expected-output
     #
     # Removing an empty, unwritable directory succeeds.
     ['unreadable-1', '-rf', $d, {EXIT => 0}, $mkdir],

     ['unreadable-2', '-rf', $d,
      {EXIT => $uid == 0 ? 0 : 1},
      {ERR => $uid == 0 ? ''
                        : "$prog: cannot remove '$d': Permission denied\n"},
      {PRE => sub { (mkdir $d,0700 and mkdir "$d/x",0700 and chmod 0100,$d)
                    or die "$d: $!\n"}} ],
    );

my $save_temps = $ENV{SAVE_TEMPS};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($program_name, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
