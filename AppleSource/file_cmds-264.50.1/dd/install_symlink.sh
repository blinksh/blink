#!/bin/sh
set -e
set -x

case "$PLATFORM_NAME" in
iphoneos|appletvos|watchos)
    ln -hfs /usr/local/bin/dd "$DSTROOT"/bin/dd
    ;;
macosx)
    ;;
*)
    echo "Unsupported platform: $PLATFORM_NAME"
    exit 1
    ;;
esac

