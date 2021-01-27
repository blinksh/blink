#!/bin/bash
set -e

(
    cd xcfs
    swift package resolve
)

(
    cd Frameworks/ios_system/xcfs
    swift package resolve
)

echo "done"