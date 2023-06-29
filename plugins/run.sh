#!/bin/sh

files=$(ls | grep -o '^[a-zA-Z]*.awk$')
awk $(for file in $files; do echo "-f $file"; done)
