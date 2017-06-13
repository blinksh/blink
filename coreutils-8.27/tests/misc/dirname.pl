#!/usr/bin/perl
# Test "dirname".

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

use strict;
use File::stat;

(my $program_name = $0) =~ s|.*/||;

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my $stat_single = stat('/');
my $stat_double = stat('//');
my $double_slash = ($stat_single->dev == $stat_double->dev
                    && $stat_single->ino == $stat_double->ino) ? '/' : '//';

my $prog = 'dirname';

my @Tests =
    (
     ['fail-1', {ERR => "$prog: missing operand\n"
       . "Try '$prog --help' for more information.\n"}, {EXIT => '1'}],

     ['a', qw(d/f),        {OUT => 'd'}],
     ['b', qw(/d/f),       {OUT => '/d'}],
     ['c', qw(d/f/),       {OUT => 'd'}],
     ['d', qw(d/f//),      {OUT => 'd'}],
     ['e', qw(f),          {OUT => '.'}],
     ['f', qw(/),          {OUT => '/'}],
     ['g', qw(//),         {OUT => "$double_slash"}],
     ['h', qw(///),        {OUT => '/'}],
     ['i', qw(//a//),      {OUT => "$double_slash"}],
     ['j', qw(///a///),    {OUT => '/'}],
     ['k', qw(///a///b),   {OUT => '///a'}],
     ['l', qw(///a//b/),   {OUT => '///a'}],
     ['m', qw(''),         {OUT => '.'}],
     ['n', qw(a/b c/d),    {OUT => "a\nc"}],
    );

# Append a newline to end of each expected 'OUT' string.
my $t;
foreach $t (@Tests)
  {
    my $arg1 = $t->[1];
    my $e;
    foreach $e (@$t)
      {
        $e->{OUT} = "$e->{OUT}\n"
          if ref $e eq 'HASH' and exists $e->{OUT};
      }
  }

my $save_temps = $ENV{SAVE_TEMPS};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($program_name, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
