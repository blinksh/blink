#!/usr/bin/perl
# Test pr.

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

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my $prog = 'pr';
my $normalize_strerror = "s/': .*/'/";

my @tv = (

# -b option is no longer an official option. But it's still working to
# get a downward compatibility. Now (version 1.19m or newer) -COLUMN
# only is equivalent to -b -COLUMN.
#
# test_name options input-file-name(s) expected-output-group-file-name
#                                                         expected-return-code
# -------------------------------------------------------------------------
# Following tests with "FF set" don't contain a complete set of all
# combinations of options and FF-arrangements
#
# One FF at start of file (one empty page)
# ['1a', '', [\'0Ft'], [\'0F'], 0],
['1b', '', [\'0Fnt'], [\'0F'], 0],
['1c', '+3', [\'0Ft'], [\'3-0F'], 0],
['1d', '+3 -f', [\'0Ft'], [\'3f-0F'], 0],
['1e', '-a -3', [\'0Ft'], [\'a3-0F'], 0],
['1f', '-a -3 -f', [\'0Ft'], [\'a3f-0F'], 0],
['1g', '-a -3 -f', [\'0Fnt'], [\'a3f-0F'], 0],
['1h', '+3 -a -3 -f', [\'0Ft'], [\'3a3f-0F'], 0],
['1i', '-b -3', [\'0Ft'], [\'b3-0F'], 0],
['1j', '-b -3 -f', [\'0Ft'], [\'b3f-0F'], 0],
['1k', '-b -3 -f', [\'0Fnt'], [\'b3f-0F'], 0],
['1l', '+3 -b -3 -f', [\'0Ft'], [\'3b3f-0F'], 0],
# Two FF at start of file (two empty page)
['2a', '', [\'0FFt'], [\'0FF'], 0],
['2b', '', [\'0FnFnt'], [\'0FF'], 0],
['2c', '-a -3 -f', [\'0FFt'], [\'a3f-0FF'], 0],
['2d', '-a -3 -f', [\'0FFnt'], [\'a3f-0FF'], 0],
['2e', '-b -3 -f', [\'0FFt'], [\'b3f-0FF'], 0],
['2f', '-b -3 -f', [\'0FFnt'], [\'b3f-0FF'], 0],
['2g', '-b -3 -f', [\'0FnFt'], [\'b3f-0FF'], 0],
['2h', '-b -3 -f', [\'0FnFnt'], [\'b3f-0FF'], 0],
['2i', '+3 -b -3 -f', [\'0FFt'], [\'3b3f-0FF'], 0],
['2j', '+3 -b -3 -f', [\'0FFnt'], [\'3b3f-0FF'], 0],
#
# FFs in text (none / one / two empty page(s))
['3a', '', [\'FFn'], [\'FF'], 0],
['3b', '', [\'FnFn'], [\'FF'], 0],
['3c', '+3', [\'FFn'], [\'3-FF'], 0],
['3d', '+3 -f', [\'FFn'], [\'3f-FF'], 0],
['3e', '-a -3 -f', [\'FFn'], [\'a3f-FF'], 0],
['3f', '-a -3 -f', [\'FFtn'], [\'a3f-FF'], 0],
['3g', '-b -3 -f', [\'FFn'], [\'b3f-FF'], 0],
['3h', '-b -3 -f', [\'FFtn'], [\'b3f-FF'], 0],
['3i', '-b -3 -f', [\'FnFn'], [\'b3f-FF'], 0],
['3j', '-b -3 -f', [\'tFFn'], [\'b3f-FF'], 0],
['3k', '-b -3 -f', [\'tFnFt'], [\'b3f-FF'], 0],
['3l', '+3 -b -3 -f', [\'FFn'], [\'3b3f-FF'], 0],
['3m', '+3 -b -3 -f', [\'FFtn'], [\'3b3f-FF'], 0],
# A full page printed (lines_left_on_page = 0) without a FF found.
# Avoid an extra empty page if a FF follows in the next input line.
['3la', '-l 24', [\'FFn'], [\'l24-FF'], 0],
['3lb', '-l 24', [\'FFtn'], [\'l24-FF'], 0],
['3lc', '-l 24', [\'FnFn'], [\'l24-FF'], 0],
['3ld', '-l 24', [\'tFFn'], [\'l24-FF'], 0],
['3le', '-l 24', [\'tFnFt'], [\'l24-FF'], 0],
['3lf', '-l 24', [\'tFFt'], [\'l24-FF'], 0],
['3aa', '-a -2 -l 17', [\'FFn'], [\'a2l17-FF'], 0],
['3ab', '-a -2 -l 17', [\'FFtn'], [\'a2l17-FF'], 0],
['3ac', '-a -2 -l 17', [\'FnFn'], [\'a2l17-FF'], 0],
['3ad', '-a -2 -l 17', [\'tFFn'], [\'a2l17-FF'], 0],
['3ae', '-a -2 -l 17', [\'tFnFt'], [\'a2l17-FF'], 0],
['3af', '-a -2 -l 17', [\'tFFt'], [\'a2l17-FF'], 0],
['3ag', '-a -2 -l 15', [\'FFn'], [\'a2l15-FF'], 0],
['3ah', '-a -2 -l 15', [\'FFtn'], [\'a2l15-FF'], 0],
['3ai', '-a -2 -l 15', [\'FnFn'], [\'a2l15-FF'], 0],
['3aj', '-a -2 -l 15', [\'tFFn'], [\'a2l15-FF'], 0],
['3ak', '-a -2 -l 15', [\'tFnFt'], [\'a2l15-FF'], 0],
['3ba', '-b -2 -l 17', [\'FFn'], [\'b2l17-FF'], 0],
['3bb', '-b -2 -l 17', [\'FFtn'], [\'b2l17-FF'], 0],
['3bc', '-b -2 -l 17', [\'FnFn'], [\'b2l17-FF'], 0],
['3bd', '-b -2 -l 17', [\'tFFn'], [\'b2l17-FF'], 0],
['3be', '-b -2 -l 17', [\'tFnFt'], [\'b2l17-FF'], 0],
['3bf', '-b -2 -l 17', [\'tFFt'], [\'b2l17-FF'], 0],
['3bg', '-b -2 -l 15', [\'FFn'], [\'b2l15-FF'], 0],
['3bh', '-b -2 -l 15', [\'FFtn'], [\'b2l15-FF'], 0],
['3bi', '-b -2 -l 15', [\'FnFn'], [\'b2l15-FF'], 0],
['3bj', '-b -2 -l 15', [\'tFFn'], [\'b2l15-FF'], 0],
['3bk', '-b -2 -l 15', [\'tFnFt'], [\'b2l15-FF'], 0],
['3Pa', '+4 -l 24', [\'FFn'], [\'4l24-FF'], 0],
['3Pb', '+4 -l 24', [\'FFtn'], [\'4l24-FF'], 0],
['3Pc', '+4 -l 24', [\'FnFn'], [\'4l24-FF'], 0],
['3Pd', '+4 -l 24', [\'tFFn'], [\'4l24-FF'], 0],
['3Pe', '+4 -l 24', [\'tFnFt'], [\'4l24-FF'], 0],
['3Pf', '+4 -l 24', [\'tFFt'], [\'4l24-FF'], 0],
['3Pg', '+4:7 -l 24', [\'tFFt'], [\'4-7l24-FF'], 0],
['3Paa', '+3 -a -2 -l 17', [\'FFn'], [\'3a2l17-FF'], 0],
['3Pab', '+3 -a -2 -l 17', [\'FFtn'], [\'3a2l17-FF'], 0],
['3Pac', '+3 -a -2 -l 17', [\'FnFn'], [\'3a2l17-FF'], 0],
['3Pad', '+3 -a -2 -l 17', [\'tFFn'], [\'3a2l17-FF'], 0],
['3Pae', '+3 -a -2 -l 17', [\'tFnFt'], [\'3a2l17-FF'], 0],
['3Paf', '+3 -a -2 -l 17', [\'tFFt'], [\'3a2l17-FF'], 0],
['3Pba', '+3 -b -2 -l 17', [\'FFn'], [\'3b2l17-FF'], 0],
['3Pbb', '+3 -b -2 -l 17', [\'FFtn'], [\'3b2l17-FF'], 0],
['3Pbc', '+3 -b -2 -l 17', [\'FnFn'], [\'3b2l17-FF'], 0],
['3Pbd', '+3 -b -2 -l 17', [\'tFFn'], [\'3b2l17-FF'], 0],
['3Pbe', '+3 -b -2 -l 17', [\'tFnFt'], [\'3b2l17-FF'], 0],
['3Pbf', '+3 -b -2 -l 17', [\'tFFt'], [\'3b2l17-FF'], 0],
#
# Without "FF set by hand"
['4a', '-l 24', [\'tn'], [\'l24-t'], 0],
['4b', '-l 24 -f', [\'tn'], [\'l24f-t'], 0],
['4c', '+3 -l 24', [\'tn'], [\'3l24-t'], 0],
['4d', '+3 -l 24 -f', [\'tn'], [\'3l24f-t'], 0],
['4e', '+3:5 -l 24 -f', [\'tn'], [\'3-5l24f-t'], 0],
['4f', '-a -3 -l 15', [\'tn'], [\'a3l15-t'], 0],
['4g', '-a -3 -l 15 -f', [\'tn'], [\'a3l15f-t'], 0],
['4h', '+3 -a -3 -l 15', [\'tn'], [\'3a3l15-t'], 0],
['4i', '+3 -a -3 -l 15 -f', [\'tn'], [\'3a3l15f-t'], 0],
['4j', '-b -3 -l 15', [\'tn'], [\'b3l15-t'], 0],
['4k', '-b -3 -l 15 -f', [\'tn'], [\'b3l15f-t'], 0],
['4l', '+3 -b -3 -l 15', [\'tn'], [\'3b3l15-t'], 0],
['4m', '+3 -b -3 -l 15 -f', [\'tn'], [\'3b3l15f-t'], 0],
#
# Merge input files (-m option)
['5a', '-m -l 24', [\'tn', \'tn'], [\'ml24-t'], 0],
['5b', '-m -l 24 -f', [\'tn', \'tn'], [\'ml24f-t'], 0],
['5c', '+3 -m -l 24', [\'tn', \'tn'], [\'3ml24-t'], 0],
['5d', '+3 -m -l 24 -f', [\'tn', \'tn'], [\'3ml24f-t'], 0],
['5e', '-m -l 24 -f', [\'0Ft', \'0Ft'], [\'ml24f-0F'], 0],
['5f', '-m -l 24 -f', [\'0Ft', \'0Fnt'], [\'ml24f-0F'], 0],
['5g', '-m -l 24 -f', [\'tn', \'0Ft'], [\'ml24f-t-0F'], 0],
# A full page printed (lines_left_on_page = 0) without a FF found.
# Avoid an extra empty page if a FF follows in the next input line.
['5ma', '-m -l 24', [\'tFFn', \'tFnFt'], [\'ml24-FF'], 0],
['5mb', '-m -l 24', [\'tFFn', \'FFn'], [\'ml24-FF'], 0],
['5mc', '-m -l 24', [\'tn', \'FFn'], [\'ml24-t-FF'], 0],
['5md', '-m -l 20', [\'FFn', \'tn'], [\'ml20-FF-t'], 0],
['5Pma', '+3 -m -l 24', [\'FFn', \'FnFn'], [\'3ml24-FF'], 0],
['5Pmb', '+3 -m -l 24', [\'tFFn', \'FFn'], [\'3ml24-FF'], 0],
['5Pmc', '+3 -m -l 24', [\'tn', \'FFn'], [\'3ml24-t-FF'], 0],
#
# Do not print header and footer but retain "FF set by Hand"
# (-t option)
['6a', '-t -l 24', [\'tn'], [\'t-t'], 0],
['6b', '-t -l 24 -f', [\'tn'], [\'t-t'], 0],
['6c', '-t -l 24 -f', [\'tFFt-bl'], [\'t-bl'], 0],
['6d', '-t -l 24', [\'0FnFnt'], [\'t-0FF'], 0],
['6e', '-t -l 24', [\'FFn'], [\'t-FF'], 0],
['6f', '-t -l 24', [\'FnFn'], [\'t-FF'], 0],
['6g', '-t -l 24 -f', [\'FFn'], [\'t-FF'], 0],
['6aa', '-t -a -3', [\'0FnFnt'], [\'ta3-0FF'], 0],
['6ab', '-t -a -3', [\'FFn'], [\'ta3-FF'], 0],
['6ac', '-t -a -3 -l 24', [\'FnFn'], [\'ta3-FF'], 0],
['6ba', '-t -b -3', [\'0FnFnt'], [\'tb3-0FF'], 0],
['6bb', '-t -b -3', [\'FFn'], [\'tb3-FF'], 0],
['6bc', '-t -b -3 -l 24', [\'FnFn'], [\'tb3-FF'], 0],
#
# Do not print header and footer nor "FF set by Hand" (-T option)
['7a', '-T -l 24', [\'tn'], [\'tt-t'], 0],
['7b', '-T -l 24 -f', [\'tn'], [\'tt-t'], 0],
['7c', '-T -l 24 -f', [\'tFFt-bl'], [\'tt-bl'], 0],
['7d', '-T -l 24', [\'0FnFnt'], [\'tt-0FF'], 0],
['7e', '-T -l 24', [\'FFn'], [\'tt-FF'], 0],
['7f', '-T -l 24', [\'FnFn'], [\'tt-FF'], 0],
['7g', '-T -l 24 -f', [\'FFn'], [\'tt-FF'], 0],
['7aa', '-T -a -3', [\'0FnFnt'], [\'tta3-0FF'], 0],
['7ab', '-T -a -3', [\'FFn'], [\'tta3-FF'], 0],
['7ac', '-T -a -3 -l 24', [\'FnFn'], [\'tta3-FF'], 0],
['7ba', '-T -b -3', [\'0FnFnt'], [\'ttb3-0FF'], 0],
['7bb', '-T -b -3', [\'FFn'], [\'ttb3-FF'], 0],
['7bc', '-T -b -3 -l 24', [\'FnFn'], [\'ttb3-FF'], 0],
#
# lhs-truncation of header
# pr-1.19m: Text line truncation only with column output
#
# numbering lines (-n  -N option)
# skip pages (+FIRST_PAGE[:LAST_PAGE] option)
['9a', '-n.3 -l 24 -f', [\'tFFt-bl'], [\'nl24f-bl'], 0],
['9b', '-n.3 -N 15 -l 24 -f', [\'tFFt-bl'], [\'nN15l24f-bl'], 0],
['9Pa', '-n.3 +2 -l 24 -f', [\'tFFt-bl'], [\'n+2l24f-bl'], 0],
['9Pb', '-n.3 +3 -l 24 -f', [\'tFFt-bl'], [\'n+3l24f-bl'], 0],
['9Pc', '-n.3 -N 1 +3 -l 24 -f', [\'tFFt-bl'], [\'nN1+3l24f-bl'], 0],
['9Pe', '-n.3 +2 -l 24 -f', [\'0FFt'], [\'n+2l24f-0FF'], 0],
['9Pf', '-n.3 +2 -l 24 -f', [\'0FFnt'], [\'n+2l24f-0FF'], 0],
['9Pg', '-n.3 +2 -l 24 -f', [\'0FnFt'], [\'n+2l24f-0FF'], 0],
['9Ph', '-n.3 +2 -l 24 -f', [\'0FnFnt'], [\'n+2l24f-0FF'], 0],
['9Pi', '-n.3 +2:5 -l 24 -f', [\'0FFt'], [\'n+2-5l24f-0FF'], 0],
['9Pj', '-n.3 +3 -l 24 -f', [\'0FFt'], [\'n+3l24f-0FF'], 0],
['9Pk', '-n.3 +3 -l 24 -f', [\'0FFnt'], [\'n+3l24f-0FF'], 0],
['9Pl', '-n.3 +3 -l 24 -f', [\'0FnFt'], [\'n+3l24f-0FF'], 0],
['9Pm', '-n.3 +3 -l 24 -f', [\'0FnFnt'], [\'n+3l24f-0FF'], 0],
['9Pn', '-n.3 +7 -l 24', [\'FFn'], [\'n+7l24-FF'], 0],
['9Po', '-n.3 +7 -l 24', [\'FFtn'], [\'n+7l24-FF'], 0],
['9Pp', '-n.3 +7 -l 24', [\'FnFn'], [\'n+7l24-FF'], 0],
['9Pq', '-n.3 +3:7 -l 24', [\'FnFn'], [\'n+3-7l24-FF'], 0],
['9Pr', '-n.3 +8 -l 20', [\'tFFn'], [\'n+8l20-FF'], 0],
['9Ps', '-n.3 +8 -l 20', [\'tFnFt'], [\'n+8l20-FF'], 0],
['9Pt', '-n.3 +8 -l 20', [\'tFFt'], [\'n+8l20-FF'], 0],
['9Paa', '-n.3 +5 -a -3 -l 13 -f', [\'0FFt'], [\'n+5a3l13f-0FF'], 0],
['9Pab', '-n.3 +5 -a -3 -l 13 -f', [\'0FFnt'], [\'n+5a3l13f-0FF'], 0],
['9Pac', '-n.3 +5 -a -3 -l 13 -f', [\'0FnFt'], [\'n+5a3l13f-0FF'], 0],
['9Pad', '-n.3 +5 -a -3 -l 13 -f', [\'0FnFnt'], [\'n+5a3l13f-0FF'], 0],
['9Pae', '-n.3 +6 -a -2 -l 17', [\'FFn'], [\'n+6a2l17-FF'], 0],
['9Paf', '-n.3 +6 -a -2 -l 17', [\'FFtn'], [\'n+6a2l17-FF'], 0],
['9Pag', '-n.3 +6 -a -2 -l 17', [\'FnFn'], [\'n+6a2l17-FF'], 0],
['9Pah', '-n.3 +6 -a -2 -l 17', [\'tFFn'], [\'n+6a2l17-FF'], 0],
['9Pai', '-n.3 +6 -a -2 -l 17', [\'tFnFt'], [\'n+6a2l17-FF'], 0],
['9Paj', '-n.3 +6 -a -2 -l 17', [\'tFFt'], [\'n+6a2l17-FF'], 0],
['9Pak', '-n.3 +4:8 -a -2 -l 17', [\'tFFt'], [\'n+4-8a2l17-FF'], 0],
['9Pba', '-n.3 +4 -b -2 -l 17 -f', [\'0FFt'], [\'n+4b2l17f-0FF'], 0],
['9Pbb', '-n.3 +4 -b -2 -l 17 -f', [\'0FFnt'], [\'n+4b2l17f-0FF'], 0],
['9Pbc', '-n.3 +4 -b -2 -l 17 -f', [\'0FnFt'], [\'n+4b2l17f-0FF'], 0],
['9Pbd', '-n.3 +4 -b -2 -l 17 -f', [\'0FnFnt'], [\'n+4b2l17f-0FF'], 0],
['9Pbe', '-n.3 +6 -b -3 -l 13 -f', [\'FFn'], [\'n+6b3l13f-FF'], 0],
['9Pbf', '-n.3 +6 -b -3 -l 13 -f', [\'FFtn'], [\'n+6b3l13f-FF'], 0],
['9Pbg', '-n.3 +6 -b -3 -l 13 -f', [\'FnFn'], [\'n+6b3l13f-FF'], 0],
['9Pbh', '-n.3 +6 -b -3 -l 13 -f', [\'tFFn'], [\'n+6b3l13f-FF'], 0],
['9Pbi', '-n.3 +6 -b -3 -l 13 -f', [\'tFnFt'], [\'n+6b3l13f-FF'], 0],
['9Pbj', '-n.3 +6 -b -3 -l 13 -f', [\'tFFt'], [\'n+6b3l13f-FF'], 0],
['9Pbk', '-n.3 +5:8 -b -3 -l 17 -f', [\'FnFn'], [\'n+5-8b3l17f-FF'], 0],
['9Pma', '-n.3 +3 -m -l 20 -f', [\'tFFt-bl', \'FnFn'], [\'n+3ml20f-bl-FF'], 0],
['9Pmb', '-n.3 +3 -m -l 24 -f', [\'tFFt-bl', \'tn'], [\'n+3ml24f-bl-tn'], 0],
['9Pmc', '-n.3 +3 -m -l 24 -f', [\'tn', \'tFFt-bl'], [\'n+3ml24f-tn-bl'], 0],
#
# line truncation  column alignment; header line truncation
# -w/W PAGE_WIDTH [-J] options
['10wa', '-W 72 -J -l24 -f', [\'tFFt-ll'], [\'W72Jl24f-ll'], 0],
['10wb', '-w 72 -J -l24 -f', [\'tFFt-ll'], [\'W72Jl24f-ll'], 0],
['10wc', '-W 72 -l24 -f', [\'tFFt-ll'], [\'W-72l24f-ll'], 0],
['10wd', '-w 72 -l24 -f', [\'tFFt-ll'], [\'w72l24f-ll'], 0],
['10we', '-W 28 -l24 -f', [\'tFFt-ll'], [\'W28l24f-ll'], 0],
['10wf', '-W 27 -l24 -f', [\'tFFt-ll'], [\'W27l24f-ll'], 0],
['10wg', '-W 26 -l24 -f', [\'tFFt-ll'], [\'W26l24f-ll'], 0],
['10wh', '-W 20 -l24 -f', [\'tFFt-ll'], [\'W20l24f-ll'], 0],
['10ma', '-m -l 24 -f', [\'tFFt-lm', \'loli'], [\'ml24f-lm-lo'], 0],
['10mb', '-W 35 -m -l 24 -f', [\'tFFt-lm', \'loli'], [\'W35ml24f-lm-lo'], 0],
['10mc', '-w 35 -m -l 24 -f', [\'tFFt-lm', \'loli'], [\'W35ml24f-lm-lo'], 0],
['10md', '-J -m -l 24 -f', [\'tFFt-lm', \'loli'], [\'Jml24f-lm-lo'], 0],
['10me', '-W 35 -J -m -l 24 -f', [\'tFFt-lm', \'loli'], [\'W35Jml24f-lmlo'], 0],
['10mf', '-w 35 -J -m -l 24 -f', [\'tFFt-lm', \'loli'], [\'W35Jml24f-lmlo'], 0],
['10mg', '-n.3 -J -m -l 24 -f', [\'tFFt-lm', \'tFFt-lm', \'loli'],
 [\'nJml24f-lmlmlo'], 0],
['10mh', '-n.3 -J -m -l 24 -f', [\'tFFt-lm', \'loli', \'tFFt-lm'],
 [\'nJml24f-lmlolm'], 0],
['10aa', '-a -3 -l 24 -f', [\'tFFt-lm'], [\'a3l24f-lm'], 0],
['10ab', '-W 35 -a -3 -l 24 -f', [\'tFFt-lm'], [\'W35a3l24f-lm'], 0],
['10ac', '-J -a -3 -l 24 -f', [\'tFFt-lm'], [\'Ja3l24f-lm'], 0],
['10ad', '-W 35 -J -a -3 -l 24 -f', [\'tFFt-lm'], [\'W35Ja3l24f-lm'], 0],
['10ba', '-b -3 -l 24 -f', [\'tFFt-lm'], [\'b3l24f-lm'], 0],
['10bb', '-W 35 -b -3 -l 24 -f', [\'tFFt-lm'], [\'W35b3l24f-lm'], 0],
['10bc', '-J -b -3 -l 24 -f', [\'tFFt-lm'], [\'Jb3l24f-lm'], 0],
['10bd', '-W 35 -J -b -3 -l 24 -f', [\'tFFt-lm'], [\'W35Jb3l24f-lm'], 0],
#
# merge files (-m option)  use separator string (-S option)
['11sa', '-n.3 -S:--: -m -l 20 -f', [\'tFFt-bl', \'FnFn'],
 [\'nSml20-bl-FF'], 0],
['11sb', '-n.3 -S:--: -m -l 24 -f', [\'tFFt-bl', \'FnFn'],
 [\'nSml24-bl-FF'], 0],
['11se', '-n.3 -S:--: -m -l 20 -f', [\'tn', \'tn', \'FnFn'],
 [\'nSml20-t-t-FF'], 0],
['11sf', '-n.3 -S:--: -m -l 24 -f', [\'tn', \'tn', \'FnFn'],
 [\'nSml24-t-t-FF'], 0],
['11sg', '-n.3 -S:--: -m -l 20 -f', [\'tn', \'tn', \'FnFn', \'FnFn'],
 [\'nSml20-t-tFFFF'], 0],
['11sh', '-n.3 -S:--: -m -l 24 -f', [\'tn', \'tn', \'FnFn', \'FnFn'],
 [\'nSml24-t-tFFFF'], 0],
#
# left margin (-o option) and separator string (-S option)
['12aa', '-o3 -a -3 -l24 -f', [\'tn'], [\'o3a3l24f-tn'], 0],
['12ab', '-o3 -a -3 -S:--: -l24 -f', [\'tn'], [\'o3a3Sl24f-tn'], 0],
['12ac', '-o3 -a -3 -S:--: -n. -l24 -f', [\'tn'], [\'o3a3Snl24f-tn'], 0],
['12ba', '-o3 -b -3 -l24 -f', [\'tn'], [\'o3b3l24f-tn'], 0],
['12bb', '-o3 -b -3 -S:--: -l24 -f', [\'tn'], [\'o3b3Sl24f-tn'], 0],
['12bc', '-o3 -b -3 -S:--: -n. -l24 -f', [\'tn'], [\'o3b3Snl24f-tn'], 0],
['12ma', '-o3 -m -l24 -f', [\'tFFt-bl', \'tn'], [\'o3ml24f-bl-tn'], 0],
['12mb', '-o3 -m -S:--: -l24 -f', [\'tFFt-bl', \'tn'], [\'o3mSl24f-bl-tn'], 0],
['12mc', '-o3 -m -S:--: -n. -l24 -f', [\'tFFt-bl', \'tn'],
 [\'o3mSnl24fbltn'], 0],
['12md', '-o3 -J -m -l24 -f', [\'tFFt-lm', \'loli'], [\'o3Jml24f-lm-lo'], 0],
#
#
# Single column output: POSIX compliant, adapt other UNIXes (SunOS.5.5.1 e.g.)
# number-separator TAB always an output TAB --> varying number/text-spacing
['13a', '-t -n -e8', [\'t_tab'], [\'tne8-t_tab'], 0],
['13b', '-t -n -e8 -o3', [\'t_tab'], [\'tne8o3-t_tab'], 0],
#
# POSIX compliant: multi-columns of equal width (unlike SunOS.5.5.1 e.g.)
# text-tab handling
['13ba', '-t -n -2 -e8', [\'t_tab'], [\'tn2e8-t_tab'], 0],
['13bb', '-t -n: -2 -e8', [\'t_tab'], [\'tn_2e8-t_tab'], 0],
['13bc', '-t -n: -2 -e8 -S----', [\'t_tab'], [\'tn_2e8S-t_tab'], 0],
['13bd', '-t -n -2 -e8 -o3', [\'t_tab'], [\'tn2e8o3-t_tab'], 0],
# number-separator TAB not treated as input text-tab, no '-e' expansion
['13be', '-t -n -2 -e5 -o3', [\'t_tab'], [\'tn2e5o3-t_tab'], 0],
# input-tab-char ':' not equal default (text) TABs
['13bf', '-t -n -2 -e:8', [\'t_tab_'], [\'tn2e8-t_tab'], 0],
#
# options -w/-s: POSIX-compliant, means adapting the interference of -w/-s
# with multi-column output from other UNIXes (SunOS e.g.);
# columns, truncated = 72   /  separator = space :
['14a', '-2 -f', [\'t_notab'], [\'2f-t_notab'], 0],
# full lines, no truncation /  separator = TAB :
['14b', '-2 -s -f', [\'t_notab'], [\'2sf-t_notab'], 0],
# full lines, no truncation /  separator = ':' :
['14c', '-2 -s: -f', [\'t_notab'], [\'2s_f-t_notab'], 0],
# columns, truncated = 60   /  separator = space :
['14d', '-2 -w60 -f', [\'t_notab'], [\'2w60f-t_notab'], 0],
# columns, truncated = 60   /  no separator   (SunOS-BUG: line width to small):
['14e', '-2 -s -w60 -f', [\'t_notab'], [\'2sw60f-t_notab'], 0],
# columns, truncated = 60   /  separator = ':'  (HP-UX.10.20-2-BUG:
# ':' missing with -m option):
['14f', '-2 -s: -w60 -f', [\'t_notab'], [\'2s_w60f-t_nota'], 0],
#
# new long-options -W/-S/-J disentangle those options (see also No.'10*')
# columns, truncated = 72   /  no separator :
['14g', '-2 -S -f', [\'t_notab'], [\'2-Sf-t_notab'], 0],
# full lines, no truncation /  separator = TAB :  (Input: -S"<TAB>")
['14h', '-2 -S"	" -J -f', [\'t_notab'], [\'2sf-t_notab'], 0],
# columns, truncated = 72   /  separator ':' :
['14i', '-2 -S: -f', [\'t_notab'], [\'2-S_f-t_notab'], 0],
# full lines, no truncation /  separator = ':' :
['14j', '-2 -S: -J -f', [\'t_notab'], [\'2s_f-t_notab'], 0],
# columns, truncated = 60   /  separator = space:
['14k', '-2 -W60 -f', [\'t_notab'], [\'2w60f-t_notab'], 0],
# columns, truncated = 60   /  no separator :
['14l', '-2 -S -W60 -f', [\'t_notab'], [\'2sw60f-t_notab'], 0],
# columns, truncated = 60   /  separator = ':' :
['14m', '-2 -S: -W60 -f', [\'t_notab'], [\'2s_w60f-t_nota'], 0],
#
# Tabify multiple spaces, -i option
# number of input spaces between a and b must not change; be careful
# comparing with other UNIXes (some other SunOS examples are OK !?)
# SunOS.5.5.1-BUG: 8 input spaces --> 11 output spaces between a and b;
['i-opt-a', '-tn -i5 -h ""', "a        b\n", "    1	a	    b\n", 0],
# SunOS.5.5.1-BUG: 8 input spaces -->  9 output spaces between a and b;
['i-opt-b', '-tn -i5 -o9 -h ""', "a        b\n",
 "		   1	a	    b\n", 0],
#
# line number overflow not allowed: cut off leading digits;
# don't adapt other UNIXes, no real standard to follow, a consequent
# programming of column handling may change the GNU pr concept.
['ncut-a', '-tn2 -N98', "y\ny\ny\ny\ny\n",
 "98	y\n99	y\n00	y\n01	y\n02	y\n", 0],
['ncut-b', '-tn:2 -N98', "y\ny\ny\ny\ny\n",
 "98:y\n99:y\n00:y\n01:y\n02:y\n", 0],

['margin-0', '-o 0', '', '', 0],

# BUG fixed: that leading space on 3rd line of output should not be there
['dbl-sp-a', '-d -l 14 -h ""', "1\n2\n",
 "\n\n-- Date/Time --                                                   "
 . "Page 1\n\n\n1\n\n2\n\n\n\n\n\n\n", 0],
# This test failed with 1.22e and earlier.
['dbl-sp-b', '-d -t', "1\n2\n", "1\n\n2\n\n", 0],

# This test would segfault with 2.0f and earlier.
['narrow-1', '-W1 -t', "12345\n", "1\n", 0],

# This test would fail with textutils-2.1 and earlier.
['col-last', '-W3 -t2', "a\nb\nc\n", "a c\nb\n", 0],

# Make sure that -02 is treated just like -2.
['col-02', '-W3 -t -02',                "a\nb\nc\n", "a c\nb\n", 0],
# The -2 must override preceding column-count-specifying options.
['col-2', '-W3 -t -4 --columns=1 -2', "a\nb\nc\n", "a c\nb\n", 0],
# The --columns=2 must override preceding column-count-specifying options.
['col-long', '-W3 -t -1 --columns=2',     "a\nb\nc\n", "a c\nb\n", 0],
# Make sure these fail.
['col-0', '-0', '', '', 1,
 "$prog: invalid number of columns: '0'\n", $normalize_strerror],
['col-inval', '-'.'9'x100, '', '', 1,
 "$prog: invalid number of columns: '". ('9'x100) ."'\n", $normalize_strerror],

# Before coreutils-5.3.1, --pages=1:-1 would be treated like
# --pages=1:18446744073709551615.
['neg-page', '--pages=1:-1', '', '', 1,
 "$prog: invalid --pages argument '1:-1'\n"],

# Up to coreutils-6.10, this would cause pr to decrement its
# internal "input_position" below zero and sometimes segfault.
['neg-inp-pos1', '-t -e', "\b\b\b\b\b\b\tx\n", "        x\n", 0],
# NB: while there are 4 backspaces in the input, there are only 3 in the output
['neg-inp-pos2', '-t -e', "abc\b\b\b\b\tx", "abc\b\b\b        x\n", 0],

# This would clobber so much of the heap, it'd segfault or abort every time.
['smash-heap', '-t -e300', "a".("\b"x50)."\t", "a\b".(" "x300)."\n", 0],
['smash-heap8', '-t -e',   "a".("\b"x50)."\t", "a\b".(" "x  8)."\n", 0],

# Before coreutils-8.13 page numbers were not handled correctly when
# headers were not printed (when -l <= 10 or -t or -T specified)
['page-range', '+1:1 -2 -l1 -s" "',  "a\nb\nc\n", "a b\n", 0],

# This padded with zeros before coreutils-8.21
['padding1', '-t -n,15', "1\n", (" "x 14)."1,1\n", 0],
# This crashed with divide by zero before coreutils-8.21
['padding2', '-t -n,64', "1\n", (" "x 63)."1,1\n", 0],
# Ensure we handle buffer truncation correctly
['padding3', '-t -N1000000 -n,1', "1\n", "0,1\n", 0],
);

