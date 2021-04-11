#!/bin/bash

shift

MODE_FORCE=false
MODE_QUIET=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
    -h | --help)
        printf "${CMD_COL}environment ${ARG_COL}<name> | clear${RESET}"
        printf "\tSet or clear current specified environemnt\n"
        exit

        ;;
    -f | --force)
        MODE_FORCE=true

        ;;
    -q | --quiet)
        MODE_QUIET=true

        ;;
    *)
        ENVIRONMENT=$1
        ;;
    esac

    shift
done

if [[ "$ENVIRONMENT" != "clear" ]]; then
    source "$ROOT_DIR/includes/blueprint/populate_env.sh" ""

    if [[ -z "$ENVIRONMENT" ]]; then
        if [[ -d "$BLUEPRINT_DIR/env" ]]; then
            printf "${GREEN}%s${RESET}:\n" "Available environments"

            for environment in $BLUEPRINT_DIR/env/*; do
                printf -- "- %s\n" "${environment#"$BLUEPRINT_DIR/env/"}"
            done
        else
            printf "The blueprint '${YELLOW}$BLUEPRINT_QUALIFIED_NAME${RESET}' has no environments.\n"
        fi

        exit 1
    fi

    if [[ ! -d "$BLUEPRINT_DIR/env/$ENVIRONMENT" ]]; then
        printf "${RED}ERROR${RESET}: No such environment '$ENVIRONMENT'.\n"
        exit 1
    fi

    yq_write_value "environment" "$ENVIRONMENT"
else
    yq eval "del(.environment)" -i "$PROJECT_BLUEPRINT_FILE"
fi

if ! $MODE_QUIET; then
    if ! $MODE_FORCE; then
        printf "Do you want to rebuild the project? (run with ${FLG_COL}--force${RESET} to always build)\n"
        printf "${YELLOW}WARNING${RESET}: This will ${RED}overwrite${RESET} existing docker files [y/N] "
        read -n 1 -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            bash $ENTRYPOINT build --force
        fi
    else
        bash $ENTRYPOINT build --force
    fi
fi
