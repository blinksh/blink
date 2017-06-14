#!/usr/bin/perl
# Newline tests for "md5sum".

# Copyright (C) 1999-2017 Free Software Foundation, Inc.

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

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

# See if we can create a file name that contains a newline.
# Use system, since Perl doesn't let you do this with "open".
system ('touch', "a\nb") == 0
  or CuSkip::skip "$ME: failed to create newline-containing file name\n";

my $degenerate = "d41d8cd98f00b204e9800998ecf8427e";
my $t = '--text';

my @Tests =
    (
     ['newline', $t, {IN=> {"a\nb"=> ''}}, {OUT=>"\\$degenerate  a\\nb\n"}],
    );

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $prog = 'md5sum';
my $fail = run_tests ($ME, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
