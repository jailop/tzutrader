#!/bin/bash

FILE="toremove.txt"
while IFS= read -r line; do
    if [ -e "$line" ]; then
        rm "$line"
    fi
done < "$FILE"
