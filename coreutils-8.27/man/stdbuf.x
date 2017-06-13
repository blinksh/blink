'\" Copyright (C) 2009-2017 Free Software Foundation, Inc.
'\"
'\" This is free software.  You may redistribute copies of it under the terms
'\" of the GNU General Public License <http://www.gnu.org/licenses/gpl.html>.
'\" There is NO WARRANTY, to the extent permitted by law.
[NAME]
stdbuf \-
Run COMMAND, with modified buffering operations for its standard streams.
[DESCRIPTION]
.\" Add any additional description here
[EXAMPLES]
.B tail -f access.log | stdbuf -oL cut -d \(aq \(aq -f1 | uniq
.br
This will immediately display unique entries from access.log
[BUGS]
On GLIBC platforms, specifying a buffer size, i.e., using fully buffered mode
will result in undefined operation.
