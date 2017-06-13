#!/usr/bin/perl
# Test "stat --printf".

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

(my $ME = $0) =~ s|.*/||;
my $prog = 'stat';

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my @Tests =
    (
     # test-name, [option, option, ...] {OUT=>"expected-output"}
     #
     ['nl', q!--printf='\n' .!,          {OUT=>"\n"}],
     ['no-nl', "--printf=%n .",          {OUT=>"."}],
     ['pct-and-esc', q!--printf='\0%n\0' .!,    {OUT=>"\0.\0"}],
     ['backslash', q!--printf='\\\\' .!, {OUT=>"\\"}],
     ['nul', q!--printf='\0' .!,         {OUT=>"\0"}],
     # Don't bother testing \v, since Perl doesn't handle it.
     ['bel-etc', q!--printf='\a\b\f\n\r\t' .!, {OUT=>"\a\b\f\n\r\t"}],
     ['octal-1', q!--printf='\012\377' .!,     {OUT=>"\012\377"}],
     ['octal-2', q!--printf='.\012a\377b' .!,  {OUT=>".\012a\377b"}],
     ['hex-1',   q!--printf='\x34\xf' .!,      {OUT=>"\x34\xf"}],
     ['hex-2',   q!--printf='.\x18p\xfq' .!,   {OUT=>".\x18p\x0fq"}],
     ['hex-3',   q!--printf='\x' .!,           {OUT=>'x'},
         {ERR=>"$prog: warning: unrecognized escape '\\x'\n"}],

     # With --format, there *is* a trailing newline.
     ['f-nl', "--format=%n .",          {OUT=>".\n"}],
     ['f-nl2', "--format=%n . .",       {OUT=>".\n.\n"}],

     ['end-pct', "--printf=% .",       {OUT=>"%"}],
     ['pct-pct', "--printf=%% .",      {OUT=>"%"}],
     ['end-bs',  "--printf='\\' .",    {OUT=>'\\'},
         {ERR=>"$prog: warning: backslash at end of format\n"}],

     ['err-1', "--printf=%9% .",       {EXIT => 1},
         {ERR=>"$prog: '%9%': invalid directive\n"}],
     ['err-2', "--printf=%9 .",        {EXIT => 1},
         {ERR=>"$prog: '%9': invalid directive\n"}],
    );

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($ME, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
