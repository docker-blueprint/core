#!/bin/bash

#
# Update .gitignore to exclude .docker-blueprint
#

CONTENT="$DIR_NAME/\n"

if [[ -f .gitignore ]]; then
    if [[ -z $(cat .gitignore | grep "$DIR_NAME/") ]]; then
        printf "$CONTENT" >> .gitignore
    fi
else
    printf "$CONTENT" > .gitignore
fi
