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

    if [[ $version =~ ^4 ]]; then
        YQ_INSTALLED=true
    fi
fi

if ! $YQ_INSTALLED; then
    if [[ -z $YQ_WARNING_SHOWN || ! $YQ_WARNING_SHOWN ]] &&
        [[ -z $AS_FUNCTION || ! $AS_FUNCTION ]]; then
        printf "${YELLOW}WARNING${RESET}: It appears that yq (version 4) is not installed locally.\n"
        printf "We are going to use docker version of yq, however it will be much slower.\n"
        printf "Install yq in order to make building faster: ${GREEN}https://github.com/mikefarah/yq#install${RESET}\n"
        printf "=============================================================\n"
    fi

    yq() {
        docker run --rm -i -v "${PWD}":/workdir mikefarah/yq:4 "$@"
    }
fi

export YQ_WARNING_SHOWN=true

yq_merge() {
    yq eval-all '. as $item ireduce ({}; . *+ $item )' $@
}

yq_read_value() {
    if [[ -z "$3" ]]; then
        FILE="$PROJECT_DIR/$PROJECT_BLUEPRINT_FILE"
    else
        FILE="$3"
    fi

    printf -v "$1" "%s" "$(yq eval ".$2 // \"\"" "$FILE" 2>/dev/null)"
}

yq_write_value() {
    if [[ -z "$3" ]]; then
        FILE="$PROJECT_DIR/$PROJECT_BLUEPRINT_FILE"
    else
        FILE="$3"
    fi

    yq eval ".$1 = \"$2\" | .$1 style=\"single\"" -i "$FILE"
}

yq_read_array() {
    if [[ -z "$3" ]]; then
        FILE="$PROJECT_DIR/$PROJECT_BLUEPRINT_FILE"
    else
        FILE="$3"
    fi

    readarray -t "$1" < <(yq eval ".$2[]" "$FILE")
}

yq_read_keys() {
    if [[ -z "$3" ]]; then
        FILE="$PROJECT_DIR/$PROJECT_BLUEPRINT_FILE"
    else
        FILE="$3"
    fi

    readarray -t "$1" < <(cat "$FILE" | yq eval ".$2 // []" - | yq eval "keys" - | yq eval ".[]" -)
}
