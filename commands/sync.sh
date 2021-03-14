#!/bin/bash

shift

#
# Read arguments
#

MODE_NO_CHOWN=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            printf "${CMD_COL}sync${RESET}"
            printf "\t\t\t\t"
            printf "Synchronize development environment container\n"

            printf "  ${FLG_COL}--no-chown${RESET}"
            printf "\t\t\tDo not attempt to chown home directory (i.e. when there are a lot of local files)\n"

            exit

            ;;
        --no-chown)
            MODE_NO_CHOWN=true

            ;;
    esac

    shift
done

yq_read_value SYNC_USER "user"

#
# Synchronize container user with the current host
#

if [[ -n "$SYNC_USER" ]]; then
    echo "Synchronizing user '$SYNC_USER'..."
    $DOCKER_COMPOSE exec "$DEFAULT_SERVICE" usermod -u "$UID" "$SYNC_USER"

    if ! $MODE_NO_CHOWN;  then
        HOME_DIR="$($DOCKER_COMPOSE exec --user="$SYNC_USER" "$DEFAULT_SERVICE" env | grep '^HOME=' | sed -r 's/^HOME=(.*)/\1/' | sed 's/\r//' | sed 's/\n//')"
        if [[ -n "$HOME_DIR" ]];  then
            echo "Recursively chowning home directory '$HOME_DIR'..."
            $DOCKER_COMPOSE exec "$DEFAULT_SERVICE" chown -R "$SYNC_USER" "$HOME_DIR"
        else
            printf "${YELLOW}WARNING${RESET}: Unable to detect home directory.\n"
            echo "Is HOME defined inside the container?"
        fi
    fi
fi

#
# Restart container to apply chown
#

if ! $MODE_NO_CHOWN;  then
    echo "Restarting container '$DEFAULT_SERVICE'..."
    $DOCKER_COMPOSE restart "$DEFAULT_SERVICE"
fi
