#!/usr/bin/perl
# Make sure a 'n' reply to 'mv -i...' aborts the move operation.

# Copyright (C) 2001-2017 Free Software Foundation, Inc.

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

my $test_a = 'a';

my @Tests =
    (
     # Make sure a 'n' reply to 'mv -i...' aborts the move operation.
     [$test_a, '-i',
      {IN => {src => "a\n"}}, {IN => {dst => "b\n"}}, '<', {IN => "n\n"},
      {ERR => "mv: overwrite 'dst'? "},
      {POST => sub { -r 'src' or die "test $test_a failed\n"}},
      {EXIT => 0},
     ],
    );

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $prog = 'mv';
my $fail = run_tests ($program_name, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
