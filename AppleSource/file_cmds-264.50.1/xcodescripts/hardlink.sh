#!/bin/sh
# Link input files to output files (in order).

set -e

if [ "$SCRIPT_INPUT_FILE_COUNT" -ne "$SCRIPT_OUTPUT_FILE_COUNT" ]; then
	echo input and output file counts differ
	exit 1
fi

X=0

while [ "$X" -lt "$SCRIPT_INPUT_FILE_COUNT" ]; do
	eval ln -fhv \"\$SCRIPT_INPUT_FILE_$X\" \"\$SCRIPT_OUTPUT_FILE_$X\"
	X=$((X+1))
done
