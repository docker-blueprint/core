#!/bin/bash

shift

#
# Read arguments
#

DOCKER_COMPOSE_ARGS=()
DOCKER_COMPOSE_UP_ARGS=()

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            printf "${CMD_COL}up${RESET} [${FLG_COL}options${RESET}]"
            printf "\t\t\t"
            printf "Bring up docker containers and reinitialize them\n"
            printf "\t\t\t\t"
            printf "You can use any of the options options for a regular docker-compose command\n"

            exit

            ;;

        *)
            DOCKER_COMPOSE_UP_ARGS+=($1)
    esac

    shift
done

$DOCKER_COMPOSE ${DOCKER_COMPOSE_ARGS[@]} up -d ${DOCKER_COMPOSE_UP_ARGS[@]}

if [[ $? > 0 ]]; then
    exit 1
fi

bash $ENTRYPOINT sync
