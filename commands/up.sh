#!/bin/bash

DEBUG_PREFIX="UP"

debug_print "Running the command..."

shift

#
# Read arguments
#

ARGS=()
MODE_SYNC=false
SYNC_ARGS=()
MODE_NO_BUILD=false
BUILD_ARGS=()

MODE_NO_SCRIPTS=false
MODE_SCRIPTS_ONLY=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
    -h | --help)
        printf "${CMD_COL}up${RESET} [${FLG_COL}options${RESET}]"
        printf "\t\t\t"
        printf "Bring up docker containers and initialize them\n"
        printf "\t\t\t\t"
        printf "You can use any of the options options for a regular docker-compose command\n"

        printf "  ${FLG_COL}--sync${RESET}"
        printf "\t\t\tAttempt to sync service container with the local environment\n"

        printf "  ${FLG_COL}--no-chown${RESET}"
        printf "\t\t\tPass --no-chown to 'sync' command\n"

        printf "  ${FLG_COL}--no-build${RESET}"
        printf "\t\t\tDon't attempt to build the blueprint\n"

        printf "  ${FLG_COL}--no-scripts${RESET}"
        printf "\t\tDon't attempt to run scripts\n"

        printf "  ${FLG_COL}--scripts-only${RESET}"
        printf "\t\tOnly run scripts - don't attempt to bring up the containers\n"

        printf "  ${FLG_COL}--no-cache${RESET}"
        printf "\t\t\tDon't use docker image cache\n"

        printf "  ${FLG_COL}-f${RESET}, ${FLG_COL}--force${RESET}"
        printf "\t\t\tPass --force to 'build' command\n"
        printf "\t\t\t\tThis will force to regenerate new docker files\n"
        printf "\t\t\t\tpotentially overwriting current ones\n"

        exit
        ;;
    -f | --force)
        BUILD_ARGS+=('--force')
        ;;
    --no-build)
        MODE_NO_BUILD=true
        ;;
    --no-cache)
        BUILD_ARGS+=("--no-cache")
        ;;
    --no-scripts)
        MODE_NO_SCRIPTS=true
        ;;
    --scripts-only)
        MODE_SCRIPTS_ONLY=true
        ;;
    --no-chown)
        SYNC_ARGS+=('--no-chown')
        ;;
    --sync)
        MODE_SYNC=true
        ;;
    --skip-compose | --no-compose)
        BUILD_ARGS+=("--skip-compose")
        ;;
    --skip-dockerfile | --no-dockerfile)
        BUILD_ARGS+=("--skip-dockerfile")
        ;;
    *)
        ARGS+=($1)
        ;;
    esac

    shift
done

if ! $MODE_SCRIPTS_ONLY;  then
    if ! $MODE_NO_BUILD; then
        bash $ENTRYPOINT build ${BUILD_ARGS[@]}

        if [[ $? > 0 ]]; then
            exit 1
        fi
    fi

    eval "$DOCKER_COMPOSE up -d --remove-orphans ${ARGS[@]}"

    if [[ $? > 0 ]]; then
        exit 1
    fi

    if $MODE_SYNC; then
        bash $ENTRYPOINT sync ${SYNC_ARGS[@]}
    fi
fi

script_paths=()

source "$ROOT_DIR/includes/blueprint/populate_env.sh" ""

# Add base blueprint module scripts first
path="$BLUEPRINT_DIR/scripts/up.$PROJECT_CONTEXT.sh"
if [[ -f "$path" ]]; then
    script_paths+=("$path")
fi

# Then add environment module scripts
path="$ENV_DIR/scripts/up.$PROJECT_CONTEXT.sh"
if [[ -f "$path" ]]; then
    script_paths+=("$path")
fi

status=0

if ! $MODE_NO_SCRIPTS; then
    printf "Running up scripts for ${YELLOW}$PROJECT_CONTEXT${RESET} context...\n"

    for path in "${script_paths[@]}"; do
        debug_print "Running script: ${path#$BLUEPRINT_DIR/}"

        PROGRAM="$(source "$ROOT_DIR/includes/script/prepare.sh" "$(cat "$path")")"

        command="bash -c \"$PROGRAM\""
        bash $ENTRYPOINT $DEFAULT_SERVICE exec "$command"

        status=$?

        if [[ $status > 0 ]]; then
            break
        fi
    done
fi

if [[ $status > 0 ]]; then
    printf -- "${RED}ERROR${RESET}: Up script returned non-zero code: ${path#$BLUEPRINT_DIR/}\n"
    exit $status
fi
