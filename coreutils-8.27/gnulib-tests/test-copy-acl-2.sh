#!/bin/sh

# Test copy-acl on the file system of the build directory, which may be
# a local file system or NFS mounted.

TMPDIR=`pwd`
export TMPDIR

exec "${srcdir}/test-copy-acl.sh"
