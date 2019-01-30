#!/bin/bash

set -e

DEPS_VERSION="1.0.17"

GHROOT="https://github.com/blinksh"

(

cd "${BASH_SOURCE%/*}/Frameworks"
echo "Downloading frameworks"
curl -OL $GHROOT/external-deps/releases/download/v$DEPS_VERSION/frameworks.tar.gz
( tar -xzf frameworks.tar.gz --strip 1 && rm frameworks.tar.gz ) || { echo "Frameworks failed to download"; exit 1; }

)

# We need ios_system for the sources of curl_static too:
(# ios_system
cd "${BASH_SOURCE%/*}/Frameworks/ios_system"
sh ./get_sources.sh
)
