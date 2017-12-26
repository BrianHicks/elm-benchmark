#!/usr/bin/env bash

# like spellcheck.sh, but fail if there are any spelling errors

STATUS=0

for file in "$@"; do
    WRONG="$(aspell list --conf ./docs/aspell.conf < "$file")"
    if ! test -z "$WRONG"; then
	STATUS=1
	echo "found misspelled words in $file:"
	echo "$WRONG"
	echo
    fi
done

exit $STATUS
