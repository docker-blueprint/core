#!/bin/bash

shift

#
# Read arguments
#

ARGS=()
MODE_SYNC=false
SYNC_ARGS=()
MODE_NO_BUILD=false
BUILD_ARGS=()

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            printf "${CMD_COL}up${RESET} [${FLG_COL}options${RESET}]"
            printf "\t\t\t"
            printf "Bring up docker containers and initialize them\n"
            printf "\t\t\t\t"
            printf "You can use any of the options options for a regular docker-compose command\n"

            printf "  ${FLG_COL}--sync${RESET}"
            printf "\t\t\tAttempt to sync service container with the local environment\n"

            printf "  ${FLG_COL}--no-chown${RESET}"
            printf "\t\t\tPass --no-chown to 'sync' command\n"

            printf "  ${FLG_COL}--no-build${RESET}"
            printf "\t\t\tDon't attempt to build the blueprint\n"

            printf "  ${FLG_COL}-f${RESET}, ${FLG_COL}--force${RESET}"
            printf "\t\t\tPass --force to 'build' command\n"
            printf "\t\t\t\tThis will force to regenerate new docker files\n"
            printf "\t\t\t\tpotentially overwriting current ones\n"

            exit

            ;;
        -f|--force)
            BUILD_ARGS+=('--force')

            ;;
        --no-build)
            MODE_NO_BUILD=true

            ;;
        --no-chown)
            SYNC_ARGS+=('--no-chown')

            ;;
        --sync)
            MODE_SYNC=true

            ;;
        *)
            ARGS+=($1)
    esac

    shift
done

if ! $MODE_NO_BUILD; then
    bash $ENTRYPOINT build ${BUILD_ARGS[@]}
fi

eval "$DOCKER_COMPOSE up -d --remove-orphans ${ARGS[@]}"

if [[ $? > 0 ]]; then
    exit 1
fi

if $MODE_SYNC; then
    bash $ENTRYPOINT sync ${SYNC_ARGS[@]}
fi
