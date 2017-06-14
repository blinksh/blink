#!/usr/bin/perl
# Basic tests for "expr".

# Copyright (C) 2001-2017 Free Software Foundation, Inc.

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
my $prog = 'expr';

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my $big =      '98782897298723498732987928734';
my $big_p1 =   '98782897298723498732987928735';
my $big_sum = '197565794597446997465975857469';
my $big_prod = '9758060798730154302876482828124348356960410232492450771490';

my @Tests =
    (
     ['a', '5 + 6', {OUT => '11'}],
     ['b', '5 - 6', {OUT => '-1'}],
     ['c', '5 \* 6', {OUT => '30'}],
     ['d', '100 / 6', {OUT => '16'}],
     ['e', '100 % 6', {OUT => '4'}],
     ['f', '3 + -2', {OUT => '1'}],
     ['g', '-2 + -2', {OUT => '-4'}],

     # Verify option processing.
     # Added when option processing broke in the 7.0 beta release
     ['opt1', '-- -11 + 12', {OUT => '1'}],
     ['opt2', '-11 + 12', {OUT => '1'}],
     ['opt3', '-- -1 + 2', {OUT => '1'}],
     ['opt4', '-1 + 2', {OUT => '1'}],
     # This evoked a syntax error diagnostic before 2.0.12.
     ['opt5', '-- 2 + 2', {OUT => '4'}],

     ['paren1', '\( 100 % 6 \)', {OUT => '4'}],
     ['paren2', '\( 100 % 6 \) - 8', {OUT => '-4'}],
     ['paren3', '9 / \( 100 % 6 \) - 8', {OUT => '-6'}],
     ['paren4', '9 / \( \( 100 % 6 \) - 8 \)', {OUT => '-2'}],
     ['paren5', '9 + \( 100 % 6 \)', {OUT => '13'}],

     # Before 2.0.12, this would output '1'.
     ['0bang', '00 \< 0!', {OUT => '0'}, {EXIT => 1}],

     # In 5.1.3 and earlier, these would exit with status 0.
     ['00', '00', {OUT => '00'}, {EXIT => 1}],
     ['minus0', '-0', {OUT => '-0'}, {EXIT => 1}],

     # In 5.1.3 and earlier, these would report errors.
     ['andand', '0 \& 1 / 0', {OUT => '0'}, {EXIT => 1}],
     ['oror', '1 \| 1 / 0', {OUT => '1'}, {EXIT => 0}],

     # In 5.1.3 and earlier, this would output the empty string.
     ['orempty', '"" \| ""', {OUT => '0'}, {EXIT => 1}],


     # This erroneously succeeded and output '3' before 2.0.12.
     ['fail-a', '3 + -', {ERR => "$prog: non-integer argument\n"},
      {EXIT => 2}],

     # This erroneously succeeded before 5.3.1.
     ['bigcmp', '-- -2417851639229258349412352 \< 2417851639229258349412352',
      {OUT => '1'}, {EXIT => 0}],

     # In 5.94 and earlier, anchors incorrectly matched newlines.
     ['anchor', "'a\nb' : 'a\$'", {OUT => '0'}, {EXIT => 1}],

     # These tests are taken from grep/tests/bre.tests.
     ['bre1', '"abc" : "a\\(b\\)c"', {OUT => 'b'}],
     ['bre2', '"a(" : "a("', {OUT => '2'}],
     ['bre3', '_ : "a\\("',
      {ERR => "$prog: Unmatched ( or \\(\n"}, {EXIT => 2}],
     ['bre4', '_ : "a\\(b"',
      {ERR => "$prog: Unmatched ( or \\(\n"}, {EXIT => 2}],
     ['bre5', '"a(b" : "a(b"', {OUT => '3'}],
     ['bre6', '"a)" : "a)"', {OUT => '2'}],
     ['bre7', '_ : "a\\)"',
      {ERR => "$prog: Unmatched ) or \\)\n"}, {EXIT => 2}],
     ['bre8', '_ : "\\)"',
      {ERR => "$prog: Unmatched ) or \\)\n"}, {EXIT => 2}],
     ['bre9', '"ab" : "a\\(\\)b"', {OUT => ''}, {EXIT => 1}],
     ['bre10', '"a^b" : "a^b"', {OUT => '3'}],
     ['bre11', '"a\$b" : "a\$b"', {OUT => '3'}],
     ['bre12', '"" : "\\($\\)\\(^\\)"', {OUT => ''}, {EXIT => 1}],
     ['bre13', '"b" : "a*\\(^b\$\\)c*"', {OUT => 'b'}],
     ['bre14', '"X|" : "X\\(|\\)" : "(" "X|" : "X\\(|\\)" ")"', {OUT => '1'}],
     ['bre15', '"X*" : "X\\(*\\)" : "(" "X*" : "X\\(*\\)" ")"', {OUT => '1'}],
     ['bre16', '"abc" : "\\(\\)"', {OUT => ''}, {EXIT => 1}],
     ['bre17', '"{1}a" : "\\(\\{1\\}a\\)"', {OUT => '{1}a'}],
     ['bre18', '"X*" : "X\\(*\\)" : "^*"', {OUT => '1'}],
     ['bre19', '"{1}" : "^\\{1\\}"', {OUT => '3'}],
     ['bre20', '"{" : "{"', {OUT => '1'}],
     ['bre21', '"abbcbd" : "a\\(b*\\)c\\1d"', {OUT => ''}, {EXIT => 1}],
     ['bre22', '"abbcbbbd" : "a\\(b*\\)c\\1d"', {OUT => ''}, {EXIT => 1}],
     ['bre23', '"abc" : "\\(.\\)\\1"', {OUT => ''}, {EXIT => 1}],
     ['bre24', '"abbccd" : "a\\(\\([bc]\\)\\2\\)*d"', {OUT => 'cc'}],
     ['bre25', '"abbcbd" : "a\\(\\([bc]\\)\\2\\)*d"',
      {OUT => ''}, {EXIT => 1}],
     ['bre26', '"abbbd" : "a\\(\\(b\\)*\\2\\)*d"', {OUT => 'bbb'}],
     ['bre27', '"aabcd" : "\\(a\\)\\1bcd"', {OUT => 'a'}],
     ['bre28', '"aabcd" : "\\(a\\)\\1bc*d"', {OUT => 'a'}],
     ['bre29', '"aabd" : "\\(a\\)\\1bc*d"', {OUT => 'a'}],
     ['bre30', '"aabcccd" : "\\(a\\)\\1bc*d"', {OUT => 'a'}],
     ['bre31', '"aabcccd" : "\\(a\\)\\1bc*[ce]d"', {OUT => 'a'}],
     ['bre32', '"aabcccd" : "\\(a\\)\\1b\\(c\\)*cd\$"', {OUT => 'a'}],
     ['bre33', '"a*b" : "a\\(*\\)b"', {OUT => '*'}],
     ['bre34', '"ab" : "a\\(**\\)b"', {OUT => ''}, {EXIT => 1}],
     ['bre35', '"ab" : "a\\(***\\)b"', {OUT => ''}, {EXIT => 1}],
     ['bre36', '"*a" : "*a"', {OUT => '2'}],
     ['bre37', '"a" : "**a"', {OUT => '1'}],
     ['bre38', '"a" : "***a"', {OUT => '1'}],
     ['bre39', '"ab" : "a\\{1\\}b"', {OUT => '2'}],
     ['bre40', '"ab" : "a\\{1,\\}b"', {OUT => '2'}],
     ['bre41', '"aab" : "a\\{1,2\\}b"', {OUT => '3'}],
     ['bre42', '_ : "a\\{1"',
      {ERR => "$prog: Unmatched \\{\n"}, {EXIT => 2}],
     ['bre43', '_ : "a\\{1a"',
      {ERR => "$prog: Unmatched \\{\n"}, {EXIT => 2}],
     ['bre44', '_ : "a\\{1a\\}"',
      {ERR => "$prog: Invalid content of \\{\\}\n"}, {EXIT => 2}],
     ['bre45', '"a" : "a\\{,2\\}"', {OUT => '1'}],
     ['bre46', '"a" : "a\\{,\\}"', {OUT => '1'}],
     ['bre47', '_ : "a\\{1,x\\}"',
      {ERR => "$prog: Invalid content of \\{\\}\n"}, {EXIT => 2}],
     ['bre48', '_ : "a\\{1,x"',
      {ERR => "$prog: Unmatched \\{\n"}, {EXIT => 2}],
     ['bre49', '_ : "a\\{32768\\}"',
      {ERR => "$prog: Invalid content of \\{\\}\n"}, {EXIT => 2},
      # Map AIX-6's different diagnostic to the one we expect:
      {ERR_SUBST =>
       's,Regular expression too big,Invalid content of \\\\{\\\\},'},
      ],
     ['bre50', '_ : "a\\{1,0\\}"',
      {ERR => "$prog: Invalid content of \\{\\}\n"}, {EXIT => 2}],
     ['bre51', '"acabc" : ".*ab\\{0,0\\}c"', {OUT => '2'}],
     ['bre52', '"abcac" : "ab\\{0,1\\}c"', {OUT => '3'}],
     ['bre53', '"abbcac" : "ab\\{0,3\\}c"', {OUT => '4'}],
     ['bre54', '"abcac" : ".*ab\\{1,1\\}c"', {OUT => '3'}],
     ['bre55', '"abcac" : ".*ab\\{1,3\\}c"', {OUT => '3'}],
     ['bre56', '"abbcabc" : ".*ab\{2,2\}c"', {OUT => '4'}],
     ['bre57', '"abbcabc" : ".*ab\{2,4\}c"', {OUT => '4'}],
     ['bre58', '"aa" : "a\\{1\\}\\{1\\}"', {OUT => '1'}],
     ['bre59', '"aa" : "a*\\{1\\}"', {OUT => '2'}],
     ['bre60', '"aa" : "a\\{1\\}*"', {OUT => '2'}],
     ['bre61', '"acd" : "a\\(b\\)?c\\1d"', {OUT => ''}, {EXIT => 1}],
     ['bre62', '-- "-5" : "-\\{0,1\\}[0-9]*\$"', {OUT => '2'}],

     ['fail-b', '9 9', {ERR => "$prog: syntax error\n"},
      {EXIT => 2}],
     ['fail-c', {ERR => "$prog: missing operand\n"
                 . "Try '$prog --help' for more information.\n"},
      {EXIT => 2}],

     ['bignum-add', "$big + 1", {OUT => $big_p1}],
     ['bignum-add2', "$big + $big_p1", {OUT => $big_sum}],
     ['bignum-sub', "$big_p1 - 1", {OUT => $big}],
     ['bignum-sub2', "$big_sum - $big", {OUT => $big_p1}],
     ['bignum-mul', "$big_p1 '*' $big", {OUT => $big_prod}],
     ['bignum-div', "$big_prod / $big", {OUT => $big_p1}],
    );

# If using big numbers fails, remove all /^bignum-/ tests
qx!expr $big_prod '*' $big_prod '*' $big_prod!
  or @Tests = grep {$_->[0] !~ /^bignum-/} @Tests;

# Append a newline to end of each expected 'OUT' string.
my $t;
foreach $t (@Tests)
  {
    my $arg1 = $t->[1];
    my $e;
    foreach $e (@$t)
      {
        $e->{OUT} .= "\n"
          if ref $e eq 'HASH' and exists $e->{OUT};
      }
  }

my $save_temps = $ENV{SAVE_TEMPS};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($program_name, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
