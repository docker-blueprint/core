#!/bin/bash

PROJECT_DIR=~/.docker-blueprint
EXEC_PATH=$(which docker-blueprint)

if [[ -n $EXEC_PATH ]]; then
    printf "Removing link..."
    sudo rm $EXEC_PATH
    printf " done\n"
fi

if [[ -d "$PROJECT_DIR" ]]; then
    printf "Removing project directory..."
    rm -rf $PROJECT_DIR
    printf " done\n"
fi

echo "Successfuly removed docker-blueprint."
