#!/bin/bash

# Substitue yq with a docker container version,
# if it isn't already present in the system.
#
# This affects performance, but allows to run docker-blueprint
# without installing external dependencies.

YQ_INSTALLED=false

which yq > /dev/null

if [[ $? -eq 0 ]]; then
    version=$(yq --version | sed -E 's/.+\s([[:digit:]])/\1/')

    if [[ $version =~ ^3 ]]; then
        YQ_INSTALLED=true
    fi
fi

if ! $YQ_INSTALLED; then
    if [[ -z $YQ_WARNING_SHOWN || ! $YQ_WARNING_SHOWN ]] &&
        [[ -z $AS_FUNCTION || ! $AS_FUNCTION ]]; then
        printf "${YELLOW}WARNING${RESET}: It appears that yq (version 3) is not installed locally.\n"
        printf "We are going to use docker version of yq, however it will be much slower.\n"
        printf "Install yq in order to improve performance: ${GREEN}https://github.com/mikefarah/yq#install${RESET}\n"
    fi

    yq() {
        docker run --rm -i -v "${PWD}":/workdir mikefarah/yq:3 yq "$@"
    }
fi

export YQ_WARNING_SHOWN=true

read_value() {
    if [[ -z "$3" ]]; then
        FILE="$BLUEPRINT_FILE_FINAL"
    else
        FILE="$3"
    fi

    printf -v "$1" "$(yq read "$FILE" "$2" 2>/dev/null)"
}

read_array() {
    if [[ -z "$3" ]]; then
        FILE="$BLUEPRINT_FILE_FINAL"
    else
        FILE="$3"
    fi

    readarray -t "$1" < <(yq read "$FILE" "$2[*]")
}

read_keys() {
    if [[ -z "$3" ]]; then
        FILE="$BLUEPRINT_FILE_FINAL"
    else
        FILE="$3"
    fi

    readarray -t "$1" < <(yq read "$FILE" "$2" --tojson | \
                        jq -r '. | keys[]')
}
