#!/bin/bash


echo "Checking all files for the header:"
cat header
echo "Please wait..."

errors=false
for i in $(find . -path "./Frameworks/*" -prune -false -o -type f -name "*.h" -o -name "*.m"); do
    DIFF=$(diff <(head -n 30 header) <(head -n 30 $i))
    if [ "$DIFF" != "" ]; then { echo -e "\033[0;31mERROR - \033[0m$i"; errors=true; } fi
done

if [ $errors = true ]; then
    echo "Errors processing input"
    exit 1
fi

echo "Success!"
