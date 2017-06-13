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

my $prog = 'tr';

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my $map_all_to_1 =
  "$prog: when translating with complemented character classes,\n"
    . "string2 must map all characters in the domain to one\n";

my @Tests =
(
  ['1', qw(abcd '[]*]'),   {IN=>'abcd'}, {OUT=>']]]]'}],
  ['2', qw(abc '[%*]xyz'), {IN=>'abc'}, {OUT=>'xyz'}],
  ['3', qw('' '[.*]'),     {IN=>'abc'}, {OUT=>'abc'}],

  # Test --truncate-set1 behavior when string1 is longer than string2
  ['4', qw(-t abcd xy), {IN=>'abcde'}, {OUT=>'xycde'}],
  # Test bsd behavior (the default) when string1 is longer than string2
  ['5', qw(abcd xy), {IN=>'abcde'}, {OUT=>'xyyye'}],
  # Do it the posix way
  ['6', qw(abcd 'x[y*]'), {IN=>'abcde'}, {OUT=>'xyyye'}],
  ['7', qw(-s a-p '%[.*]$'), {IN=>'abcdefghijklmnop'}, {OUT=>'%.$'}],
  ['8', qw(-s a-p '[.*]$'), {IN=>'abcdefghijklmnop'}, {OUT=>'.$'}],
  ['9', qw(-s a-p '%[.*]'), {IN=>'abcdefghijklmnop'}, {OUT=>'%.'}],
  ['a', qw(-s '[a-z]'), {IN=>'aabbcc'}, {OUT=>'abc'}],
  ['b', qw(-s '[a-c]'), {IN=>'aabbcc'}, {OUT=>'abc'}],
  ['c', qw(-s '[a-b]'), {IN=>'aabbcc'}, {OUT=>'abcc'}],
  ['d', qw(-s '[b-c]'), {IN=>'aabbcc'}, {OUT=>'aabc'}],
  ['e', qw(-s '[\0-\5]'),
   {IN=>"\0\0a\1\1b\2\2\2c\3\3\3d\4\4\4\4e\5\5"}, {OUT=>"\0a\1b\2c\3d\4e\5"}],
  # tests of delete
  ['f', qw(-d '[=[=]'), {IN=>'[[[[[[[]]]]]]]]'}, {OUT=>']]]]]]]]'}],
  ['g', qw(-d '[=]=]'), {IN=>'[[[[[[[]]]]]]]]'}, {OUT=>'[[[[[[['}],
  ['h', qw(-d '[:xdigit:]'), {IN=>'0123456789acbdefABCDEF'}, {OUT=>''}],
  ['i', qw(-d '[:xdigit:]'), {IN=>'w0x1y2z3456789acbdefABCDEFz'},
   {OUT=>'wxyzz'}],
  ['j', qw(-d '[:digit:]'), {IN=>'0123456789'}, {OUT=>''}],
  ['k', qw(-d '[:digit:]'),
   {IN=>'a0b1c2d3e4f5g6h7i8j9k'}, {OUT=>'abcdefghijk'}],
  ['l', qw(-d '[:lower:]'), {IN=>'abcdefghijklmnopqrstuvwxyz'}, {OUT=>''}],
  ['m', qw(-d '[:upper:]'), {IN=>'ABCDEFGHIJKLMNOPQRSTUVWXYZ'}, {OUT=>''}],
  ['n', qw(-d '[:lower:][:upper:]'),
   {IN=>'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'}, {OUT=>''}],
  ['o', qw(-d '[:alpha:]'),
   {IN=>'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'}, {OUT=>''}],
  ['p', qw(-d '[:alnum:]'),
   {IN=>'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'},
   {OUT=>''}],
  ['q', qw(-d '[:alnum:]'),
   {IN=>'.abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.'},
   {OUT=>'..'}],
  ['r', qw(-ds '[:alnum:]' .),
   {IN=>'.abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.'},
   {OUT=>'.'}],

  # The classic example, with string2 BSD-style
  ['s', qw(-cs '[:alnum:]' '\n'),
   {IN=>'The big black fox jumped over the fence.'},
   {OUT=>"The\nbig\nblack\nfox\njumped\nover\nthe\nfence\n"}],

  # The classic example, POSIX-style
  ['t', qw(-cs '[:alnum:]' '[\n*]'),
   {IN=>'The big black fox jumped over the fence.'},
   {OUT=>"The\nbig\nblack\nfox\njumped\nover\nthe\nfence\n"}],
  ['u', qw(-ds b a), {IN=>'aabbaa'}, {OUT=>'a'}],
  ['v', qw(-ds '[:xdigit:]' Z), {IN=>'ZZ0123456789acbdefABCDEFZZ'}, {OUT=>'Z'}],

  # Try some data with 8th bit set in case something is mistakenly
  # sign-extended.
  ['w', qw(-ds '\350' '\345'),
   {IN=>"\300\301\377\345\345\350\345"},
   {OUT=>"\300\301\377\345"}],
  ['x', qw(-s abcdefghijklmn '[:*016]'),
   {IN=>'abcdefghijklmnop'}, {OUT=>':op'}],
  ['y', qw(-d a-z), {IN=>'abc $code'}, {OUT=>' $'}],
  ['z', qw(-ds a-z '$.'), {IN=>'a.b.c $$$$code\\'}, {OUT=>'. $\\'}],

  # Make sure that a-a is accepted.
  ['range-a-a', qw(a-a z), {IN=>'abc'}, {OUT=>'zbc'}],
  #
  ['null', qw(a ''), {IN=>''}, {OUT=>''}, {EXIT=>1},
   {ERR=>"$prog: when not truncating set1, string2 must be non-empty\n"}],
  ['upcase', qw('[:lower:]' '[:upper:]'),
   {IN=>'abcxyzABCXYZ'},
   {OUT=>'ABCXYZABCXYZ'}],
  ['dncase', qw('[:upper:]' '[:lower:]'),
   {IN=>'abcxyzABCXYZ'},
   {OUT=>'abcxyzabcxyz'}],
  #
  ['rep-cclass', qw('a[=*2][=c=]' xyyz), {IN=>'a=c'}, {OUT=>'xyz'}],
  ['rep-1', qw('[:*3][:digit:]' a-m), {IN=>':1239'}, {OUT=>'cefgm'}],
  ['rep-2', qw('a[b*512]c' '1[x*]2'), {IN=>'abc'}, {OUT=>'1x2'}],
  ['rep-3', qw('a[b*513]c' '1[x*]2'), {IN=>'abc'}, {OUT=>'1x2'}],
  # Another couple octal repeat count tests.
  ['o-rep-1', qw('[b*08]' '[x*]'), {IN=>''}, {OUT=>''}, {EXIT=>1},
   {ERR=>"$prog: invalid repeat count '08' in [c*n] construct\n"}],
  ['o-rep-2', qw('[b*010]cd' '[a*7]BC[x*]'), {IN=>'bcd'}, {OUT=>'BCx'}],

  ['esc', qw('a\-z' A-Z), {IN=>'abc-z'}, {OUT=>'AbcBC'}],
  ['bs-055', qw('a\055b' def), {IN=>"a\055b"}, {OUT=>'def'}],
  ['bs-at-end', qw('\\' x), {IN=>"\\"}, {OUT=>'x'},
   {ERR=>"$prog: warning: an unescaped backslash at end of "
    . "string is not portable\n"}],

  #
  # From Ross
  ['ross-0a', qw(-cs '[:upper:]' 'X[Y*]'), {IN=>''}, {OUT=>''}, {EXIT=>1},
   {ERR=>$map_all_to_1}],
  ['ross-0b', qw(-cs '[:cntrl:]' 'X[Y*]'), {IN=>''}, {OUT=>''}, {EXIT=>1},
   {ERR=>$map_all_to_1}],
  ['ross-1a', qw(-cs '[:upper:]' '[X*]'),
   {IN=>'AMZamz123.-+AMZ'}, {OUT=>'AMZXAMZ'}],
  ['ross-1b', qw(-cs '[:upper:][:digit:]' '[Z*]'), {IN=>''}, {OUT=>''}],
  ['ross-2', qw(-dcs '[:lower:]' n-rs-z),
   {IN=>'amzAMZ123.-+amz'}, {OUT=>'amzamz'}],
  ['ross-3', qw(-ds '[:xdigit:]' '[:alnum:]'),
   {IN=>'.ZABCDEFGzabcdefg.0123456788899.GG'}, {OUT=>'.ZGzg..G'}],
  ['ross-4', qw(-dcs '[:alnum:]' '[:digit:]'), {IN=>''}, {OUT=>''}],
  ['ross-5', qw(-dc '[:lower:]'), {IN=>''}, {OUT=>''}],
  ['ross-6', qw(-dc '[:upper:]'), {IN=>''}, {OUT=>''}],

  # Ensure that these fail.
  # Prior to 2.0.20, each would evoke a failed assertion.
  ['empty-eq', qw('[==]' x), {IN=>''}, {OUT=>''}, {EXIT=>1},
   {ERR=>"$prog: missing equivalence class character '[==]'\n"}],
  ['empty-cc', qw('[::]' x), {IN=>''}, {OUT=>''}, {EXIT=>1},
   {ERR=>"$prog: missing character class name '[::]'\n"}],

  # Weird repeat counts.
  ['repeat-bs-9', qw(abc '[b*\9]'), {IN=>'abcd'}, {OUT=>'[b*d'}],
  ['repeat-0', qw(abc '[b*0]'), {IN=>'abcd'}, {OUT=>'bbbd'}],
  ['repeat-zeros', qw(abc '[b*00000000000000000000]'),
   {IN=>'abcd'}, {OUT=>'bbbd'}],
  ['repeat-compl', qw(-c '[a*65536]\n' '[b*]'), {IN=>'abcd'}, {OUT=>'abbb'}],
  ['repeat-xC', qw(-C '[a*65536]\n' '[b*]'), {IN=>'abcd'}, {OUT=>'abbb'}],

  # From Glenn Fowler.
  ['fowler-1', qw(ah -H), {IN=>'aha'}, {OUT=>'-H-'}],

  # Up to coreutils-6.9, this would provoke a failed assertion.
  ['no-abort-1', qw(-c a '[b*256]'), {IN=>'abc'}, {OUT=>'abb'}],
);

@Tests = triple_test \@Tests;

# tr takes its input only from stdin, not from a file argument, so
# remove the tests that provide file arguments and keep only the ones
# generated by triple_test (identifiable by their .r and .p suffixes).
@Tests = grep {$_->[0] =~ /\.[pr]$/} @Tests;

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($prog, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
