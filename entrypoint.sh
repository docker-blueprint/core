#!/bin/bash

EXECUTABLE_NAME=$(basename "${BASH_SOURCE}")

PROJECT_DIR=$PWD
[[ -z $PROJECT_NAME ]] && PROJECT_NAME=$(basename $PROJECT_DIR)
DIR=.docker-blueprint
REAL_DIR="$(readlink -f "$0")"
ROOT_DIR="$(dirname "$REAL_DIR")"
LOCAL_DIR="$PROJECT_DIR/$DIR"
TEMP_DIR="$LOCAL_DIR/tmp"
ENTRYPOINT="$ROOT_DIR/$(basename "$REAL_DIR")"
BLUEPRINT_FILE_FINAL=docker-blueprint.yml

mkdir -p $DIR
source "$ROOT_DIR/includes/update-gitignore.sh"

if [[ -z $UID ]]; then
    UID=$(id -u)
fi

if [[ -z "$GID" ]]; then
    GID=$(id -g)
fi

source "$ROOT_DIR/includes/colors.sh"
source "$ROOT_DIR/includes/debug.sh"
source "$ROOT_DIR/includes/yq.sh"

if [[ -f "$BLUEPRINT_FILE_FINAL" ]]; then
    [[ -z $PROJECT_CONTEXT ]] && \
    yq_read_value PROJECT_CONTEXT "project.context" "$BLUEPRINT_FILE_FINAL"

    yq_read_value name "project.name" "$BLUEPRINT_FILE_FINAL"
    [[ -n $name ]] && export PROJECT_NAME="$name"
fi

source "$ROOT_DIR/includes/entrypoint/init-compose.sh"

init_default_service() {
    DEFAULT_SERVICE=$(cat $DIR/default_service 2>/dev/null)

    if [[ -z $DEFAULT_SERVICE ]] && [[ -f "$BLUEPRINT_FILE_FINAL" ]]; then
        yq_read_value DEFAULT_SERVICE "default_service" "$BLUEPRINT_FILE_FINAL"
        echo "$DEFAULT_SERVICE" > "$DIR/default_service"
    fi
}

if [[ -z "$DEFAULT_SERVICE" ]]; then
    init_default_service
fi

if [[ -f "$ROOT_DIR/commands/$1.sh" ]]; then
    if [[ -z $AS_FUNCTION ]]; then
        AS_FUNCTION=false
    fi

    source "$ROOT_DIR/commands/$1.sh"
    exit
fi

MODE_NO_TTY=false

if [[ $# -eq 0 ]]; then
    source "$ROOT_DIR/commands/help.sh"
    exit
fi

while [[ "$#" -gt 0 ]]; do
    case $1 in
        start | stop | restart | down)
            $DOCKER_COMPOSE "$1" ${@:2}
            exit
            ;;

        -h | --help)
            source "$ROOT_DIR/commands/help.sh"
            exit
            ;;

        -v | --version)
            AS_FUNCTION=false
            source "$ROOT_DIR/commands/version.sh"
            exit
            ;;

        -T)
            MODE_NO_TTY=true
            ;;

        *)
            if [[ ! -z "$1" ]]; then
                COMMAND=("$DOCKER_COMPOSE exec")

                if $MODE_NO_TTY; then
                    COMMAND+=("-T")
                fi

                if [[ ! -z "$2" ]] && [[ "$2" == "sudo" ]]; then
                    COMMAND+=("$1 ${@:3}")
                elif [[ "$1" == "sudo" ]]; then
                    COMMAND+=("$DEFAULT_SERVICE ${@:2}")
                elif [[ ! -z "$2" ]] && [[ "$2" == "exec" ]]; then
                    COMMAND+=("--user=$UID:$GID $1 ${@:3}")
                elif [[ "$1" == "exec" ]]; then
                    COMMAND+=("--user=$UID:$GID $DEFAULT_SERVICE ${@:2}")
                else
                    COMMAND+=("--user=$UID:$GID $DEFAULT_SERVICE ${@:1}")
                fi

                if [[ -z "$DEFAULT_SERVICE" ]]; then
                    echo "Cannot execute command against default service - no default service specified."
                    exit 1
                else
                    eval "${COMMAND[@]}"
                fi
            else
                source "$ROOT_DIR/commands/help.sh"
            fi

            exit
    esac

    shift
done
