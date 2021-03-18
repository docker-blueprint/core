#!/bin/bash

DEBUG_PREFIX="SYNC"

debug_print "Running the command..."

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
    debug_print "SYNC_USER is defined"

    echo "Synchronizing user '$SYNC_USER'..."

    echo "Setting UID to $UID..."
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

if [[ -f .env ]]; then
    debug_print "Found .env file in the project directory"
    debug_print "Looking for docker-compose files..."

    temp_file="$TEMP_DIR/docker-compose.env"
    for file in docker-compose*; do
        debug_print "Found file: $file"

        if [[ ! -f "$temp_file" ]]; then
            debug_print "$temp_file doesn't exist - copying the first file..."
            cp -f "$file" "$temp_file"
        else
            debug_print "$temp_file exists - merging files..."
            printf -- "$(yq_merge $temp_file $file)" >"$temp_file"
        fi
    done

    readarray -t VARIABLES < <(yq eval '.services.*.environment | select(. != null) | keys | .[]' "$temp_file")

    for variable in "${VARIABLES[@]}"; do
        debug_print "Commenting '$variable'..."

        v="${variable#'environment.'}" \
            perl -i -pe 's/^(?!#)(\s*$ENV{v})/# $1/' .env
    done

    rm -f "$temp_file"

    echo "Commented environment variables used by docker-compose"
fi

#
# Restart container to apply chown
#

if ! $MODE_NO_CHOWN;  then
    echo "Restarting container '$DEFAULT_SERVICE'..."
    $DOCKER_COMPOSE restart "$DEFAULT_SERVICE"
fi
