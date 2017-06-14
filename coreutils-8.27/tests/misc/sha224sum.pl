#!/usr/bin/perl
# Test "sha224sum".

# Copyright (C) 2005-2017 Free Software Foundation, Inc.

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

my @Tests =
    (
     ['s3', {IN=> {f=> 'abc'}},
      {OUT=>"23097d223405d8228642a477bda255b32aadbce4bda0b3f7e36c9da7  f\n"}],
     ['s4',
      {IN=> {f=> 'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'}},
      {OUT=>"75388b16512776cc5dba5da1fd890150b0c6455cb4f58b1952522525  f\n"}],
     ['s8', {IN=> {f=> 'a' x 1000000}},
      {OUT=>"20794655980c91d8bbb4c1ea97618a4bf03f42581948b2ee4ee7ad67  f\n"}],
    );

# Insert the '--text' argument for each test.
my $t;
foreach $t (@Tests)
  {
    splice @$t, 1, 0, '--text' unless @$t[1] =~ /--check/;
  }

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $prog = 'sha224sum';
my $fail = run_tests ($program_name, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
