#!/bin/bash

debug_switch_context "SYNC"

debug_print "Running the command..."

shift

#
# Read arguments
#

MODE_NO_CHOWN=false
MODE_SKIP_USER=false
MODE_SKIP_ENV=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
    -h | --help)
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
    --skip-user)
        MODE_SKIP_USER=true
        ;;
    --skip-env)
        MODE_SKIP_ENV=true
        ;;
    esac

    shift
done

yq_read_value SYNC_USER "user"

#
# Synchronize container user with the current host
#

if ! $MODE_SKIP_USER && [[ -n "$SYNC_USER" ]]; then
    debug_print "SYNC_USER is defined"

    echo "Synchronizing user '$SYNC_USER'..."

    echo "Setting UID to $UID..."
    $DOCKER_COMPOSE exec "$DEFAULT_SERVICE" usermod -u "$UID" "$SYNC_USER"

    if ! $MODE_NO_CHOWN; then
        HOME_DIR="$($DOCKER_COMPOSE exec --user="$SYNC_USER" "$DEFAULT_SERVICE" env | grep '^HOME=' | sed -r 's/^HOME=(.*)/\1/' | sed 's/\r//' | sed 's/\n//')"
        if [[ -n "$HOME_DIR" ]]; then
            echo "Recursively chowning home directory '$HOME_DIR'..."
            $DOCKER_COMPOSE exec "$DEFAULT_SERVICE" chown -R "$SYNC_USER" "$HOME_DIR"
        else
            printf "${YELLOW}WARNING${RESET}: Unable to detect home directory.\n"
            echo "Is HOME defined inside the container?"
        fi
    fi
fi

if ! $MODE_SKIP_ENV && [[ -f .env ]]; then
    debug_print "Found .env file in the project directory"
    debug_print "Looking for docker-compose files..."

    files=(
        docker-compose.$PROJECT_CONTEXT.y*ml
        docker-compose.y*ml
    )

    temp_file="$TEMP_DIR/docker-compose.env"
    touch "$temp_file"

    for file in ${files[@]}; do
        if [[ ! -f "$file" ]]; then
            continue
        fi

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

    temp_env_file="$TEMP_DIR/.env"
    cp -f ".env" "$temp_env_file"

    for variable in "${VARIABLES[@]}"; do
        value="$(yq eval ".services.*.environment.\"$variable\" // \"\"" "$temp_file")"
        # remove leading whitespace characters
        value="${value#"${value%%[![:space:]]*}"}"
        # remove trailing whitespace characters
        value="${value%"${value##*[![:space:]]}"}"

        # Check if value is a substituion
        if [[ "$value" =~ "$" ]]; then
            debug_print "Value of variable '$variable' is a substitution - replacing..."
            value="$(echo "$value" | sed -E 's/\$\{.+:\-(.*)\}/\1/')"
            debug_print "${RED}>>>${RESET} %s\n" "$value"
        fi

        while read -r line || [[ -n "$line" ]]; do
            # Parse each line into the parts before and after equal sign
            before="${line%=*}"
            after="${line#*=}"

            if [[ "$before" = "$variable" ]]; then
                if [[ "$after" =~ "#" ]]; then
                    # Check if there is already a comment on this line
                    debug_print "Variable '$variable' has a comment - skipping"
                elif [[ "$after" = "$value" ]]; then
                    # Check if the value is the same
                    debug_print "Variable '$variable' has the same value - skipping"
                elif [[ "$value" =~ "$" ]]; then
                    # Check if value is a substituion
                    debug_print "Variable '$variable' value is a substitution - skipping"
                else
                    debug_print "Setting '$variable' to '$value'"
                    echo "$before=$value # Value replaced by docker-blueprint: $after" >&2
                    continue
                fi
            fi

            echo "$line" >&2
        done <"$temp_env_file" 2>"$temp_env_file.copy"

        mv -f "$temp_env_file.copy" "$temp_env_file"
    done

    cp -f "$temp_env_file" ".env"

    rm -f "$temp_env_file"
    rm -f "$temp_file"

    echo "Commented environment variables used by docker-compose"
fi

#
# Restart container to apply chown
#

if ! $MODE_NO_CHOWN; then
    echo "Restarting container '$DEFAULT_SERVICE'..."
    $DOCKER_COMPOSE restart "$DEFAULT_SERVICE"
fi