# Convert the above old-style test vectors to the newer
# format used by Coreutils.pm.

my $pfx = "$ENV{abs_srcdir}/tests/pr";

# Normalize otherwise-variable output page headers.
my $common_option_prefix = '--date-format="-- Date/Time --" -h x';

my @Tests;
foreach my $t (@tv)
  {
    my ($test_name, $flags, $in, $exp, $ret, $err_msg, $err_sub) = @$t;
    my $new_ent = [$test_name, $common_option_prefix, $flags];
    if (!ref $in)
      {
        push @$new_ent, {IN=>$in};
      }
    else
      {
        foreach my $e (@$in)
          {
            my $file_name = $$e;
            push @$new_ent, {IN=>{"$pfx/$file_name"=>undef}};
          }
      }
    if (!ref $exp)
      {
        push @$new_ent, {OUT=>$exp};
      }
    else
      {
        foreach my $e (@$exp)
          {
            my $file_name = $$e;
            push @$new_ent, {OUT=>{"$pfx/$file_name"=>undef}};
          }
      }
    $ret
      and push @$new_ent, {EXIT=>$ret}, {ERR=>$err_msg}, {ERR_SUBST=>$err_sub};
    push @Tests, $new_ent;
  }

# Exercise a bug with pr -m -s (commit 553d347)
push @Tests,
   ['merge-w-tabs', '-m -s -t',
    {IN=>{1=>"a\tb\tc\n"}},
    {IN=>{2=>"m\tn\to\n"}},
    {IN=>{3=>"x\ty\tz\n"}},
     {OUT=>join("\t", qw(a b c m n o x y z)) . "\n"} ];

# This resulted in reading invalid memory before coreutils-8.26
push @Tests,
   ['asan1', "-m -S'\t\t\t' -t",
    {IN=>{1=>"a\n"}},
    {IN=>{2=>"a\n"}},
     {OUT=>"a\t\t\t\t  \t\t\ta\n"} ];

@Tests = triple_test \@Tests;

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($prog, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
