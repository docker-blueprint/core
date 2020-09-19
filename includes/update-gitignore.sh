#!/bin/bash

#
# Update .gitignore to exclude .docker-blueprint
#

CONTENT="$DIR\n"

if [[ -f .gitignore ]]; then
    if [[ -z $(cat .gitignore | grep "$DIR") ]]; then
        printf "$CONTENT" >> .gitignore
    fi
else
    printf "$CONTENT" > .gitignore
fi
