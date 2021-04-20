#!/bin/bash

if [[ -z "$(which docker-compose)" ]]; then
    printf "You do not appear to have 'docker-compose' installed (${HIGHLIGHT}https://docs.docker.com/compose/install${RESET})\n"

    printf "Since docker-blueprint is designed to work with docker-compose, you will not be able to use it without docker-compose\n"
    printf "We can attempt to automatically install docker-compose using curl:\n"
    printf "${HIGHLIGHT}https://docs.docker.com/compose/install/#install-compose-on-linux-systems${RESET}\n"
    printf "\n"
    printf "Do you want to automatically install docker-compose? [Y/n] "
    read -n 1 -r
    echo ""
    if [[ -z "$REPLY" ]] || [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Trying to install docker-compose..."
        sudo curl -L "https://github.com/docker/compose/releases/download/1.29.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        if [[ $? > 0 ]]; then
            printf "Unable to install docker-compose, skipping..."
        fi
        sudo chmod +x /usr/local/bin/docker-compose
    fi
fi
