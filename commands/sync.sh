#!/bin/bash

shift

#
# Read arguments
#

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            printf "${CMD_COL}sync${RESET} [${FLG_COL}options${RESET}]"
            printf "\t\tSynchronize development environment container\n"

            exit

            ;;
    esac

    shift
done

read_value SYNC_USER "user"
read_array MAKE_DIRS "make_dirs"
read_array POSTBUILD_COMMANDS "postbuild_commands"

#
# Synchronize container user with the current host
#

if [[ -n "$SYNC_USER" ]]; then
    echo "Synchronizing user '$SYNC_USER'..."
    docker-compose exec "$DEFAULT_SERVICE" usermod -u "$UID" "$SYNC_USER"
    docker-compose exec "$DEFAULT_SERVICE" groupmod -g "$GID" "$SYNC_USER"

    HOME_DIR="$(docker-compose exec --user="$SYNC_USER" "$DEFAULT_SERVICE" env | grep '^HOME=' | sed -r 's/^HOME=(.*)/\1/' | sed 's/\r//' | sed 's/\n//')"

    echo "Chowning home directory '$HOME_DIR'..."

    docker-compose exec "$DEFAULT_SERVICE" chown -R "$SYNC_USER" "$HOME_DIR"
fi

if [[ -n "$MAKE_DIRS" ]]; then
    for dir in "${MAKE_DIRS[@]}"; do
        echo "Making directory '$dir'..."
        docker-compose exec "$DEFAULT_SERVICE" mkdir -p "$dir"
        if [[ -n "$SYNC_USER" ]]; then
            docker-compose exec "$DEFAULT_SERVICE" chown -R "$SYNC_USER" "$dir"
        fi
    done
fi

for command in "${POSTBUILD_COMMANDS[@]}"; do
    echo "Running '$command'..."
    if [[ -z "$SYNC_USER" ]]; then
        docker-compose exec "$DEFAULT_SERVICE" $command
    else
        docker-compose exec --user="$SYNC_USER" "$DEFAULT_SERVICE" $command
    fi
done

#
# Restart container to apply chown
#

echo "Restarting container '$DEFAULT_SERVICE'..."
docker-compose restart "$DEFAULT_SERVICE"
