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
            printf "\t\t\tDo not attempt to chown home directory\n"
            printf "\t\t\t\t(useful when there are a lot of local files)\n"

            exit

            ;;
        --no-chown)
            MODE_NO_CHOWN=true

            ;;
    esac

    shift
done

yq_read_value SYNC_USER "user"
yq_read_array MAKE_DIRS "make_dirs"
yq_read_array POSTBUILD_COMMANDS "postbuild_commands"

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

if [[ -n "$MAKE_DIRS" ]]; then
    for dir in "${MAKE_DIRS[@]}"; do
        echo "Making directory '$dir'..."
        $DOCKER_COMPOSE exec "$DEFAULT_SERVICE" mkdir -p "$dir"
        if [[ -n "$SYNC_USER" ]]; then
            $DOCKER_COMPOSE exec "$DEFAULT_SERVICE" chown -R "$SYNC_USER" "$dir"
        fi
    done
fi

for command in "${POSTBUILD_COMMANDS[@]}"; do
    if [[ -z "$SYNC_USER" ]]; then
        echo "Running '$command'..."
        $DOCKER_COMPOSE exec "$DEFAULT_SERVICE" $command
    else
        echo "Running '$command' as user '$SYNC_USER'..."
        $DOCKER_COMPOSE exec --user="$SYNC_USER" "$DEFAULT_SERVICE" $command
    fi
done

#
# Restart container to apply chown
#

if ! $MODE_NO_CHOWN;  then
    echo "Restarting container '$DEFAULT_SERVICE'..."
    $DOCKER_COMPOSE restart "$DEFAULT_SERVICE"
fi
