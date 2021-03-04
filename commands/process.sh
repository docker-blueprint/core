#!/bin/bash

# Blueprint PROCESS command
#
# This command preprocesses dockerfile templates that are used in blueprints:
#
# 1) Substitutes all _special variables_ and uncomments the lines where they
#    are used. If the variable is empty, the commented line is removed.
# 2) Processes docker blueprint specific DIRECTIVES:
#    - `#include <resource>`
#
#      Include a dockerfile `partial` inside the current dockerfile template.
#      Together with conditional expressions this allows to mix and match
#      multiple parts of the dockerfile depending on currently active modules.
#
#      The `<resource>` here is...
#
#    - `#ifdef`
#

shift

#
# Read arguments
#

MODE_INLINE=false

if [[ -z "$1" ]]; then
    printf "Usage:\n"
    bash $ENTRYPOINT process --help
    exit 1
fi

while [[ "$#" -gt 0 ]]; do
    case $1 in
    -h | --help)
        printf "${CMD_COL}process${RESET} [${FLG_COL}options${RESET}] ${ARG_COL}<path>${RESET}"
        printf "\t"
        printf "Preprocess dockerfile template from the blueprint\n"

        printf "  ${FLG_COL}-i${RESET}, ${FLG_COL}--inline${RESET}"
        printf "\t\tOutput processed file to STDOUT instead of saving a copy with .out suffix\n"

        exit

        ;;
    -i | --inline)
        MODE_INLINE=true
        AS_FUNCTION=true
        ;;
    *)

        if [[ -z $DOCKERFILE ]]; then
            DOCKERFILE=$1
        fi
        ;;
    esac

    shift
done

#
# Initialize preprocessor for the file
#

if $AS_FUNCTION; then
    MODE_QUIET=true
fi

if ! $AS_FUNCTION; then
    printf "Processing $(basename $DOCKERFILE)..."
fi

if [[ ! -f $DOCKERFILE ]]; then
    if ! $AS_FUNCTION; then
        printf "\n${RED}ERROR${RESET}: Cannot find $DOCKERFILE\n"
    fi
    exit 1
fi

OUTPUT_FILE="$DOCKERFILE.out"

cp -f "$DOCKERFILE" "$OUTPUT_FILE"

# Process the dockerfile

parse_directive() {
    source "$ROOT_DIR/includes/preprocessor/parse-directive.sh" "$1"
}

substitute_vars() {
    source "$ROOT_DIR/includes/preprocessor/substitute-vars.sh" "$1"
}

# Parse dockerfile directives

while read -r line || [[ -n "$line" ]]; do
    result="$(parse_directive "$line")"
    if [[ $? -eq 0 ]]; then
        echo "$result"
    fi
done <"$OUTPUT_FILE" >"$OUTPUT_FILE.tmp"
# https://stackoverflow.com/a/4160535/2467106

mv -f "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"

# Substitute blueprint variables

while read -r line || [[ -n "$line" ]]; do
    echo "$(substitute_vars "$line")"
done <"$OUTPUT_FILE" >"$OUTPUT_FILE.tmp"

mv -f "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"

if ! $AS_FUNCTION; then
    printf " ${GREEN}done${RESET}\n"
fi

if $MODE_INLINE; then
    echo "$(cat "$OUTPUT_FILE")"
    rm -f "$OUTPUT_FILE"
else
    if $AS_FUNCTION; then
        printf "%s" "$OUTPUT_FILE"
    fi
fi
