#!/bin/bash

SUDO="$(which sudo 2>/dev/null)"
PROJECT_DIR=~/.docker-blueprint
EXEC_PATH=$(which docker-blueprint 2>/dev/null)

if [[ -n $EXEC_PATH ]]; then
    printf "Removing link..."
    $SUDO rm -f $EXEC_PATH
    printf " done\n"
fi

EXEC_PATH=$(which dob 2>/dev/null)

if [[ -n $EXEC_PATH ]]; then
    printf "Removing link..."
    $SUDO rm -f $EXEC_PATH
    printf " done\n"
fi

if [[ -d "$PROJECT_DIR" ]]; then
    printf "Removing project directory..."
    rm -rf $PROJECT_DIR
    printf " done\n"
fi

echo "Successfuly removed docker-blueprint."
