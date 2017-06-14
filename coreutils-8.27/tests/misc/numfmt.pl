#!/usr/bin/perl
# Basic tests for "numfmt".

# Copyright (C) 2012-2017 Free Software Foundation, Inc.

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
my $prog = 'numfmt';

my $limits = getlimits ();

# TODO: add localization tests with "grouping"
# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my $locale = $ENV{LOCALE_FR_UTF8};
! defined $locale || $locale eq 'none'
  and $locale = 'C';

my $try = "Try '$prog --help' for more information.\n";

my @Tests =
    (
     ['1', '1234',             {OUT => "1234"}],
     ['2', '--from=si 1K',     {OUT => "1000"}],
     ['3', '--from=iec 1K',    {OUT => "1024"}],
     ['4', '--from=auto 1K',   {OUT => "1000"}],
     ['5', '--from=auto 1Ki',  {OUT => "1024"}],
     ['5.1', '--from=iec-i 1Ki',  {OUT => "1024"}],

     ['6', {IN_PIPE => "1234\n"},            {OUT => "1234"}],
     ['7', '--from=si', {IN_PIPE => "2K\n"}, {OUT => "2000"}],
     ['7a', '--invalid=fail', {IN_PIPE => "no_NL"}, {OUT => "no_NL"},
              {ERR => "$prog: invalid number: 'no_NL'\n"},
              {EXIT => '2'}],

     ['8',  '--to=si 2000',                   {OUT => "2.0K"}],
     ['9',  '--to=si 2001',                   {OUT => "2.1K"}],
     ['10', '--to=si 1999',                   {OUT => "2.0K"}],
     ['11', '--to=si --round=down   2001',   {OUT => "2.0K"}],
     ['12', '--to=si --round=down   1999',   {OUT => "1.9K"}],
     ['13', '--to=si --round=up 1901',   {OUT => "2.0K"}],
     ['14', '--to=si --round=down   1901',   {OUT => "1.9K"}],
     ['15', '--to=si --round=nearest 1901',   {OUT => "1.9K"}],
     ['16', '--to=si --round=nearest 1945',   {OUT => "1.9K"}],
     ['17', '--to=si --round=nearest 1955',   {OUT => "2.0K"}],

     ['18',  '--to=iec 2048',                  {OUT => "2.0K"}],
     ['19',  '--to=iec 2049',                  {OUT => "2.1K"}],
     ['20', '--to=iec 2047',                   {OUT => "2.0K"}],
     ['21', '--to=iec --round=down   2049',   {OUT => "2.0K"}],
     ['22', '--to=iec --round=down   2047',   {OUT => "1.9K"}],
     ['23', '--to=iec --round=up 2040',   {OUT => "2.0K"}],
     ['24', '--to=iec --round=down   2040',   {OUT => "1.9K"}],
     ['25', '--to=iec --round=nearest 1996',   {OUT => "1.9K"}],
     ['26', '--to=iec --round=nearest 1997',   {OUT => "2.0K"}],
     ['27', '--to=iec-i 2048',                  {OUT => "2.0Ki"}],

     ['neg-1', '-- -1234',                     {OUT => "-1234"}],
     ['neg-2', '--padding=5 -- -1234',         {OUT => "-1234"}],
     ['neg-3', '--padding=6 -- -1234',         {OUT => " -1234"}],
     ['neg-4', '--to=iec -- 9100 -9100',       {OUT => "8.9K\n-8.9K"}],
     ['neg-5', '-- -0.1',                      {OUT => "-0.1"}],
     ['neg-6', '-- -0',                        {OUT => "0"}],
     ['neg-7', '-- -0.-1',
              {ERR => "$prog: invalid number: '-0.-1'\n"},
              {EXIT => '2'}],

     ['float-1', '1.1',                        {OUT => "1.1"}],
     ['float-2', '1.22',                       {OUT => "1.22"}],
     ['float-3', '1.22.',
             {ERR => "$prog: invalid suffix in input: '1.22.'\n"},
             {EXIT => '2'}],

     ['unit-1', '--from-unit=512 4',   {OUT => "2048"}],
     ['unit-2', '--to-unit=512 2048',   {OUT => "4"}],
     ['unit-3', '--from-unit=512 --from=si 4M',   {OUT => "2048000000"}],
     ['unit-4', '--from-unit=512 --from=iec --to=iec 4M',   {OUT => "2.0G"}],
     ['unit-5', '--from-unit=AA --from=iec --to=iec 4M',
             {ERR => "$prog: invalid unit size: 'AA'\n"},
             {EXIT => '1'}],
     ['unit-6', '--from-unit=54W --from=iec --to=iec 4M',
             {ERR => "$prog: invalid unit size: '54W'\n"},
             {EXIT => '1'}],
     ['unit-7', '--from-unit=K 30', {OUT=>"30000"}],
     ['unit-7.1', '--from-unit=Ki 30', {OUT=>"30720"}],
     ['unit-7.2', '--from-unit=i 0',
             {ERR => "$prog: invalid unit size: 'i'\n"},
             {EXIT => '1'}],
     ['unit-7.3', '--from-unit=1i 0',
             {ERR => "$prog: invalid unit size: '1i'\n"},
             {EXIT => '1'}],
     ['unit-8', '--from-unit='.$limits->{UINTMAX_OFLOW}.' --to=iec 30',
             {ERR => "$prog: invalid unit size: '$limits->{UINTMAX_OFLOW}'\n"},
             {EXIT => '1'}],
     ['unit-9', '--from-unit=0 1',
             {ERR => "$prog: invalid unit size: '0'\n"},
             {EXIT => '1'}],
     ['unit-10', '--to-unit=0 1',
             {ERR => "$prog: invalid unit size: '0'\n"},
             {EXIT => '1'}],

     # Test Suffix logic
     ['suf-1', '4000',    {OUT=>'4000'}],
     ['suf-2', '4Q',
             {ERR => "$prog: invalid suffix in input: '4Q'\n"},
             {EXIT => '2'}],
     ['suf-2.1', '4M',
             {ERR => "$prog: rejecting suffix " .
             "in input: '4M' (consider using --from)\n"},
             {EXIT => '2'}],
     ['suf-3', '--from=si 4M',  {OUT=>'4000000'}],
     ['suf-4', '--from=si 4Q',
             {ERR => "$prog: invalid suffix in input: '4Q'\n"},
             {EXIT => '2'}],
     ['suf-5', '--from=si 4MQ',
             {ERR => "$prog: invalid suffix in input '4MQ': 'Q'\n"},
             {EXIT => '2'}],

     ['suf-6', '--from=iec 4M',  {OUT=>'4194304'}],
     ['suf-7', '--from=auto 4M',  {OUT=>'4000000'}],
     ['suf-8', '--from=auto 4Mi',  {OUT=>'4194304'}],
     ['suf-9', '--from=auto 4MiQ',
             {ERR => "$prog: invalid suffix in input '4MiQ': 'Q'\n"},
             {EXIT => '2'}],
     ['suf-10', '--from=auto 4QiQ',
             {ERR => "$prog: invalid suffix in input: '4QiQ'\n"},
             {EXIT => '2'}],

     # characters after a white space are OK - printed as-is
     ['suf-11', '"4 M"',     {OUT=>'4 M'}],

     # Custom suffix
     ['suf-12', '--suffix=Foo 70Foo',               {OUT=>'70Foo'}],
     ['suf-13', '--suffix=Foo 70',                  {OUT=>'70Foo'}],
     ['suf-14', '--suffix=Foo --from=si 70K',       {OUT=>'70000Foo'}],
     ['suf-15', '--suffix=Foo --from=si 70KFoo',    {OUT=>'70000Foo'}],
     ['suf-16', '--suffix=Foo --to=si   7000Foo',    {OUT=>'7.0KFoo'}],
     ['suf-17', '--suffix=Foo --to=si   7000Bar',
              {ERR => "$prog: invalid suffix in input: '7000Bar'\n"},
              {EXIT => '2'}],
     ['suf-18', '--suffix=Foo --to=si   7000FooF',
              {ERR => "$prog: invalid suffix in input: '7000FooF'\n"},
              {EXIT => '2'}],
     # space(s) between number and suffix.  Note only field 1 is used
     # by default so specify the NUL delimiter to consider the whole "line".
     ['suf-19', "-d '' --from=si '4.0 K'",         {OUT => "4000"}],

     ## GROUPING

     # "C" locale - no grouping (locale-specific tests, below)
     ['grp-1', '--from=si --grouping 7M',   {OUT=>'7000000'}],
     ['grp-2', '--from=si --to=si --grouping 7M',
              {ERR => "$prog: grouping cannot be combined with --to\n"},
              {EXIT => '1'}],


     ## Padding
     ['pad-1', '--padding=10 5',             {OUT=>'         5'}],
     ['pad-2', '--padding=-10 5',            {OUT=>'5         '}],
     ['pad-3', '--padding=A 5',
             {ERR => "$prog: invalid padding value 'A'\n"},
             {EXIT => '1'}],
     ['pad-3.1', '--padding=0 5',
             {ERR => "$prog: invalid padding value '0'\n"},
             {EXIT => '1'}],
     ['pad-4', '--padding=10 --to=si 50000',             {OUT=>'       50K'}],
     ['pad-5', '--padding=-10 --to=si 50000',            {OUT=>'50K       '}],

     # padding too narrow
     ['pad-6', '--padding=2 --to=si 1000', {OUT=>'1.0K'}],


     # Padding + suffix
     ['pad-7', '--padding=10 --suffix=foo --to=si 50000',
             {OUT=>'    50Kfoo'}],
     ['pad-8', '--padding=-10 --suffix=foo --to=si 50000',
             {OUT=>'50Kfoo    '}],


     # Delimiters
     ['delim-1', '--delimiter=: --from=auto 40M:',   {OUT=>'40000000:'}],
     ['delim-2', '--delimiter="" --from=auto "40 M"',{OUT=>'40000000'}],
     ['delim-3', '--delimiter=" " --from=auto "40M Foo"',{OUT=>'40000000 Foo'}],
     ['delim-4', '--delimiter=: --from=auto 40M:60M',  {OUT=>'40000000:60M'}],
     ['delim-5', '-d: --field=2 --from=auto :40M:60M',  {OUT=>':40000000:60M'}],
     ['delim-6', '-d: --field 3 --from=auto 40M:60M', {OUT=>"40M:60M"}],
     ['delim-err-1', '-d,, --to=si 1', {EXIT=>1},
             {ERR => "$prog: the delimiter must be a single character\n"}],

     #Fields
     ['field-1', '--field A',
             {ERR => "$prog: invalid field value 'A'\n$try"},
             {EXIT => '1'}],
     ['field-2', '--field 2 --from=auto "Hello 40M World 90G"',
             {OUT=>'Hello 40000000 World 90G'}],
     ['field-3', '--field 3 --from=auto "Hello 40M World 90G"',
             {OUT=>"Hello 40M "},
             {ERR=>"$prog: invalid number: 'World'\n"},
             {EXIT => 2},],
     # Last field - no text after number
     ['field-4', '--field 4 --from=auto "Hello 40M World 90G"',
             {OUT=>"Hello 40M World 90000000000"}],
     # Last field - a delimiter after the number
     ['field-5', '--field 4 --from=auto "Hello 40M World 90G "',
             {OUT=>"Hello 40M World 90000000000 "}],

     # Mix Fields + Delimiters
     ['field-6', '--delimiter=: --field 2 --from=auto "Hello:40M:World:90G"',
             {OUT=>"Hello:40000000:World:90G"}],

     # not enough fields
     ['field-8', '--field 3 --to=si "Hello World"', {OUT=>"Hello World"}],

     # Multiple fields
     ['field-range-1', '--field 2,4 --to=si "1000 2000 3000 4000 5000"',
             {OUT=>"1000 2.0K 3000 4.0K 5000"}],

     ['field-range-2', '--field 2-4 --to=si "1000 2000 3000 4000 5000"',
             {OUT=>"1000 2.0K 3.0K 4.0K 5000"}],

     ['field-range-3', '--field 1,2,3-5 --to=si "1000 2000 3000 4000 5000"',
             {OUT=>"1.0K 2.0K 3.0K 4.0K 5.0K"}],

     ['field-range-4', '--field 1-5 --to=si "1000 2000 3000 4000 5000"',
             {OUT=>"1.0K 2.0K 3.0K 4.0K 5.0K"}],

     ['field-range-5', '--field 1-3,5 --to=si "1000 2000 3000 4000 5000"',
             {OUT=>"1.0K 2.0K 3.0K 4000 5.0K"}],

     ['field-range-6', '--field 3- --to=si "1000 2000 3000 4000 5000"',
             {OUT=>"1000 2000 3.0K 4.0K 5.0K"}],

     ['field-range-7', '--field -3 --to=si "1000 2000 3000 4000 5000"',
             {OUT=>"1.0K 2.0K 3.0K 4000 5000"}],

     ['field-range-8', '--field 1-2,4-5 --to=si "1000 2000 3000 4000 5000"',
             {OUT=>"1.0K 2.0K 3000 4.0K 5.0K"}],
     ['field-range-9', '--field 4-5,1-2 --to=si "1000 2000 3000 4000 5000"',
             {OUT=>"1.0K 2.0K 3000 4.0K 5.0K"}],

     ['field-range-10','--field 1-3,2-4 --to=si "1000 2000 3000 4000 5000"',
             {OUT=>"1.0K 2.0K 3.0K 4.0K 5000"}],
     ['field-range-11','--field 2-4,1-3 --to=si "1000 2000 3000 4000 5000"',
             {OUT=>"1.0K 2.0K 3.0K 4.0K 5000"}],

     ['field-range-12','--field 1-1,3-3 --to=si "1000 2000 3000 4000 5000"',
             {OUT=>"1.0K 2000 3.0K 4000 5000"}],

     ['field-range-13', '--field 1,-2 --to=si "1000 2000 3000"',
             {OUT=>"1.0K 2.0K 3000"}],

     ['field-range-14', '--field -2,4- --to=si "1000 2000 3000 4000 5000"',
             {OUT=>"1.0K 2.0K 3000 4.0K 5.0K"}],
     ['field-range-15', '--field -2,-4 --to=si "1000 2000 3000 4000 5000"',
             {OUT=>"1.0K 2.0K 3.0K 4.0K 5000"}],
     ['field-range-16', '--field 2-,4- --to=si "1000 2000 3000 4000 5000"',
             {OUT=>"1000 2.0K 3.0K 4.0K 5.0K"}],
     ['field-range-17', '--field 4-,2- --to=si "1000 2000 3000 4000 5000"',
             {OUT=>"1000 2.0K 3.0K 4.0K 5.0K"}],

     # white space are valid field separators
     # (undocumented? but works in cut as well).
     ['field-range-18', '--field "1,2 4" --to=si "1000 2000 3000 4000 5000"',
             {OUT=>"1.0K 2.0K 3000 4.0K 5000"}],

     # Unlike 'cut', a lone '-' means 'all fields', even as part of a list
     # of fields.
     ['field-range-19','--field 3,- --to=si "1000 2000 3000 4000 5000"',
             {OUT=>"1.0K 2.0K 3.0K 4.0K 5.0K"}],

     ['all-fields-1', '--field=- --to=si "1000 2000 3000 4000 5000"',
             {OUT=>"1.0K 2.0K 3.0K 4.0K 5.0K"}],

     ['field-range-err-1', '--field -foo --to=si 10',
             {EXIT=>1}, {ERR=>"$prog: invalid field value 'foo'\n$try"}],
     ['field-range-err-2', '--field --3 --to=si 10',
             {EXIT=>1}, {ERR=>"$prog: invalid field range\n$try"}],
     ['field-range-err-3', '--field 0 --to=si 10',
             {EXIT=>1}, {ERR=>"$prog: fields are numbered from 1\n$try"}],
     ['field-range-err-4', '--field 3-2 --to=si 10',
             {EXIT=>1}, {ERR=>"$prog: invalid decreasing range\n$try"}],
     ['field-range-err-6', '--field - --field 1- --to=si 10',
             {EXIT=>1}, {ERR=>"$prog: multiple field specifications\n"}],
     ['field-range-err-7', '--field -1 --field 1- --to=si 10',
             {EXIT=>1}, {ERR=>"$prog: multiple field specifications\n"}],
     ['field-range-err-8', '--field -1 --field 1,2,3 --to=si 10',
             {EXIT=>1}, {ERR=>"$prog: multiple field specifications\n"}],
     ['field-range-err-9', '--field 1- --field 1,2,3 --to=si 10',
             {EXIT=>1}, {ERR=>"$prog: multiple field specifications\n"}],
     ['field-range-err-10','--field 1,2,3 --field 1- --to=si 10',
             {EXIT=>1}, {ERR=>"$prog: multiple field specifications\n"}],
     ['field-range-err-11','--field 1-2-3 --to=si 10',
             {EXIT=>1}, {ERR=>"$prog: invalid field range\n$try"}],
     ['field-range-err-12','--field 0-1 --to=si 10',
             {EXIT=>1}, {ERR=>"$prog: fields are numbered from 1\n$try"}],
     ['field-range-err-13','--field '.$limits->{SIZE_MAX}.',22 --to=si 10',
             {EXIT=>1}, {ERR=>"$prog: field number " .
                              "'".$limits->{SIZE_MAX}."' is too large\n$try"}],

     # Auto-consume white-space, setup auto-padding
     ['whitespace-1', '--to=si --field 2 "A    500 B"', {OUT=>"A    500 B"}],
     ['whitespace-2', '--to=si --field 2 "A   5000 B"', {OUT=>"A   5.0K B"}],
     ['whitespace-3', '--to=si "  500"', {OUT=>"  500"}],
     ['whitespace-4', '--to=si " 6500"', {OUT=>" 6.5K"}],
     # NOTE: auto-padding is not enabled if the value is on the first
     #       field and there's no white-space before it.
     ['whitespace-5', '--to=si "6000000"', {OUT=>"6.0M"}],
     # but if there is whitespace, assume auto-padding is desired.
     ['whitespace-6', '--to=si " 6000000"', {OUT=>"    6.0M"}],

     # auto-padding - lines have same padding-width
     #  (padding_buffer will be alloc'd just once)
     ['whitespace-7', '--to=si --field 2',
             {IN_PIPE=>"rootfs    100000\n" .
                       "udevxx   2000000\n"},
             {OUT    =>"rootfs      100K\n" .
                       "udevxx      2.0M"}],
     # auto-padding - second line requires a
     # larger padding (padding-buffer needs to be realloc'd)
     ['whitespace-8', '--to=si --field 2',
             {IN_PIPE=>"rootfs    100000\n" .
                       "udev         20000000\n"},
             {OUT    =>"rootfs      100K\n" .
                       "udev              20M"}],


     # Corner-cases:
     # weird mix of identical suffix,delimiters
     # The priority is:
     #   1. delimiters (and fields) are parsed (in process_line()
     #   2. optional custom suffix is removed (in process_suffixed_number())
     #   3. Remaining suffixes must be valid SI/IEC (in human_xstrtol())

     # custom suffix comes BEFORE SI/IEC suffix,
     #   so these are 40 of "M", not 40,000,000.
     ['mix-1', '--suffix=M --from=si 40M',     {OUT=>"40M"}],

     # These are forty-million Ms .
     ['mix-2', '--suffix=M --from=si 40MM',     {OUT=>"40000000M"}],

     ['mix-3', '--suffix=M --from=auto 40MM',     {OUT=>"40000000M"}],
     ['mix-4', '--suffix=M --from=auto 40MiM',     {OUT=>"41943040M"}],
     ['mix-5', '--suffix=M --to=si --from=si 4MM',     {OUT=>"4.0MM"}],

     # This might be confusing to the user, but it's legit:
     # The M in the output is the custom suffix, not Mega.
     ['mix-6', '--suffix=M 40',     {OUT=>"40M"}],
     ['mix-7', '--suffix=M 4000000',     {OUT=>"4000000M"}],
     ['mix-8', '--suffix=M --to=si 4000000',     {OUT=>"4.0MM"}],

     # The output 'M' is the custom suffix.
     ['mix-10', '--delimiter=M --suffix=M 40',     {OUT=>"40M"}],

     # The INPUT 'M' is a delimiter (delimiters are top priority)
     # The output contains one M for custom suffix, and one 'M' delimiter.
     ['mix-11', '--delimiter=M --suffix=M 40M',     {OUT=>"40MM"}],

     # Same as above, the "M" is NOT treated as a mega SI prefix,
     ['mix-12', '--delimiter=M --from=si --suffix=M 40M',     {OUT=>"40MM"}],

     # The 'M' is treated as a delimiter, and so the input value is '4000'
     ['mix-13', '--delimiter=M --to=si --from=auto 4000M5000M9000',
             {OUT=>"4.0KM5000M9000"}],
     # 'M' is the delimiter, so the second input field is '5000'
     ['mix-14', '--delimiter=M --field 2 --from=auto --to=si 4000M5000M9000',
             {OUT=>"4000M5.0KM9000"}],



     ## Header testing

     # header - silently ignored with command line parameters
     ['header-1', '--header --to=iec 4096', {OUT=>"4.0K"}],

     # header warning with --debug
     ['header-2', '--debug --header --to=iec 4096', {OUT=>"4.0K"},
             {ERR=>"$prog: --header ignored with command-line input\n"}],

     ['header-3', '--header=A',
             {ERR=>"$prog: invalid header value 'A'\n"},
             {EXIT => 1},],
     ['header-4', '--header=0',
             {ERR=>"$prog: invalid header value '0'\n"},
             {EXIT => 1},],
     ['header-5', '--header=-6',
             {ERR=>"$prog: invalid header value '-6'\n"},
             {EXIT => 1},],
     ['header-6', '--debug --header --to=iec',
             {IN_PIPE=>"size\n5000\n90000\n"},
             {OUT=>"size\n4.9K\n88K"}],
     ['header-7', '--debug --header=3 --to=iec',
             {IN_PIPE=>"hello\nworld\nsize\n5000\n90000\n"},
             {OUT=>"hello\nworld\nsize\n4.9K\n88K"}],
     # header, but no actual content
     ['header-8', '--header=2 --to=iec',
             {IN_PIPE=>"hello\nworld\n"},
             {OUT=>"hello\nworld"}],
     # not enough header lines
     ['header-9', '--header=3 --to=iec',
             {IN_PIPE=>"hello\nworld\n"},
             {OUT=>"hello\nworld"}],


     ## human_strtod testing

     # NO_DIGITS_FOUND
     ['strtod-1', '--from=si "foo"',
             {ERR=>"$prog: invalid number: 'foo'\n"},
             {EXIT=> 2}],
     ['strtod-2', '--from=si ""',
             {ERR=>"$prog: invalid number: ''\n"},
             {EXIT=> 2}],

     # FRACTION_NO_DIGITS_FOUND
     ['strtod-5', '--from=si 12.',
             {ERR=>"$prog: invalid number: '12.'\n"},
             {EXIT=>2}],
     ['strtod-6', '--from=si 12.K',
             {ERR=>"$prog: invalid number: '12.K'\n"},
             {EXIT=>2}],

     # whitespace is not allowed after decimal-point
     ['strtod-6.1', '--from=si --delimiter=, "12.  2"',
             {ERR=>"$prog: invalid number: '12.  2'\n"},
             {EXIT=>2}],

     # INVALID_SUFFIX
     ['strtod-9', '--from=si 12.2Q',
             {ERR=>"$prog: invalid suffix in input: '12.2Q'\n"},
             {EXIT=>2}],

     # VALID_BUT_FORBIDDEN_SUFFIX
     ['strtod-10', '12M',
             {ERR => "$prog: rejecting suffix " .
                     "in input: '12M' (consider using --from)\n"},
             {EXIT=>2}],

     # MISSING_I_SUFFIX
     ['strtod-11', '--from=iec-i 12M',
             {ERR => "$prog: missing 'i' suffix in input: " .
                     "'12M' (e.g Ki/Mi/Gi)\n"},
             {EXIT=>2}],

     #
     # Test double_to_human()
     #

     # 1K and smaller
     ['dbl-to-human-1','--to=si 800',  {OUT=>"800"}],
     ['dbl-to-human-2','--to=si 0',  {OUT=>"0"}],
     ['dbl-to-human-2.1','--to=si 999',  {OUT=>"999"}],
     ['dbl-to-human-2.2','--to=si 1000',  {OUT=>"1.0K"}],
     #NOTE: the following are consistent with "ls -lh" output
     ['dbl-to-human-2.3','--to=iec 999',  {OUT=>"999"}],
     ['dbl-to-human-2.4','--to=iec 1023',  {OUT=>"1023"}],
     ['dbl-to-human-2.5','--to=iec 1024',  {OUT=>"1.0K"}],
     ['dbl-to-human-2.6','--to=iec 1025',  {OUT=>"1.1K"}],
     ['dbl-to-human-2.7','--to=iec 0',  {OUT=>"0"}],
     # no "i" suffix if output has no suffix
     ['dbl-to-human-2.8','--to=iec-i 0',  {OUT=>"0"}],

     # values resulting in "N.Nx" output
     ['dbl-to-human-3','--to=si 8000', {OUT=>"8.0K"}],
     ['dbl-to-human-3.1','--to=si 8001', {OUT=>"8.1K"}],
     ['dbl-to-human-4','--to=si --round=down 8001', {OUT=>"8.0K"}],

     ['dbl-to-human-5','--to=si --round=down 3500', {OUT=>"3.5K"}],
     ['dbl-to-human-6','--to=si --round=nearest 3500', {OUT=>"3.5K"}],
     ['dbl-to-human-7','--to=si --round=up 3500', {OUT=>"3.5K"}],

     ['dbl-to-human-8','--to=si --round=down    3501', {OUT=>"3.5K"}],
     ['dbl-to-human-9','--to=si --round=nearest  3501', {OUT=>"3.5K"}],
     ['dbl-to-human-10','--to=si --round=up 3501', {OUT=>"3.6K"}],

     ['dbl-to-human-11','--to=si --round=nearest  3550', {OUT=>"3.6K"}],
     ['dbl-to-human-12','--to=si --from=si 999.89K', {OUT=>"1.0M"}],
     ['dbl-to-human-13','--to=si --from=si 9.9K', {OUT=>"9.9K"}],
     ['dbl-to-human-14','--to=si 9900', {OUT=>"9.9K"}],
     ['dbl-to-human-15','--to=iec --from=si 3.3K', {OUT=>"3.3K"}],
     ['dbl-to-human-16','--to=iec --round=down --from=si 3.3K', {OUT=>"3.2K"}],

     # values resulting in 'NNx' output
     ['dbl-to-human-17','--to=si 9999', {OUT=>"10K"}],
     ['dbl-to-human-18','--to=si --round=down 35000', {OUT=>"35K"}],
     ['dbl-to-human-19','--to=iec 35000', {OUT=>"35K"}],
     ['dbl-to-human-20','--to=iec --round=down 35000', {OUT=>"34K"}],
     ['dbl-to-human-21','--to=iec 35000000', {OUT=>"34M"}],
     ['dbl-to-human-22','--to=iec --round=down 35000000', {OUT=>"33M"}],
     ['dbl-to-human-23','--to=si  35000001', {OUT=>"36M"}],
     ['dbl-to-human-24','--to=si --from=si  9.99M', {OUT=>"10M"}],
     ['dbl-to-human-25','--to=si --from=iec 9.99M', {OUT=>"11M"}],
     ['dbl-to-human-25.1','--to=iec 99999', {OUT=>"98K"}],

     # values resulting in 'NNNx' output
     ['dbl-to-human-26','--to=si 999000000000', {OUT=>"999G"}],
     ['dbl-to-human-27','--to=iec 999000000000', {OUT=>"931G"}],
     ['dbl-to-human-28','--to=si 123600000000000', {OUT=>"124T"}],
     ['dbl-to-human-29','--to=si 998123', {OUT=>"999K"}],
     ['dbl-to-human-30','--to=si --round=nearest 998123', {OUT=>"998K"}],
     ['dbl-to-human-31','--to=si 99999', {OUT=>"100K"}],
     ['dbl-to-human-32','--to=iec 102399', {OUT=>"100K"}],
     ['dbl-to-human-33','--to=iec-i 102399', {OUT=>"100Ki"}],


     # Default --round=from-zero
     ['round-1','--to-unit=1024 -- 6000 -6000',
             {OUT=>"6\n-6"}],
     ['round-2','--to-unit=1024 -- 6000.0 -6000.0',
             {OUT=>"5.9\n-5.9"}],
     ['round-3','--to-unit=1024 -- 6000.00 -6000.00',
             {OUT=>"5.86\n-5.86"}],
     ['round-4','--to-unit=1024 -- 6000.000 -6000.000',
             {OUT=>"5.860\n-5.860"}],
     ['round-5','--to-unit=1024 -- 6000.0000 -6000.0000',
             {OUT=>"5.8594\n-5.8594"}],
     # --round=up
     ['round-1-up','--round=up --to-unit=1024 -- 6000 -6000',
             {OUT=>"6\n-5"}],
     ['round-2-up','--round=up --to-unit=1024 -- 6000.0 -6000.0',
             {OUT=>"5.9\n-5.8"}],
     ['round-3-up','--round=up --to-unit=1024 -- 6000.00 -6000.00',
             {OUT=>"5.86\n-5.85"}],
     ['round-4-up','--round=up --to-unit=1024 -- 6000.000 -6000.000',
             {OUT=>"5.860\n-5.859"}],
     ['round-5-up','--round=up --to-unit=1024 -- 6000.0000 -6000.0000',
             {OUT=>"5.8594\n-5.8593"}],
     # --round=down
     ['round-1-down','--round=down --to-unit=1024 -- 6000 -6000',
             {OUT=>"5\n-6"}],
     ['round-2-down','--round=down --to-unit=1024 -- 6000.0 -6000.0',
             {OUT=>"5.8\n-5.9"}],
     ['round-3-down','--round=down --to-unit=1024 -- 6000.00 -6000.00',
             {OUT=>"5.85\n-5.86"}],
     ['round-4-down','--round=down --to-unit=1024 -- 6000.000 -6000.000',
             {OUT=>"5.859\n-5.860"}],
     ['round-5-down','--round=down --to-unit=1024 -- 6000.0000 -6000.0000',
             {OUT=>"5.8593\n-5.8594"}],
     # --round=towards-zero
     ['round-1-to-zero','--ro=towards-zero --to-u=1024 -- 6000 -6000',
             {OUT=>"5\n-5"}],
     ['round-2-to-zero','--ro=towards-zero --to-u=1024 -- 6000.0 -6000.0',
             {OUT=>"5.8\n-5.8"}],
     ['round-3-to-zero','--ro=towards-zero --to-u=1024 -- 6000.00 -6000.00',
             {OUT=>"5.85\n-5.85"}],
     ['round-4-to-zero','--ro=towards-zero --to-u=1024 -- 6000.000 -6000.000',
             {OUT=>"5.859\n-5.859"}],
     ['round-5-to-zero','--ro=towards-zero --to-u=1024 -- 6000.0000 -6000.0000',
             {OUT=>"5.8593\n-5.8593"}],
     # --round=nearest
     ['round-1-near','--ro=nearest --to-u=1024 -- 6000 -6000',
             {OUT=>"6\n-6"}],
     ['round-2-near','--ro=nearest --to-u=1024 -- 6000.0 -6000.0',
             {OUT=>"5.9\n-5.9"}],
     ['round-3-near','--ro=nearest --to-u=1024 -- 6000.00 -6000.00',
             {OUT=>"5.86\n-5.86"}],
     ['round-4-near','--ro=nearest --to-u=1024 -- 6000.000 -6000.000',
             {OUT=>"5.859\n-5.859"}],
     ['round-5-near','--ro=nearest --to-u=1024 -- 6000.0000 -6000.0000',
             {OUT=>"5.8594\n-5.8594"}],


     # Leading zeros weren't handled appropriately before 8.24
     ['leading-1','0000000000000000000000000001', {OUT=>"1"}],
     ['leading-2','.1', {OUT=>"0.1"}],
     ['leading-3','bad.1',
             {ERR => "$prog: invalid number: 'bad.1'\n"},
             {EXIT => 2}],
     ['leading-4','..1',
             {ERR => "$prog: invalid suffix in input: '..1'\n"},
             {EXIT => 2}],
     ['leading-5','1.',
             {ERR => "$prog: invalid number: '1.'\n"},
             {EXIT => 2}],

     # precision override
     ['precision-1','--format=%.4f 9991239123 --to=si', {OUT=>"9.9913G"}],
     ['precision-2','--format=%.1f 9991239123 --to=si', {OUT=>"10.0G"}],
     ['precision-3','--format=%.1f 1', {OUT=>"1.0"}],
     ['precision-4','--format=%.1f 1.12', {OUT=>"1.2"}],
     ['precision-5','--format=%.1f 9991239123 --to-unit=G', {OUT=>"10.0"}],
     ['precision-6','--format="% .1f" 9991239123 --to-unit=G', {OUT=>"10.0"}],
     ['precision-7','--format=%.-1f 1.1',
             {ERR => "$prog: invalid precision in format '%.-1f'\n"},
             {EXIT => 1}],
     ['precision-8','--format=%.+1f 1.1',
             {ERR => "$prog: invalid precision in format '%.+1f'\n"},
             {EXIT => 1}],
     ['precision-9','--format="%. 1f" 1.1',
             {ERR => "$prog: invalid precision in format '%. 1f'\n"},
             {EXIT => 1}],

     # debug warnings
     ['debug-1', '--debug 4096', {OUT=>"4096"},
             {ERR=>"$prog: no conversion option specified\n"}],
     # '--padding' is a valid conversion option - no warning should be printed
     ['debug-1.1', '--debug --padding 10 4096', {OUT=>"      4096"}],
     ['debug-2', '--debug --grouping --from=si 4.0K', {OUT=>"4000"},
             {ERR=>"$prog: grouping has no effect in this locale\n"}],

     # dev-debug messages - the actual messages don't matter
     # just ensure the program works, and for code coverage testing.
     ['devdebug-1', '---debug --from=si 4.9K', {OUT=>"4900"},
             {ERR=>""},
             {ERR_SUBST=>"s/.*//msg"}],
     ['devdebug-2', '---debug 4900', {OUT=>"4900"},
             {ERR=>""},
             {ERR_SUBST=>"s/.*//msg"}],
     ['devdebug-3', '---debug --from=auto 4Mi', {OUT=>"4194304"},
             {ERR=>""},
             {ERR_SUBST=>"s/.*//msg"}],
     ['devdebug-4', '---debug --to=si 4000000', {OUT=>"4.0M"},
             {ERR=>""},
             {ERR_SUBST=>"s/.*//msg"}],
     ['devdebug-5', '---debug --to=si --padding=5 4000000', {OUT=>" 4.0M"},
             {ERR=>""},
             {ERR_SUBST=>"s/.*//msg"}],
     ['devdebug-6', '---debug --suffix=Foo 1234Foo', {OUT=>"1234Foo"},
             {ERR=>""},
             {ERR_SUBST=>"s/.*//msg"}],
     ['devdebug-7', '---debug --suffix=Foo 1234', {OUT=>"1234Foo"},
             {ERR=>""},
             {ERR_SUBST=>"s/.*//msg"}],
     ['devdebug-9', '---debug --grouping 10000', {OUT=>"10000"},
             {ERR=>""},
             {ERR_SUBST=>"s/.*//msg"}],
     ['devdebug-10', '---debug --format %f 10000', {OUT=>"10000"},
             {ERR=>""},
             {ERR_SUBST=>"s/.*//msg"}],
     ['devdebug-11', '---debug --format "%\'-10f" 10000',{OUT=>"10000     "},
             {ERR=>""},
             {ERR_SUBST=>"s/.*//msg"}],

     # Invalid parameters
     ['help-1', '--foobar',
             {ERR=>"$prog: unrecognized option\n$try"},
             {ERR_SUBST=>"s/option.*/option/; s/unknown/unrecognized/"},
             {EXIT=>1}],

     ## Format string - check error detection
     ['fmt-err-1', '--format ""',
             {ERR=>"$prog: format '' has no % directive\n"},
             {EXIT=>1}],
     ['fmt-err-2', '--format "hello"',
             {ERR=>"$prog: format 'hello' has no % directive\n"},
             {EXIT=>1}],
     ['fmt-err-3', '--format "hello%"',
             {ERR=>"$prog: format 'hello%' ends in %\n"},
             {EXIT=>1}],
     ['fmt-err-4', '--format "%d"',
             {ERR=>"$prog: invalid format '%d', " .
                   "directive must be %[0]['][-][N][.][N]f\n"},
             {EXIT=>1}],
     ['fmt-err-5', '--format "% -43 f"',
             {ERR=>"$prog: invalid format '% -43 f', " .
                   "directive must be %[0]['][-][N][.][N]f\n"},
             {EXIT=>1}],
     ['fmt-err-6', '--format "%f %f"',
             {ERR=>"$prog: format '%f %f' has too many % directives\n"},
             {EXIT=>1}],
     ['fmt-err-7', '--format "%'.$limits->{LONG_OFLOW}.'f"',
             {ERR=>"$prog: invalid format '%$limits->{LONG_OFLOW}f'".
                   " (width overflow)\n"},
             {EXIT=>1}],
     ['fmt-err-9', '--format "%f" --grouping',
             {ERR=>"$prog: --grouping cannot be combined with --format\n"},
             {EXIT=>1}],
     ['fmt-err-10', '--format "%\'f" --to=si',
             {ERR=>"$prog: grouping cannot be combined with --to\n"},
             {EXIT=>1}],
     ['fmt-err-11', '--debug --format "%\'f" 5000', {OUT=>"5000"},
             {ERR=>"$prog: grouping has no effect in this locale\n"}],

     ## Format string - check some corner cases
     ['fmt-1', '--format "%% %f" 5000', {OUT=>"%%5000"}],
     ['fmt-2', '--format "%f %%" 5000', {OUT=>"5000 %%"}],

     ['fmt-3', '--format "--%f--" 5000000', {OUT=>"--5000000--"}],
     ['fmt-4', '--format "--%f--" --to=si 5000000', {OUT=>"--5.0M--"}],

     ['fmt-5', '--format "--%10f--" --to=si 5000000',{OUT=>"--      5.0M--"}],
     ['fmt-6', '--format "--%-10f--" --to=si 5000000',{OUT=>"--5.0M      --"}],
     ['fmt-7', '--format "--%10f--" 5000000',{OUT=>"--   5000000--"}],
     ['fmt-8', '--format "--%-10f--" 5000000',{OUT=>"--5000000   --"}],

     # too-short width
     ['fmt-9', '--format "--%5f--" 5000000',{OUT=>"--5000000--"}],

     # Format + Suffix
     ['fmt-10', '--format "--%10f--" --suffix Foo 50', {OUT=>"--     50Foo--"}],
     ['fmt-11', '--format "--%-10f--" --suffix Foo 50',{OUT=>"--50Foo     --"}],

     # Grouping in C locale - no grouping effect
     ['fmt-12', '--format "%\'f" 50000',{OUT=>"50000"}],
     ['fmt-13', '--format "%\'10f" 50000', {OUT=>"     50000"}],
     ['fmt-14', '--format "%\'-10f" 50000',{OUT=>"50000     "}],

     # Very large format strings
     ['fmt-15', '--format "--%100000f--" --to=si 4200',
                  {OUT=>"--" . " " x 99996 . "4.2K--" }],

     # --format padding overrides --padding
     ['fmt-16', '--format="%6f" --padding=66 1234',{OUT=>"  1234"}],

     # zero padding
     ['fmt-17', '--format="%06f" 1234',{OUT=>"001234"}],
     # also support spaces (which are ignored as spacing is handled separately)
     ['fmt-18', '--format="%0 6f" 1234',{OUT=>"001234"}],
     # handle generic padding in combination
     ['fmt-22', '--format="%06f" --padding=7 1234',{OUT=>" 001234"}],
     ['fmt-23', '--format="%06f" --padding=-7 1234',{OUT=>"001234 "}],


     ## Check all errors again, this time with --invalid=fail
     ##  Input will be printed without conversion,
     ##  and exit code will be 2
     ['ign-err-1', '--invalid=fail 4Q',
             {ERR => "$prog: invalid suffix in input: '4Q'\n"},
             {OUT => "4Q\n"},
             {EXIT => 2}],
     ['ign-err-2', '--invalid=fail 4M',
             {ERR => "$prog: rejecting suffix " .
             "in input: '4M' (consider using --from)\n"},
             {OUT => "4M\n"},
             {EXIT => 2}],
     ['ign-err-3', '--invalid=fail --from=si 4MQ',
             {ERR => "$prog: invalid suffix in input '4MQ': 'Q'\n"},
             {OUT => "4MQ\n"},
             {EXIT => 2}],
     ['ign-err-4', '--invalid=fail --suffix=Foo --to=si   7000FooF',
              {ERR => "$prog: invalid suffix in input: '7000FooF'\n"},
              {OUT => "7000FooF\n"},
              {EXIT => 2}],
     ['ign-err-5','--invalid=fail --field 3 --from=auto "Hello 40M World 90G"',
             {ERR => "$prog: invalid number: 'World'\n"},
             {OUT => "Hello 40M World 90G\n"},
             {EXIT => 2}],
     ['ign-err-7', '--invalid=fail --from=si "foo"',
             {ERR => "$prog: invalid number: 'foo'\n"},
             {OUT => "foo\n"},
             {EXIT=> 2}],
     ['ign-err-8', '--invalid=fail 12M',
             {ERR => "$prog: rejecting suffix " .
                     "in input: '12M' (consider using --from)\n"},
             {OUT => "12M\n"},
             {EXIT => 2}],
     ['ign-err-9', '--invalid=fail --from=iec-i 12M',
             {ERR => "$prog: missing 'i' suffix in input: " .
                     "'12M' (e.g Ki/Mi/Gi)\n"},
             {OUT => "12M\n"},
             {EXIT=>2}],

     ## Ignore Errors with multiple conversions
     ['ign-err-m1', '--invalid=ignore --to=si 1000 2000 bad 3000',
             {OUT => "1.0K\n2.0K\nbad\n3.0K"},
             {EXIT => 0}],
     ['ign-err-m1.1', '--invalid=ignore --to=si',
             {IN_PIPE => "1000\n2000\nbad\n3000\n"},
             {OUT => "1.0K\n2.0K\nbad\n3.0K"},
             {EXIT => 0}],
     ['ign-err-m1.3', '--invalid=fail --debug --to=si 1000 2000 3000',
             {OUT => "1.0K\n2.0K\n3.0K"},
             {EXIT => 0}],
     ['ign-err-m2', '--invalid=fail --to=si 1000 Foo 3000',
             {OUT => "1.0K\nFoo\n3.0K\n"},
             {ERR => "$prog: invalid number: 'Foo'\n"},
             {EXIT => 2}],
     ['ign-err-m2.1', '--invalid=warn --to=si',
             {IN_PIPE => "1000\nFoo\n3000\n"},
             {OUT => "1.0K\nFoo\n3.0K"},
             {ERR => "$prog: invalid number: 'Foo'\n"},
             {EXIT => 0}],

     # --debug will trigger a final warning at EOF
     ['ign-err-m2.2', '--invalid=fail --debug --to=si 1000 Foo 3000',
             {OUT => "1.0K\nFoo\n3.0K\n"},
             {ERR => "$prog: invalid number: 'Foo'\n" .
                     "$prog: failed to convert some of the input numbers\n"},
             {EXIT => 2}],

     ['ign-err-m3', '--invalid=fail --field 2 --from=si --to=iec',
             {IN_PIPE => "A 1K x\nB 2M y\nC 3G z\n"},
             {OUT => "A 1000 x\nB 2.0M y\nC 2.8G z"},
             {EXIT => 0}],
     # invalid input on one of the fields
     ['ign-err-m3.1', '--invalid=fail --field 2 --from=si --to=iec',
             {IN_PIPE => "A 1K x\nB Foo y\nC 3G z\n"},
             {OUT => "A 1000 x\nB Foo y\nC 2.8G z\n"},
             {ERR => "$prog: invalid number: 'Foo'\n"},
             {EXIT => 2}],
    );

