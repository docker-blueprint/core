#!/bin/bash

debug_print() {
    if [[ $DEBUG -eq 1 ]]; then
        prefix="${DEBUG_PREFIX:-DEBUG}"

        # Source: https://stackoverflow.com/a/7265130/2467106
        n=$(md5sum <<<"$prefix") # Get md5 hash of a string
        n=$((0x${n%% *}))        # Convert to base 10
        n=${n#-}                 # Remove negative sign
        ((n = $n % 7 + 1))       # Clamp values to the range [1; 6]
        color="\e[38;5;${n}m"    # Generate color code

        printf "$color[$prefix]$RESET "
        if [[ -n "${2+x}" ]]; then
            printf "$@"
        else
            printf "%s\n" "$1"
        fi
    fi
}
export -f debug_print

non_debug_print() {
    if [[ -z $DEBUG || $DEBUG -eq 0 ]]; then
        printf -- "$1"
    fi
}
export -f non_debug_print

debug_newline_print() {
    if [[ -z $DEBUG || $DEBUG -eq 0 ]]; then
        printf -- "$1"
    elif [[ $DEBUG -eq 1 ]]; then
        printf -- "$1\n"
    fi
}
export -f debug_newline_print
