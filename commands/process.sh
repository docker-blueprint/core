#!/bin/bash

# Blueprint PROCESS command
#
# This command preprocesses dockerfile templates that are used in blueprints:
#
# 1) Substitutes all environment variables prefixed with BLUEPRINT_ and
#    uncomments the lines where they are used if such variable is defined.
#    Blueprint variables have a different symbol in front of them in order
#    to distinguish them from build arguments during the build.
#
#    For example the following input:
#
#    > # RUN echo "%BLUEPRINT_DIR" # this is a dockerfile template
#
#    Produces this output, since BLUEPRINT_DIR is always defined:
#
#    > RUN echo ".docker-blueprint/<path-to-the-blueprint-root>"
#
# 2) Processes docker blueprint specific directives:
#    - `#include <resource>`
#
#      Include a dockerfile _partial_ inside the current dockerfile template.
#      Resource path can include blueprint variables. In this case they are
#      resolved before trying to include the file.
#
#      If the file specified doesn't exist, then the line with this directive
#      is removed from the final file.
#
#      Before inserting, the content of the file is also processed by this
#      command. Because of this nested includes are possible.
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

temp_file="$DOCKERFILE.tmp"

# Parse dockerfile directives

rm -f "$temp_file" && touch "$temp_file"
while read -r line || [[ -n "$line" ]]; do
    result="$(parse_directive "$line")"
    if [[ $? -eq 0 ]]; then
        echo "$result" >> "$temp_file"
    fi

    ! $AS_FUNCTION && non_debug_print "."
done <"$OUTPUT_FILE"
# https://stackoverflow.com/a/4160535/2467106

mv -f "$temp_file" "$OUTPUT_FILE"

# Substitute blueprint variables

rm -f "$temp_file" && touch "$temp_file"
while read -r line || [[ -n "$line" ]]; do
    echo "$(substitute_vars "$line")" >> "$temp_file"

    ! $AS_FUNCTION && non_debug_print "."
done <"$OUTPUT_FILE"

mv -f "$temp_file" "$OUTPUT_FILE"
rm -f "$temp_file"

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
