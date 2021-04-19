#!/bin/bash

shift

case $1 in
-h | --help)
    printf "${CMD_COL}version${RESET} [change ${ARG_COL}<pathspec>${RESET}]"
    printf "\tGet current version or switch version to <pathspec>\n"
    exit
    ;;
change)
    NEW_VERSION="$2"

    if [[ -z "$NEW_VERSION" ]]; then
        printf "${RED}ERROR${RESET}: pathspec must not be empty\n"
        bash $ENTRYPOINT version -h
        exit 1
    fi
    ;;
esac

PREVIOUS_DIR=$PWD

cd $ROOT_DIR

if [[ -n "$NEW_VERSION" ]]; then
    git checkout "$NEW_VERSION"
    if [[ $? > 0 ]]; then
        exit 1
    fi
fi

if ! $AS_FUNCTION; then
    printf "Current version: "
fi

printf "$(git describe --match "v*" --abbrev=0 --tags)"
printf " ($(git rev-parse --short HEAD))"

if ! $AS_FUNCTION; then
    printf "\n"
fi

cd $PREVIOUS_DIR
