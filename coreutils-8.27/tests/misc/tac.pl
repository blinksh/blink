#!/usr/bin/perl

# Copyright (C) 2008-2017 Free Software Foundation, Inc.

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

my $prog = 'tac';

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my $bad_dir = 'no/such/dir';

# This must be longer than 16KiB to trigger the double free in coreutils-8.5.
my $long_line = 'o' x (16 * 1024 + 1);

my @Tests =
(
  ['segfault', '-r', {IN=>"a\n"}, {IN=>"b\n"}, {OUT=>"a\nb\n"}],
  ['segfault2','-r', {IN=>"a\nb\n"}, {IN=>"1\n2\n"}, {OUT=>"b\na\n2\n1\n"}],

  ['basic-0', '', {IN=>""}, {OUT=>""}],
  ['basic-a', '', {IN=>"a"}, {OUT=>"a"}],
  ['basic-b', '', {IN=>"\n"}, {OUT=>"\n"}],
  ['basic-c', '', {IN=>"a\n"}, {OUT=>"a\n"}],
  ['basic-d', '', {IN=>"a\nb"}, {OUT=>"ba\n"}],
  ['basic-e', '', {IN=>"a\nb\n"}, {OUT=>"b\na\n"}],
  ['basic-f', '', {IN=>"1234567\n8\n"}, {OUT=>"8\n1234567\n"}],
  ['basic-g', '', {IN=>"12345678\n9\n"}, {OUT=>"9\n12345678\n"}],
  ['basic-h', '', {IN=>"123456\n8\n"}, {OUT=>"8\n123456\n"}],
  ['basic-i', '', {IN=>"12345\n8\n"}, {OUT=>"8\n12345\n"}],
  ['basic-j', '', {IN=>"1234\n8\n"}, {OUT=>"8\n1234\n"}],
  ['basic-k', '', {IN=>"123\n8\n"}, {OUT=>"8\n123\n"}],

  ['nul-0', '-s ""', {IN=>""}, {OUT=>""}],
  ['nul-a', '-s ""', {IN=>"a"}, {OUT=>"a"}],
  ['nul-b', '-s ""', {IN=>"\0"}, {OUT=>"\0"}],
  ['nul-c', '-s ""', {IN=>"a\0"}, {OUT=>"a\0"}],
  ['nul-d', '-s ""', {IN=>"a\0b"}, {OUT=>"ba\0"}],
  ['nul-e', '-s ""', {IN=>"a\0b\0"}, {OUT=>"b\0a\0"}],

  ['opt-b', '-b', {IN=>"\na\nb\nc"}, {OUT=>"\nc\nb\na"}],
  ['opt-s', '-s:', {IN=>"a:b:c:"}, {OUT=>"c:b:a:"}],
  ['opt-sb', qw(-s : -b), {IN=>":a:b:c"}, {OUT=>":c:b:a"}],
  ['opt-r', qw(-r -s '\._+'),
   {IN=>"1._2.__3.___4._"},
   {OUT=>"4._3.___2.__1._"}],

  ['opt-r2', qw(-r -s '\._+'),
   {IN=>"a.___b.__1._2.__3.___4._"},
   {OUT=>"4._3.___2.__1._b.__a.___"}],

  # This gave incorrect output (.___4._2.__3._1) with tac-1.22.
  ['opt-br', qw(-b -r -s '\._+'),
   {IN=>"._1._2.__3.___4"}, {OUT=>".___4.__3._2._1"}],

  ['opt-br2', qw(-b -r -s '\._+'),
   {IN=>".__x.___y.____z._1._2.__3.___4"},
   {OUT=>".___4.__3._2._1.____z.___y.__x"}],

  ['pipe-bad-tmpdir',
   {ENV => "TMPDIR=$bad_dir"},
   {IN_PIPE => "a\n"},
   {ERR_SUBST => "s,'$bad_dir': .*,...,"},
   {ERR => "$prog: failed to create temporary file in ...\n"},
   {EXIT => 1}],

  # coreutils-8.5's tac would double-free its primary buffer.
  ['double-free', {IN=>$long_line}, {OUT=>$long_line}],
);

@Tests = triple_test \@Tests;

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($prog, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
