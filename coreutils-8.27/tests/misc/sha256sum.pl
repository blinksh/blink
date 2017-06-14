#!/usr/bin/perl
# Test "sha256sum".

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

my $sha_degenerate = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";

my @Tests =
    (
     ['s1', {IN=> {f=> ''}},
                        {OUT=>"$sha_degenerate  f\n"}],
     ['s2', {IN=> {f=> 'a'}},
                        {OUT=>"ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb  f\n"}],
     ['s3', {IN=> {f=> 'abc'}},
                        {OUT=>"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  f\n"}],
     ['s4',
      {IN=> {f=> 'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'}},
                        {OUT=>"248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1  f\n"}],
     ['s8', {IN=> {f=> 'a' x 1000000}},
                        {OUT=>"cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0  f\n"}],
    );

# Insert the '--text' argument for each test.
my $t;
foreach $t (@Tests)
  {
    splice @$t, 1, 0, '--text' unless @$t[1] =~ /--check/;
  }

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $prog = 'sha256sum';
my $fail = run_tests ($program_name, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
