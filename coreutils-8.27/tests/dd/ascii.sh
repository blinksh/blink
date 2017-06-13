#!/bin/sh
# test conv=ascii

# Copyright (C) 2014-2017 Free Software Foundation, Inc.

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
print_ver_ dd printf

{
  # Two lines, EBCDIC " A A" and " A  ", followed by all the bytes in order.
  env printf '\100\301\100\301\100\301\100\100' &&
  env printf $(env printf '\\%03o' $(seq 0 255));
} >in || framework_failure_

{
  # The converted lines, with trailing spaces removed.
env printf \
' A A\n A\n'\
'\000\001\002\003\n\234\011\206\177\n'\
'\227\215\216\013\n\014\015\016\017\n'\
'\020\021\022\023\n\235\205\010\207\n'\
'\030\031\222\217\n\034\035\036\037\n'\
'\200\201\202\203\n\204\012\027\033\n'\
'\210\211\212\213\n\214\005\006\007\n'\
'\220\221\026\223\n\224\225\226\004\n'\
'\230\231\232\233\n\024\025\236\032\n'\
'\040\240\241\242\n\243\244\245\246\n'\
'\247\250\325\056\n\074\050\053\174\n'\
'\046\251\252\253\n\254\255\256\257\n'\
'\260\261\041\044\n\052\051\073\176\n'\
'\055\057\262\263\n\264\265\266\267\n'\
'\270\271\313\054\n\045\137\076\077\n'\
'\272\273\274\275\n\276\277\300\301\n'\
'\302\140\072\043\n\100\047\075\042\n'\
'\303\141\142\143\n\144\145\146\147\n'\
'\150\151\304\305\n\306\307\310\311\n'\
'\312\152\153\154\n\155\156\157\160\n'\
'\161\162\136\314\n\315\316\317\320\n'\
'\321\345\163\164\n\165\166\167\170\n'\
'\171\172\322\323\n\324\133\326\327\n'\
'\330\331\332\333\n\334\335\336\337\n'\
'\340\341\342\343\n\344\135\346\347\n'\
'\173\101\102\103\n\104\105\106\107\n'\
'\110\111\350\351\n\352\353\354\355\n'\
'\175\112\113\114\n\115\116\117\120\n'\
'\121\122\356\357\n\360\361\362\363\n'\
'\134\237\123\124\n\125\126\127\130\n'\
'\131\132\364\365\n\366\367\370\371\n'\
'\060\061\062\063\n\064\065\066\067\n'\
'\070\071\372\373\n\374\375\376\377\n';
} >exp || framework_failure_

dd if=in of=out conv=ascii cbs=4 || fail=1

compare exp out \
  || { od -v -to1 exp > exp2 || framework_failure_;
       od -v -to1 out > out2 || framework_failure_;
       compare exp2 out2;
       fail=1; }

Exit $fail
