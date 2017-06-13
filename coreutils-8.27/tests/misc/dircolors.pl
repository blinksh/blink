#!/usr/bin/perl
# Simple dircolors tests.

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

my @Tests =
    (
     ['a', '-b', {IN => {k => "exec\n"}},
      {ERR => "dircolors: k:1: invalid line;  missing second token\n"},
      {EXIT => 1}],
     ['quote', '-b', {IN => "exec 'echo Hello;:'\n"},
      {OUT => "LS_COLORS='ex='\\''echo Hello;\\:'\\'':';\n"
      . "export LS_COLORS\n"}],
     ['other-wr', '-b', {IN => "owt 40;33\n"},
      {OUT => "LS_COLORS='tw=40;33:';\nexport LS_COLORS\n"}],
     ['term-1', '-b', {IN => "TERM none\nowt 40;33\n"},
      {OUT => "LS_COLORS='tw=40;33:';\nexport LS_COLORS\n"}],
     ['term-2', '-b', {IN => "TERM non*\nowt 40;33\n"},
      {OUT => "LS_COLORS='tw=40;33:';\nexport LS_COLORS\n"}],
     ['term-3', '-b', {IN => "TERM nomatch\nowt 40;33\n"},
      {OUT => "LS_COLORS='';\nexport LS_COLORS\n"}],
     ['term-4', '-b', {IN => "TERM N*match\nowt 40;33\n"},
      {OUT => "LS_COLORS='';\nexport LS_COLORS\n"}],

     # CAREFUL: always specify the -b option, unless explicitly testing
     # for csh syntax output.
    );

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $prog = 'dircolors';
my $fail = run_tests ($program_name, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
