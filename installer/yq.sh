#!/bin/bash

if [[ -z "$(which yq)" ]]; then
    printf "You do not appear to have 'yq' installed (${HIGHLIGHT}https://github.com/mikefarah/yq${RESET})\n"
    printf "For the best experience it is recommended to install a standalone version of 'yq'\n"
    printf "\n"
    printf "Do you want to attempt to automatically install 'yq'? [Y/n] "
    read -n 1 -r
    echo ""
    if [[ -z "$REPLY" ]] || [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Trying to install using webi..."
        curl -sS https://webinstall.dev/yq@4 | bash
    fi
fi
