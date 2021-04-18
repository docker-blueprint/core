#!/bin/bash

shift

case $1 in
-h | --help)
    printf "${CMD_COL}version${RESET}\t\t\tGet current version\n"
    exit

    ;;
esac

if ! $AS_FUNCTION; then
    printf "Current version: "
fi

PREVIOUS_DIR=$PWD

cd $ROOT_DIR

printf "$(git describe --match "v*" --abbrev=0 --tags)"
printf " ($(git rev-parse --short HEAD))"

if ! $AS_FUNCTION; then
    printf "\n"
fi

cd $PREVIOUS_DIR
