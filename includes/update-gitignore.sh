#!/bin/bash

#
# Update .gitignore to exclude .docker-blueprint
#

CONTENT="$LOCAL_DIR\n"

if [[ -f .gitignore ]]; then
    if [[ -z $(cat .gitignore | grep "$LOCAL_DIR") ]]; then
        printf "$CONTENT" >> .gitignore
    fi
else
    printf "$CONTENT" > .gitignore
fi
