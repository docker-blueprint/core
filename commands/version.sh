#!/bin/bash

if  ! $AS_FUNCTION; then
    printf "Current version: "
fi

printf $(git describe --match "v*" --abbrev=0 --tags)
printf "\n"
