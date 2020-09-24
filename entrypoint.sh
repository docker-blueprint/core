#!/bin/bash

EXECUTABLE_NAME=$(basename "${BASH_SOURCE}")

DIR=.docker-blueprint
REAL_DIR="$(readlink -f "$0")"
ROOT_DIR="$(dirname "$REAL_DIR")"
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

source "$ROOT_DIR/includes/yq.sh"
source "$ROOT_DIR/includes/colors.sh"

init_default_service() {
    DEFAULT_SERVICE=$(cat $DIR/default_service 2>/dev/null)

    if [[ -z $DEFAULT_SERVICE ]] && [[ -f docker-blueprint.yml ]]; then
        read_value DEFAULT_SERVICE "default_service" docker-blueprint.yml
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

case $1 in
    exec)
        docker-compose exec --user="$UID":"$GID" ${@:2}
        ;;

    down|restart)
        docker-compose "$1" ${@:2}
        ;;

    -h | --help)
        source "$ROOT_DIR/commands/help.sh"
        ;;

    *)
        if [[ ! -z "$1" ]]; then
            if [[ ! -z "$2" ]] && [[ "$2" == "sudo" ]]; then
                COMMAND="docker-compose exec $1 ${@:3}"
            elif [[ "$1" == "sudo" ]]; then
                COMMAND="docker-compose exec $DEFAULT_SERVICE ${@:2}"
            else
                COMMAND="docker-compose exec --user=$UID:$GID $DEFAULT_SERVICE $@"
            fi

            if [[ -z "$DEFAULT_SERVICE" ]]; then
                echo "Cannot execute command against default service - no default service specified."
                exit 1
            else
                $COMMAND
            fi
        else
            source "$ROOT_DIR/commands/help.sh"
        fi
        ;;
esac
