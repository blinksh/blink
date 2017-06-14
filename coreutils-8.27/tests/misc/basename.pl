#!/usr/bin/perl
# Test basename.
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

my $prog = 'basename';

my @Tests =
    (
     ['fail-1', {ERR => "$prog: missing operand\n"
       . "Try '$prog --help' for more information.\n"}, {EXIT => '1'}],
     ['fail-2', qw(a b c), {ERR => "$prog: extra operand 'c'\n"
       . "Try '$prog --help' for more information.\n"}, {EXIT => '1'}],

     ['a', qw(d/f),        {OUT => 'f'}],
     ['b', qw(/d/f),       {OUT => 'f'}],
     ['c', qw(d/f/),       {OUT => 'f'}],
     ['d', qw(d/f//),      {OUT => 'f'}],
     ['e', qw(f),          {OUT => 'f'}],
     ['f', qw(/),          {OUT => '/'}],
     ['g', qw(//),         {OUT => "$double_slash"}],
     ['h', qw(///),        {OUT => '/'}],
     ['i', qw(///a///),    {OUT => 'a'}],
     ['j', qw(''),         {OUT => ''}],
     ['k', qw(aa a),       {OUT => 'a'}],
     ['l', qw(-a a b),     {OUT => "a\nb"}],
     ['m', qw(-s a aa ba ab),  {OUT => "a\nb\nab"}],
     ['n', qw(a-a -a),     {OUT => 'a'}],
     ['1', qw(f.s .s),     {OUT => 'f'}],
     ['2', qw(fs s),       {OUT => 'f'}],
     ['3', qw(fs fs),      {OUT => 'fs'}],
     ['4', qw(fs/ s),      {OUT => 'f'}],
     ['5', qw(dir/file.suf .suf),      {OUT => 'file'}],
     ['6', qw(// /),       {OUT => "$double_slash"}],
     ['7', qw(// //),      {OUT => "$double_slash"}],
     ['8', qw(fs x),       {OUT => 'fs'}],
     ['9', qw(fs ''),      {OUT => 'fs'}],
     ['10', qw(fs/ s/),    {OUT => 'fs'}],

     # Exercise -z option.
     ['z0', qw(-z a),       {OUT => "a\0"}],
     ['z1', qw(--zero a),   {OUT => "a\0"}],
     ['z2', qw(-za a b),    {OUT => "a\0b\0"}],
     ['z3', qw(-z ba a),    {OUT => "b\0"}],
     ['z4', qw(-z -s a ba), {OUT => "b\0"}],
   );

# Append a newline to end of each expected 'OUT' string.
# Skip -z tests, i.e., those whose 'OUT' string has a trailing '\0'.
my $t;
foreach $t (@Tests)
  {
    my $arg1 = $t->[1];
    my $e;
    foreach $e (@$t)
      {
        $e->{OUT} = "$e->{OUT}\n"
          if ref $e eq 'HASH' and exists $e->{OUT}
            and not $e->{OUT} =~ /\0$/;
      }
  }

my $save_temps = $ENV{SAVE_TEMPS};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($program_name, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
