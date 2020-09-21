#!/bin/bash

shift

case $1 in
    -h|--help)
        printf "version\t\t\tGet current version\n"
        exit

        ;;
esac

if  ! $AS_FUNCTION; then
    printf "Current version: "
fi

PREVIOUS_DIR=$PWD

cd $ROOT_DIR

printf $(git describe --match "v*" --abbrev=0 --tags)
printf "\n"

cd $PREVIOUS_DIR
