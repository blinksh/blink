#!/usr/bin/perl
# Exercise dd's conv=unblock mode

# Copyright (C) 2009-2017 Free Software Foundation, Inc.

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
my $out = 'out';

my @t =
  (
   # An empty test name signals that these are the arguments to use for the
   # following tests.
   ['', [qw (cbs=3 conv=unblock status=noxfer < )]],
   ['0', '', ''],
   ['1', "a\n  ", "a\n\n\n"],
   ['2', "a\n ",  "a\n\n"],
   ['3', "a  ",   "a\n"],
   ['4', "a \n ", "a \n\n\n"],
   ['5', "a \n",  "a \n\n"],
   ['6', "a   ",  "a\n\n"],
   ['7', "a  \n", "a\n\n\n"],
  );

my @Tests;
my $args;
foreach my $t (@t)
  {
    $t->[0] eq ''
      and $args = $t->[1], next;

    push @Tests, [$t->[0], @$args, {IN=>$t->[1]}, {OUT=>$t->[2]},
                  {ERR_SUBST=>'s/^\d+\+\d+ records (?:in|out)$//'},
                  {ERR=>"\n\n"}];
  }

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $prog = 'dd';
my $fail = run_tests ($program_name, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
