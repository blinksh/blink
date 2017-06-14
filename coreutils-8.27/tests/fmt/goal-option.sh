#!/bin/sh
# Exercise the fmt -g option.

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

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ fmt

cat <<\_EOF_ > base || fail=1

@command{fmt} prefers breaking lines at the end of a sentence, and tries to
avoid line breaks after the first word of a sentence or before the last word
of a sentence.  A @dfn{sentence break} is defined as either the end of a
paragraph or a word ending in any of @samp{.?!}, followed by two spaces or end
of line, ignoring any intervening parentheses or quotes.  Like @TeX{},
@command{fmt} reads entire ''paragraphs'' before choosing line breaks; the
algorithm is a variant of that given by
Donald E. Knuth and Michael F. Plass
in ''Breaking Paragraphs Into Lines'',
@cite{Software---Practice & Experience}
@b{11}, 11 (November 1981), 1119--1184.
_EOF_

fmt -g 60 -w 72 base > out || fail=1

cat <<\_EOF_ > exp

@command{fmt} prefers breaking lines at the end of a sentence,
and tries to avoid line breaks after the first word of a sentence
or before the last word of a sentence.  A @dfn{sentence break}
is defined as either the end of a paragraph or a word ending
in any of @samp{.?!}, followed by two spaces or end of line,
ignoring any intervening parentheses or quotes.  Like @TeX{},
@command{fmt} reads entire ''paragraphs'' before choosing line
breaks; the algorithm is a variant of that given by Donald
E. Knuth and Michael F. Plass in ''Breaking Paragraphs Into
Lines'', @cite{Software---Practice & Experience} @b{11}, 11
(November 1981), 1119--1184.
_EOF_

compare exp out || fail=1

Exit $fail
