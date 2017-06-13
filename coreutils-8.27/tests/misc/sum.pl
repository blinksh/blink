#!/usr/bin/perl
# Test "sum".

# Copyright (C) 2000-2017 Free Software Foundation, Inc.

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

my $in_1k = 'a' x 1024;
my $in_2k = 'b' x 2048;

my @Tests =
    (
     ['1', {IN=> {f=> ''}},	{OUT=>"00000     0\n"}],
     ['2', {IN=> {f=> 'a'}},	{OUT=>"00097     1\n"}],
     ['3', {IN=> {f=> 'abc'}},	{OUT=>"16556     1\n"}],
     ['4', {IN=> {f=> 'message digest'}}, {OUT=>"26423     1\n"}],
     ['5', {IN=> {f=> 'abcdefghijklmnopqrstuvwxyz'}}, {OUT=>"53553     1\n"}],
     ['6', {IN=> {f=> join ('', 'A'..'Z', 'a'..'z', '0'..'9')}},
                                {OUT=>"25587     1\n"}],
     ['7', {IN=> {f=> '1234567890' x 8}}, {OUT=>"21845     1\n"}],

     ['a-r-1k', '-r', {IN=> {f=> $in_1k}}, {OUT=>"65409     1\n"}],
     ['a-s-1k', '-s', {IN=> {f=> $in_1k}}, {OUT=>"33793 2 f\n"}],
     ['b-r-2k', '-r', {IN=> {f=> $in_2k}}, {OUT=>"65223     2\n"}],
     ['b-s-2k', '-s', {IN=> {f=> $in_2k}}, {OUT=>"4099 4 f\n"}],

     ['1s', '-s', {IN=> {f=> ''}},	{OUT=>"0 0 f\n"}],
     ['2s', '-s', {IN=> {f=> 'a'}},	{OUT=>"97 1 f\n"}],
     ['3s', '-s', {IN=> {f=> 'abc'}},	{OUT=>"294 1 f\n"}],
     ['4s', '-s', {IN=> {f=> 'message digest'}}, {OUT=>"1413 1 f\n"}],
     ['5s', '-s', {IN=> {f=> 'abcdefghijklmnopqrstuvwxyz'}},
                                        {OUT=>"2847 1 f\n"}],
     ['6s', '-s', {IN=> {f=> join ('', 'A'..'Z', 'a'..'z', '0'..'9')}},
                                        {OUT=>"5387 1 f\n"}],
     ['7s', '-s', {IN=> {f=> '1234567890' x 8}}, {OUT=>"4200 1 f\n"}],
    );

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $prog = 'sum';
my $fail = run_tests ($program_name, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
