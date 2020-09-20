#!/bin/bash

shift

case $1 in
    -h|--help)
        printf "update\t\t\tUpdate docker-blueprint to the latest version\n"
        exit

        ;;
esac

bash -c "$(curl -fsSL https://raw.githubusercontent.com/docker-blueprint/core/master/install.sh)"
