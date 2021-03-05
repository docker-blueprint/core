#!/bin/bash

debug_print() {
    if [[ $DEBUG -eq 1 ]]; then
        printf -- "${PURPLE}DEBUG${RESET}: $1\n"
    fi
}

non_debug_print() {
    if [[ -z $DEBUG || $DEBUG -eq 0 ]]; then
        printf -- "$1"
    fi
}

debug_newline_print() {
    if [[ -z $DEBUG || $DEBUG -eq 0 ]]; then
        printf -- "$1"
    elif [[ $DEBUG -eq 1 ]]; then
        printf -- "$1\n"
    fi
}
