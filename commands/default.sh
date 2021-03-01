#!/bin/bash

shift

#
# Read arguments
#

case $1 in
    -h|--help)
        printf "${CMD_COL}default clear${RESET}\t\t\tClear default service\n"
        printf "${CMD_COL}default${RESET} ${ARG_COL}<service>${RESET}\t\tSet default service to run commands against (usually set by the blueprint)\n"
        exit

        ;;
    *)
        SERVICE=$1
esac

if [[ -z "$SERVICE" ]]; then
    if [[ -z "$DEFAULT_SERVICE" ]]; then
        echo "No default service set"
    else
        echo "Current default service: $DEFAULT_SERVICE"
    fi
    echo ""
    echo "Usage: $EXECUTABLE_NAME default <service>"
else
    if [[ "$SERVICE" == "clear" ]]; then
        if [[ -f $DIR/default_service ]]; then
            rm $DIR/default_service
        fi
        echo "Default service cleared"
    else
        SERVICES=$($DOCKER_COMPOSE ps --services)
        if [[ ${SERVICES[@]} =~ $SERVICE ]]; then
            echo "$SERVICE" > $DIR/default_service
            init_default_service
            echo "Default service set: $SERVICE"
        else
            echo "Unknown service '$SERVICE'."
            echo "Available services:" "$SERVICES"
        fi
    fi
fi