# test null-terminated lines
my @NullDelim_Tests =
  (
     # Input from STDIN
     ['z1', '-z --to=iec',
             {IN_PIPE => "1025\x002048\x00"}, {OUT=>"1.1K\x002.0K\x00"}],

     # Input from the commandline - terminated by NULL vs NL
     ['z3', '   --to=iec 1024',  {OUT=>"1.0K\n"}],
     ['z2', '-z --to=iec 1024',  {OUT=>"1.0K\x00"}],

     # Input from STDIN, with fields
     ['z4', '-z --field=3 --to=si',
             {IN_PIPE => "A B 1001 C\x00" .
                         "D E 2002 F\x00"},
             {OUT => "A B 1.1K C\x00" .
                     "D E 2.1K F\x00"}],

     # Input from STDIN, with fields and embedded NL
     ['z5', '-z --field=3 --to=si',
             {IN_PIPE => "A\nB 1001 C\x00" .
                         "D E\n2002 F\x00"},
             {OUT => "A B 1.1K C\x00" .
                     "D E 2.1K F\x00"}],
  );

my @Limit_Tests =
  (
     # Large Values
     ['large-1','1000000000000000', {OUT=>"1000000000000000"}],
     # 18 digits is OK
     ['large-2','1000000000000000000', {OUT=>"1000000000000000000"}],
     # 19 digits is too much (without output scaling)
     ['large-3','10000000000000000000',
             {ERR => "$prog: value too large to be printed: '1e+19' " .
                     "(consider using --to)\n"},
             {EXIT=>2}],
     ['large-4','1000000000000000000.0',
             {ERR => "$prog: value/precision too large to be printed: " .
                     "'1e+18/1' (consider using --to)\n"},
             {EXIT=>2}],


     # Test input:
     # Up to 27 digits is OK.
     ['large-3.1', '--to=si                           1', {OUT=>   "1"}],
     ['large-3.2', '--to=si                          10', {OUT=>  "10"}],
     ['large-3.3', '--to=si                         100', {OUT=> "100"}],
     ['large-3.4', '--to=si                        1000', {OUT=>"1.0K"}],
     ['large-3.5', '--to=si                       10000', {OUT=> "10K"}],
     ['large-3.6', '--to=si                      100000', {OUT=>"100K"}],
     ['large-3.7', '--to=si                     1000000', {OUT=>"1.0M"}],
     ['large-3.8', '--to=si                    10000000', {OUT=> "10M"}],
     ['large-3.9', '--to=si                   100000000', {OUT=>"100M"}],
     ['large-3.10','--to=si                  1000000000', {OUT=>"1.0G"}],
     ['large-3.11','--to=si                 10000000000', {OUT=> "10G"}],
     ['large-3.12','--to=si                100000000000', {OUT=>"100G"}],
     ['large-3.13','--to=si               1000000000000', {OUT=>"1.0T"}],
     ['large-3.14','--to=si              10000000000000', {OUT=> "10T"}],
     ['large-3.15','--to=si             100000000000000', {OUT=>"100T"}],
     ['large-3.16','--to=si            1000000000000000', {OUT=>"1.0P"}],
     ['large-3.17','--to=si           10000000000000000', {OUT=> "10P"}],
     ['large-3.18','--to=si          100000000000000000', {OUT=>"100P"}],
     ['large-3.19','--to=si         1000000000000000000', {OUT=>"1.0E"}],
     ['large-3.20','--to=si        10000000000000000000', {OUT=> "10E"}],
     ['large-3.21','--to=si       210000000000000000000', {OUT=>"210E"}],
     ['large-3.22','--to=si      3210000000000000000000', {OUT=>"3.3Z"}],
     ['large-3.23','--to=si     43210000000000000000000', {OUT=> "44Z"}],
     ['large-3.24','--to=si    543210000000000000000000', {OUT=>"544Z"}],
     ['large-3.25','--to=si   6543210000000000000000000', {OUT=>"6.6Y"}],
     ['large-3.26','--to=si  76543210000000000000000000', {OUT=> "77Y"}],
     ['large-3.27','--to=si 876543210000000000000000000', {OUT=>"877Y"}],

     # More than 27 digits is not OK
     ['large-3.28','--to=si 9876543210000000000000000000',
             {ERR => "$prog: value too large to be converted: " .
                     "'9876543210000000000000000000'\n"},
             {EXIT => 2}],

     # Test Output
     ['large-4.1', '--from=si  9.7M',               {OUT=>"9700000"}],
     ['large-4.2', '--from=si  10M',              {OUT =>"10000000"}],
     ['large-4.3', '--from=si  200M',            {OUT =>"200000000"}],
     ['large-4.4', '--from=si  3G',             {OUT =>"3000000000"}],
     ['large-4.5', '--from=si  40G',           {OUT =>"40000000000"}],
     ['large-4.6', '--from=si  500G',         {OUT =>"500000000000"}],
     ['large-4.7', '--from=si  6T',          {OUT =>"6000000000000"}],
     ['large-4.8', '--from=si  70T',        {OUT =>"70000000000000"}],
     ['large-4.9', '--from=si  800T',      {OUT =>"800000000000000"}],
     ['large-4.10','--from=si  9P',       {OUT =>"9000000000000000"}],
     ['large-4.11','--from=si  10P',     {OUT =>"10000000000000000"}],
     ['large-4.12','--from=si  200P',   {OUT =>"200000000000000000"}],
     ['large-4.13','--from=si  3E',    {OUT =>"3000000000000000000"}],

     # More than 18 digits of output without scaling - no good.
     ['large-4.14','--from=si  40E',
             {ERR => "$prog: value too large to be printed: '4e+19' " .
                     "(consider using --to)\n"},
             {EXIT => 2}],
     ['large-4.15','--from=si  500E',
             {ERR => "$prog: value too large to be printed: '5e+20' " .
                     "(consider using --to)\n"},
             {EXIT => 2}],
     ['large-4.16','--from=si  6Z',
             {ERR => "$prog: value too large to be printed: '6e+21' " .
                     "(consider using --to)\n"},
             {EXIT => 2}],
     ['large-4.17','--from=si  70Z',
             {ERR => "$prog: value too large to be printed: '7e+22' " .
                     "(consider using --to)\n"},
             {EXIT => 2}],
     ['large-4.18','--from=si  800Z',
             {ERR => "$prog: value too large to be printed: '8e+23' " .
                     "(consider using --to)\n"},
             {EXIT => 2}],
     ['large-4.19','--from=si  9Y',
             {ERR => "$prog: value too large to be printed: '9e+24' " .
                     "(consider using --to)\n"},
             {EXIT => 2}],
     ['large-4.20','--from=si  10Y',
             {ERR => "$prog: value too large to be printed: '1e+25' " .
                     "(consider using --to)\n"},
             {EXIT => 2}],
     ['large-4.21','--from=si  200Y',
             {ERR => "$prog: value too large to be printed: '2e+26' " .
                     "(consider using --to)\n"},
             {EXIT => 2}],

     ['large-5.1','--to=si 1000000000000000000', {OUT=>"1.0E"}],
     ['large-5','--from=si --to=si 2E', {OUT=>"2.0E"}],
     ['large-6','--from=si --to=si 3.4Z', {OUT=>"3.4Z"}],
     ['large-7','--from=si --to=si 80Y', {OUT=>"80Y"}],
     ['large-8','--from=si --to=si 9000Z', {OUT=>"9.0Y"}],

     ['large-10','--from=si --to=si 999Y', {OUT=>"999Y"}],
     ['large-11','--from=si --to=iec 999Y', {OUT=>"827Y"}],
     ['large-12','--from=si --round=down --to=iec 999Y', {OUT=>"826Y"}],

     # units can also affect the output
     ['large-13','--from=si --from-unit=1000000 9P',
             {ERR => "$prog: value too large to be printed: '9e+21' " .
                     "(consider using --to)\n"},
             {EXIT => 2}],
     ['large-13.1','--from=si --from-unit=1000000 --to=si 9P', {OUT=>"9.0Z"}],

     # Numbers>999Y are never acceptable, regardless of scaling
     ['large-14','--from=si --to=si 999Y', {OUT=>"999Y"}],
     ['large-14.1','--from=si --to=si 1000Y',
             {ERR => "$prog: value too large to be printed: '1e+27' " .
                     "(cannot handle values > 999Y)\n"},
             {EXIT => 2}],
     ['large-14.2','--from=si --to=si --from-unit=10000 1Y',
             {ERR => "$prog: value too large to be printed: '1e+28' " .
                     "(cannot handle values > 999Y)\n"},
             {EXIT => 2}],

     # intmax_t overflow when rounding caused this to fail before 8.24
     ['large-15',$limits->{INTMAX_OFLOW}, {OUT=>$limits->{INTMAX_OFLOW}}],
     ['large-16','9.300000000000000000', {OUT=>'9.300000000000000000'}],

     # INTEGRAL_OVERFLOW
     ['strtod-3', '--from=si "1234567890123456789012345678901234567890'.
                  '1234567890123456789012345678901234567890"',
             {ERR=>"$prog: value too large to be converted: '" .
                     "1234567890123456789012345678901234567890" .
                     "1234567890123456789012345678901234567890'\n",
                     },
             {EXIT=> 2}],

     # FRACTION_OVERFLOW
     ['strtod-7', '--from=si "12.1234567890123456789012345678901234567890'.
                  '1234567890123456789012345678901234567890"',
             {ERR=>"$prog: value too large to be converted: '" .
                     "12.1234567890123456789012345678901234567890" .
                     "1234567890123456789012345678901234567890'\n",
                     },
             {EXIT=> 2}],

     ['debug-4', '--to=si --debug 12345678901234567890',
             {OUT=>"13E"},
             {ERR=>"$prog: large input value '12345678901234567890':" .
                   " possible precision loss\n"}],
     ['debug-5', '--to=si --from=si --debug 1.12345678901234567890Y',
             {OUT=>"1.2Y"},
             {ERR=>"$prog: large input value '1.12345678901234567890Y':" .
                   " possible precision loss\n"}],

     ['ign-err-10','--invalid=fail 10000000000000000000',
             {ERR => "$prog: value too large to be printed: '1e+19' " .
                     "(consider using --to)\n"},
             {OUT => "10000000000000000000\n"},
             {EXIT=>2}],
     ['ign-err-11','--invalid=fail --to=si 9876543210000000000000000000',
             {ERR => "$prog: value too large to be converted: " .
                     "'9876543210000000000000000000'\n"},
             {OUT => "9876543210000000000000000000\n"},
             {EXIT => 2}],
  );
