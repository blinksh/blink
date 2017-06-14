#!/usr/bin/perl
# improve printf.c test coverage

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

my $prog = 'printf';
my $try = "Try '$prog --help' for more information.\n";
my $pow_2_31 = 2**31;

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my @Tests =
(
  ['no-args', {EXIT=>1}, {ERR=>"$prog: missing operand\n$try"}],
  ['no-arg2', '--', {EXIT=>1}, {ERR=>"$prog: missing operand\n$try"}],
  ['escape-1', q('\a\b\f\n\r\t\v\z\c'), {OUT=>"\a\b\f\n\r\t\x0b\\z"}],
  ['hex-ucX',   '%X 999',    {OUT=>"3E7"}],
  ['hex-ucXw',  '%4X 999',   {OUT=>" 3E7"}],
  ['hex-ucXp',  '%.4X 999',  {OUT=>"03E7"}],
  ['hex-ucXwp', '%5.4X 999', {OUT=>" 03E7"}],
  ['hex-vw',   '%*X 4 42',  {OUT=>"  2A"}],
  ['hex-vp',   '%.*X 4 42',  {OUT=>"002A"}],
  ['hex-vwvp', '%*.*X 3 2 15',  {OUT=>" 0F"}],
  ['b', q('nl\ntab\tx'), {OUT=>"nl\ntab\tx"}],
  ['c1', '%c 123',     {OUT=>"1"}],
  ['cw', '%\*c 3 123', {OUT=>"  1"}],
  ['d-ucXwp', '%5.4d 999', {OUT=>" 0999"}],
  ['d-vw',   '%*d 4 42',  {OUT=>"  42"}],
  ['d-vp',   '%.*d 4 42',  {OUT=>"0042"}],
  ['d-vwvp', '%*.*d 3 2 15',  {OUT=>" 15"}],
  ['d-neg-prec', '%.*d -3 15',  {OUT=>"15"}],
  ['d-big-prec', "%.*d $pow_2_31 15",  # INT_MAX
   {EXIT=>1}, {ERR=>"$prog: invalid precision: '$pow_2_31'\n"}],
  ['d-big-fwidth', "%*d $pow_2_31 15",  # INT_MAX
   {EXIT=>1}, {ERR=>"$prog: invalid field width: '$pow_2_31'\n"}],
  ['F',  '%F  1',  {OUT=>"1.000000"}],
  ['LF', '%LF 1',  {OUT=>"1.000000"}],
  ['E',  '%E  2',  {OUT=>"2.000000E+00"}],
  ['LE', '%LE 2',  {OUT=>"2.000000E+00"}],
  ['s', '%s x',      {OUT=>"x"}],
  ['sw', '%\*s 2 x', {OUT=>" x"}],
  ['sp',  '%.\*s 2 abcd',  {OUT=>"ab"}],
  ['swp', '%\*.\*s 2 2 abcd',  {OUT=>"ab"}],
  ['sw-no-args', '%\*s'],
  ['sw-no-args2', '%.\*s'],
  ['G-ucXwp', '%5.4G 3', {OUT=>"    3"}],
  ['G-vw',   '%*G 4 42',  {OUT=>"  42"}],
  ['G-vp',   '%.*G 4 42',  {OUT=>"42"}],
  ['G-vwvp', '%*.*G 5 3 15',  {OUT=>"   15"}],
  ['esc', q('\xaa\0377'),  {OUT=>"\xaa\0377"}],
  ['esc-bad-hex', q('\x'), {EXIT=>1},
    {ERR=>"$prog: missing hexadecimal number in escape\n"}],
  # ['u4', q('\u09ac'), {OUT=>"\xe0a6ac"}],
  ['u-invalid', q('\u0000'), {EXIT=>1},
    {ERR=>"$prog: invalid universal character name \\u0000\n"}],
  ['u-missing', q('\u'), {EXIT=>1},
    {ERR=>"$prog: missing hexadecimal number in escape\n"}],
  ['d-invalid', '%d no-num', {OUT=>'0'}, {EXIT=>1},
    # Depending on the strtol implementation we expect one of these:
    #   no-num: Invalid argument         (FreeBSD6)
    #   no-num: expected a numeric value (glibc, Solaris 10)
    {ERR_SUBST => 's/Invalid argument$/expected a numeric value/'},
    {ERR=>"$prog: 'no-num': expected a numeric value\n"}],
  ['d-bad-suffix', '%d 9z', {OUT=>'9'}, {EXIT=>1},
    {ERR=>"$prog: '9z': value not completely converted\n"}],
  ['d-out-of-range', '%d '.('9'x30), {EXIT=>1},
    {OUT=>"inaccurate"}, {OUT_SUBST => 's/\d+/inaccurate/'},
    {ERR=>"$prog: 9...9\n"}, {ERR_SUBST => "s/'9+.*/9...9/"}],
  ['excess', 'B 1', {OUT=>'B'},
    {ERR=>"$prog: warning: ignoring excess arguments, starting with '1'\n"}],
  ['percent', '%%', {OUT=>'%'}],
  ['d-sp',    q('% d' 33), {OUT=>' 33'}],
  ['d-plus',  q('%+d' 33), {OUT=>'+33'}],
  ['d-minus', q('%-d' 33), {OUT=> '33'}],
  ['d-zero',  q('%02d' 1), {OUT=> '01'}],
  ['d-quote', q("%'d" 3333), {OUT=> '3333'}, {OUT_SUBST => 'tr/3//c'}],
  ['d-hash', q("%#d" 3333), {EXIT=>1},
    {ERR=>"$prog: %#d: invalid conversion specification\n"}],
);

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($prog, \$prog, \@Tests, $save_temps, $verbose);
exit $fail;
