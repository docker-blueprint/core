#!/bin/bash

if [[ -z "$(which docker)" ]]; then
    printf "You do not appear to have 'docker' installed (${HIGHLIGHT}https://docker.com${RESET})\n"

    if $is_wsl; then
        printf "We detected that you are running this installer under WSL and\n"
        printf "that 'docker' is not installed. Please install Docker for Desktop\n"
        printf "for the best experience: ${HIGHLIGHT}https://www.docker.com/products/docker-desktop${RESET}\n"
        printf "\n"
        printf "Do you want to continue installing? [y/N] "
        read -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        printf "Since docker-blueprint is designed to work with docker, you will not be able to use it without docker\n"
        printf "We can attempt to automatically install docker using convinience script:\n"
        printf "${HIGHLIGHT}https://docs.docker.com/engine/install/ubuntu/#install-using-the-convenience-script${RESET}\n"
        printf "\n"
        printf "Do you want to automatically install docker? [Y/n] "
        read -n 1 -r
        echo ""
        if [[ -z "$REPLY" ]] || [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Trying to install docker..."
            curl -fsSL https://get.docker.com | sh
            if [[ $? > 0 ]]; then
                printf "Unable to install docker, skipping..."
            fi
        fi
    fi
fi
