#!/bin/bash

if [[ -z "$2" ]]; then
    if [[ -z "$DEFAULT_SERVICE" ]]; then
        echo "No default service set"
    else
        echo "Current default service: $DEFAULT_SERVICE"
    fi
    echo ""
    echo "Usage: $EXECUTABLE_NAME default <service>"
else
    if [[ "$2" == "clear" ]]; then
        if [[ -f $DIR/default_service ]]; then
            rm $DIR/default_service
        fi
        echo "Default service cleared"
    else
        SERVICES=$(docker-compose ps --services)
        if [[ ${SERVICES[@]} =~ $2 ]]; then
            echo "$2" > $DIR/default_service
            init_default_service
            echo "Default service set: $2"
        else
            echo "Unknown service '$2'."
            echo "Available services:" "$SERVICES"
        fi
    fi
fi
