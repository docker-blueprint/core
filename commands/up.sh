#!/bin/bash

shift

#
# Read arguments
#

ARGS=()
SYNC_ARGS=()

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            printf "${CMD_COL}up${RESET} [${FLG_COL}options${RESET}]"
            printf "\t\t\t"
            printf "Bring up docker containers and initialize them\n"
            printf "\t\t\t\t"
            printf "You can use any of the options options for a regular docker-compose command\n"

            printf "  ${FLG_COL}--no-chown${RESET}"
            printf "\t\t\tPass --no-chown to 'sync' command\n"

            exit

            ;;
        --no-chown)
            SYNC_ARGS+=('--no-chown')

            ;;
        *)
            ARGS+=($1)
    esac

    shift
done

eval "$DOCKER_COMPOSE up -d ${ARGS[@]}"

if [[ $? > 0 ]]; then
    exit 1
fi

bash $ENTRYPOINT sync ${SYNC_ARGS[@]}
