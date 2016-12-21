#!/bin/bash

LIBSSH2_VER="1.7.0"
OPENSSL_VER="1.0.2j"
LIBMOSH_VER="1.2.5-dd1d82e"
PROTOBF_VER="2.6.1"

GHROOT="https://github.com/blinksh"

cd "${BASH_SOURCE%/*}/Frameworks"
# libssh2
echo "Downloading libssh2-$LIBSSH2_VER.framework.tar.gz"
curl -OL $GHROOT/libssh2-for-iOS/releases/download/$LIBSSH2_VER/libssh2-$LIBSSH2_VER.framework.tar.gz
( tar -zxf libssh2-*.tar.gz && rm libssh2-*.tar.gz ) || { echo "Libssh2 framework failed to download"; exit 1; }
# openssl
echo "Downloading OpenSSL-$OPENSSL_VER.framework.tar.gz"
curl -OL $GHROOT/OpenSSL-for-iPhone/releases/download/$OPENSSL_VER/openssl-$OPENSSL_VER.framework.tar.gz
( tar -zxf openssl-*.tar.gz && rm openssl-*.tar.gz ) || { echo "OpenSSL framework failed to download"; exit 1; }
# libmoshios
echo "Downloading libmoshios-$LIBMOSH_VER.framework.tar.gz"
curl -OL $GHROOT/build-mosh/releases/download/$LIBMOSH_VER/libmoshios-$LIBMOSH_VER.framework.tar.gz
( tar -zxf libmoshios-*.tar.gz && rm libmoshios-*.tar.gz ) || { echo "Libmoshios framework failed to download"; exit 1; }
# protobuf
echo "Downloading protobuf-$PROTOBF_VER.framework.tar.gz"
curl -OL $GHROOT/build-protobuf/releases/download/$PROTOBF_VER/protobuf-$PROTOBF_VER.tar.gz
( tar -zxf protobuf-*.tar.gz && cp protobuf-*/lib/libprotobuf.a ./lib/ && rm -rf protobuf-* ) || { echo "Protobuf framework failed to download"; exit 1; }

