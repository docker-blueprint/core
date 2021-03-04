#!/bin/bash

substitute_vars() {
    source "$ROOT_DIR/includes/preprocessor/substitute-vars.sh" "$1"
}

# Line starts with a comment symbol with a non-whitespace
# symbol following right after it, so it can potentially be a directive.
if [[ "$(echo "$1" | cut -c1)" = "#" && "$(echo "$1" | cut -c2)" != " " ]]; then
    # Strip comment symbol from the beginning of the string
    INPUT="$(echo "$1" | cut -c2-)"
    IFS=' ' read -r -a items <<<$INPUT

    if [[ "${items[0]}" = "include" ]]; then
        resource_path="$(substitute_vars "${items[1]}")"
        file="$(AS_FUNCTION=true bash $ENTRYPOINT process "$resource_path")"

        if [[ -f $file ]]; then
            printf "%s" "$(cat $file)"
            rm -f "$file" # Clean up after processing
            export PARSER_VARIABLE=Fanter
            exit # The given path was read successfully
        fi

        exit 1 # Unable to include the given path
    fi
fi

printf "%s" "$1"
