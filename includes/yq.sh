#!/bin/bash

# Substitue yq with a docker container version,
# if it isn't already present in the system.
#
# This affects performance, but allows to run docker-blueprint
# without installing external dependencies.

which yq > /dev/null

if [[ $? > 0 ]]; then
    yq() {
        docker run --rm -i -v "${PWD}":/workdir mikefarah/yq yq "$@"
    }
fi

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
