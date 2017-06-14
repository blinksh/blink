#!/bin/sh
set -e -x

BINDIR="$DSTROOT"/usr/bin
LIBEXECDIR="$DSTROOT"/usr/libexec
MANDIR="$DSTROOT"/usr/share/man
PAMDIR="$DSTROOT"/private/etc/pam.d

ln -f "$BINDIR/hexdump" "$BINDIR/od"
ln -f "$BINDIR/id" "$BINDIR/groups"
ln -f "$BINDIR/id" "$BINDIR/whoami"
ln -f "$BINDIR/w" "$BINDIR/uptime"
ln -f "$DSTROOT/bin/test" "$DSTROOT/bin/["

install -d -o root -g wheel -m 0755 "$BINDIR"
install -d -o root -g wheel -m 0755 "$MANDIR"/man1
install -d -o root -g wheel -m 0755 "$MANDIR"/man8

install -c -o root -g wheel -m 0755 "$SRCROOT"/alias/generic.sh "$BINDIR"/alias
install -c -o root -g wheel -m 0644 "$SRCROOT"/alias/builtin.1 "$MANDIR"/man1

set +x
for builtin in `cat "$SRCROOT/xcodescripts/builtins.txt"`; do
	echo ... linking $builtin
	ln -f "$BINDIR"/alias "$BINDIR/$builtin"
done

for manpage in `cat "$SRCROOT/xcodescripts/builtins-manpages.txt"`; do
	echo ... linking $manpage
	echo ".so man1/builtin.1" > "$MANDIR/man1/$manpage"
done
set -x

# Skip locate and su targets for iOS
if [ "$TARGET_NAME" = "All_iOS" ]; then
	exit 0
fi
	
install -d -o root -g wheel -m 0755 "$LIBEXECDIR"
install -c -o root -g wheel -m 0755 "$SRCROOT"/locate/locate/updatedb.sh \
	"$LIBEXECDIR"/locate.updatedb
install -c -o root -g wheel -m 0644 "$SRCROOT"/locate/locate/locate.updatedb.8 \
	"$MANDIR"/man8
install -c -o root -g wheel -m 0755 "$SRCROOT"/locate/locate/concatdb.sh \
	"$LIBEXECDIR"/locate.concatdb
echo ".so man8/locate.updatedb.8" > "$MANDIR"/man8/locate.concatdb.8
install -c -o root -g wheel -m 0755 "$SRCROOT"/locate/locate/mklocatedb.sh \
	"$LIBEXECDIR"/locate.mklocatedb
echo ".so man8/locate.updatedb.8" > "$MANDIR"/man8/locate.mklocatedb.8

install -d -o root -g wheel -m 0755 "$PAMDIR"
install -c -o root -g wheel -m 0644 "$SRCROOT"/su/su.pam "$PAMDIR"/su