# Restrict these tests to systems with LDBL_DIG == 18
(system "$prog ---debug 1 2>&1|grep 'MAX_UNSCALED_DIGITS: 18' > /dev/null") == 0
  and push @Tests, @Limit_Tests;

my @Locale_Tests =
  (
     # Locale that supports grouping, but without '--grouping' parameter
     ['lcl-grp-1', '--from=si 7M',   {OUT=>"7000000"},
             {ENV=>"LC_ALL=$locale"}],

     # Locale with grouping
     ['lcl-grp-2', '--from=si --grouping 7M',   {OUT=>"7 000 000"},
             {ENV=>"LC_ALL=$locale"}],

     # Locale with grouping and debug - no debug warning message
     ['lcl-grp-3', '--from=si --debug --grouping 7M',   {OUT=>"7 000 000"},
             {ENV=>"LC_ALL=$locale"}],

     # Input with locale'd decimal-point
     ['lcl-stdtod-1', '--from=si 12,2K', {OUT=>"12200"},
             {ENV=>"LC_ALL=$locale"}],

     ['lcl-dbl-to-human-1', '--to=si 1100', {OUT=>"1,1K"},
             {ENV=>"LC_ALL=$locale"}],

     # Format + Grouping
     ['lcl-fmt-1', '--format "%\'f" 50000',{OUT=>"50 000"},
             {ENV=>"LC_ALL=$locale"}],
     ['lcl-fmt-2', '--format "--%\'10f--" 50000', {OUT=>"--    50 000--"},
             {ENV=>"LC_ALL=$locale"}],
     ['lcl-fmt-3', '--format "--%\'-10f--" 50000',{OUT=>"--50 000    --"},
             {ENV=>"LC_ALL=$locale"}],
     ['lcl-fmt-4', '--format "--%-10f--" --to=si 5000000',
             {OUT=>"--5,0M      --"},
             {ENV=>"LC_ALL=$locale"}],
     # handle zero/grouping in combination
     ['lcl-fmt-5', '--format="%\'06f" 1234',{OUT=>"01 234"},
             {ENV=>"LC_ALL=$locale"}],
     ['lcl-fmt-6', '--format="%0\'6f" 1234',{OUT=>"01 234"},
             {ENV=>"LC_ALL=$locale"}],
     ['lcl-fmt-7', '--format="%0\'\'6f" 1234',{OUT=>"01 234"},
             {ENV=>"LC_ALL=$locale"}],

  );
