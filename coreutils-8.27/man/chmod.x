'\" Copyright (C) 1998-2017 Free Software Foundation, Inc.
'\"
'\" This is free software.  You may redistribute copies of it under the terms
'\" of the GNU General Public License <http://www.gnu.org/licenses/gpl.html>.
'\" There is NO WARRANTY, to the extent permitted by law.
[NAME]
chmod \- change file mode bits
[DESCRIPTION]
This manual page
documents the GNU version of
.BR chmod .
.B chmod
changes the file mode bits of each given file according to
.IR mode ,
which can be either a symbolic representation of changes to make, or
an octal number representing the bit pattern for the new mode bits.
.PP
The format of a symbolic mode is [\c
\fBugoa\fP.\|.\|.][[\fB-+=\fP][\fIperms\fP.\|.\|.].\|.\|.],
where
.I "perms"
is either zero or more letters from the set
\fBrwxXst\fP, or a single letter from the set \fBugo\fP.
Multiple symbolic
modes can be given, separated by commas.
.PP
A combination of the letters \fBugoa\fP controls which users' access
to the file will be changed: the user who owns it (\fBu\fP), other
users in the file's group (\fBg\fP), other users not in the file's
group (\fBo\fP), or all users (\fBa\fP).  If none of these are given,
the effect is as if (\fBa\fP) were
given, but bits that are set in the umask are not affected.
.PP
The operator \fB+\fP causes the selected file mode bits to be added to
the existing file mode bits of each file; \fB-\fP causes them to be
removed; and \fB=\fP causes them to be added and causes unmentioned
bits to be removed except that a directory's unmentioned set user and
group ID bits are not affected.
.PP
The letters \fBrwxXst\fP select file mode bits for the affected users:
read (\fBr\fP), write (\fBw\fP), execute (or search for directories)
(\fBx\fP), execute/search only if the file is a directory or already
has execute permission for some user (\fBX\fP), set user or group ID
on execution (\fBs\fP), restricted deletion flag or sticky bit
(\fBt\fP).  Instead of one or more of these letters, you can specify
exactly one of the letters \fBugo\fP: the permissions granted to the
user who owns the file (\fBu\fP), the permissions granted to other
users who are members of the file's group (\fBg\fP),
and the permissions granted to users that are in neither of the two preceding
categories (\fBo\fP).
.PP
A numeric mode is from one to four octal digits (0\-7), derived by
adding up the bits with values 4, 2, and 1.  Omitted digits are
assumed to be leading zeros.
The first digit selects the set user ID (4) and set group ID (2) and
restricted deletion or sticky (1) attributes.  The second digit
selects permissions for the user who owns the file: read (4), write (2),
and execute (1); the third selects permissions for other users in the
file's group, with the same values; and the fourth for other users not
in the file's group, with the same values.
.PP
.B chmod
never changes the permissions of symbolic links; the
.B chmod
system call cannot change their permissions.  This is not a problem
since the permissions of symbolic links are never used.
However, for each symbolic link listed on the command line,
.B chmod
changes the permissions of the pointed-to file.
In contrast,
.B chmod
ignores symbolic links encountered during recursive directory
traversals.
.SH "SETUID AND SETGID BITS"
.B chmod
clears the set-group-ID bit of a
regular file if the file's group ID does not match the user's
effective group ID or one of the user's supplementary group IDs,
unless the user has appropriate privileges.  Additional restrictions
may cause the set-user-ID and set-group-ID bits of
.I MODE
or
.I RFILE
to be ignored.  This behavior depends on the policy and
functionality of the underlying
.B chmod
system call.  When in
doubt, check the underlying system behavior.
.PP
.B chmod
preserves a directory's set-user-ID and set-group-ID bits unless you
explicitly specify otherwise.  You can set or clear the bits with
symbolic modes like
.B u+s
and
.BR g\-s ,
and you can set (but not clear) the bits with a numeric mode.
.SH "RESTRICTED DELETION FLAG OR STICKY BIT"
The restricted deletion flag or sticky bit is a single bit, whose
interpretation depends on the file type.  For directories, it prevents
unprivileged users from removing or renaming a file in the directory
unless they own the file or the directory; this is called the
.I "restricted deletion flag"
for the directory, and is commonly found on world-writable directories
like \fB/tmp\fP.  For regular files on some older systems, the bit
saves the program's text image on the swap device so it will load more
quickly when run; this is called the
.IR "sticky bit" .
.SH OPTIONS
[SEE ALSO]
chmod(2)
