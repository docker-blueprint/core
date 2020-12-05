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
            printf "${CMD_COL}up${RESET} [${FLG_COL}-d${RESET}]"
            printf "\t\t\tBring up docker containers (in detached mode) and reinitialize them\n"

            exit

            ;;

        *)
            DOCKER_COMPOSE_UP_ARGS+=($1)
    esac

    shift
done

docker-compose ${DOCKER_COMPOSE_ARGS[@]} up -d ${DOCKER_COMPOSE_UP_ARGS[@]}

bash $ENTRYPOINT sync
