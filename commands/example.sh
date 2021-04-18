#!/bin/bash

shift

while [[ "$#" -gt 0 ]]; do
    case $1 in
    -h | --help)
        printf "${CMD_COL}example${RESET} ${ARG_COL}<name>${RESET}"
        printf "\t\tShow technology-specific usage example\n"

        exit
        ;;
    *)
        EXAMPLE_NAME=$1
        ;;
    esac

    shift
done

if [[ -z "$EXAMPLE_NAME" ]]; then
    bash $ENTRYPOINT example -h
fi

FILES=("$ROOT_DIR/examples/"*.sh)

EXAMPLES_LIST=()

for file in "${FILES[@]}"; do
    name=$(basename "$file" .sh)

    number=$(echo $name | cut -d'-' -f1 | sed 's/^0*//')
    title=$(echo $name | cut -d'-' -f2)

    case $EXAMPLE_NAME in
    "$number" | "$title")
        printf "\n"
        eval "$(cat "$file")"
        printf "\n"
        exit
        ;;
    *)
        EXAMPLES_LIST+=("$title")
        ;;
    esac
done

printf "${GREEN}Available examples:${RESET}\n"

for example in ${EXAMPLES_LIST[@]}; do
    printf -- "- %s\n" "$example"
done

exit 1
