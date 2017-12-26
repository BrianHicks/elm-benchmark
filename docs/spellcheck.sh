#!/usr/bin/env bash

for file in "$@"; do
    aspell check "$file" --conf ./docs/aspell.conf
done