if ($locale ne 'C')
  {
    # Reset locale to 'C' if LOCALE_FR_UTF8 doesn't output as expected
    # as determined by the separate printf program.
    open(LOC_NUM, "env LC_ALL=$locale printf \"%'d\" 1234|")
      or die "Can't fork command: $!";
    my $loc_num = <LOC_NUM>;
    close(LOC_NUM) || die "Failed to read grouped number from printf";
    if ($loc_num ne '1 234')
      {
        warn "skipping locale grouping tests as 1234 groups like $loc_num\n";
        $locale = 'C';
      }
  }
push @Tests, @Locale_Tests if $locale ne 'C';

## Check all valid/invalid suffixes
foreach my $suf ( 'A' .. 'Z', 'a' .. 'z' ) {
  if ( $suf =~ /^[KMGTPEZY]$/ )
    {
      push @Tests, ["auto-suf-si-$suf","--from=si --to=si 1$suf",
              {OUT=>"1.0$suf"}];
      push @Tests, ["auto-suf-iec-$suf","--from=iec --to=iec 1$suf",
              {OUT=>"1.0$suf"}];
      push @Tests, ["auto-suf-auto-$suf","--from=auto --to=iec 1${suf}i",
              {OUT=>"1.0$suf"}];
      push @Tests, ["auto-suf-iec-to-ieci-$suf","--from=iec --to=iec-i 1${suf}",
              {OUT=>"1.0${suf}i"}];
      push @Tests, ["auto-suf-ieci-to-iec-$suf",
              "--from=iec-i --to=iec 1${suf}i",{OUT=>"1.0${suf}"}];
    }
  else
    {
      push @Tests, ["auto-suf-si-$suf","--from=si --to=si 1$suf",
              {ERR=>"$prog: invalid suffix in input: '1${suf}'\n"},
              {EXIT=>2}];
    }
}

# Prepend the command line argument and append a newline to end
# of each expected 'OUT' string.
my $t;

Test:
foreach $t (@Tests)
  {
    # Don't fiddle with expected OUT string if there's a nonzero exit status.
    foreach my $e (@$t)
      {
        ref $e eq 'HASH' && exists $e->{EXIT} && $e->{EXIT}
          and next Test;
      }

    foreach my $e (@$t)
      {
        ref $e eq 'HASH' && exists $e->{OUT}
          and $e->{OUT} .= "\n"
      }
  }

# Add test for null-terminated lines (after adjusting the OUT string, above).
push @Tests, @NullDelim_Tests;

my $save_temps = $ENV{SAVE_TEMPS};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($program_name, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
