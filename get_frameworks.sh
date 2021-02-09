#!/bin/bash
set -e

(
    cd xcfs
    swift package resolve
)

echo "done"
