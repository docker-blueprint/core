#!/bin/bash

export EXECUTABLE_NAME=$(basename "${BASH_SOURCE}")

export PROJECT_DIR=$PWD
[[ -n $PROJECT_NAME ]] && GOT_PROJECT_NAME_FROM_ENV=true
[[ -z $GOT_PROJECT_NAME_FROM_ENV ]] && PROJECT_NAME=$(basename $PROJECT_DIR)
export DIR_NAME=.docker-blueprint
export ROOT_DIR=~/.docker-blueprint
export LOCAL_DIR="$PROJECT_DIR/$DIR_NAME"
export TEMP_DIR="$LOCAL_DIR/tmp"
export ENTRYPOINT="$ROOT_DIR/entrypoint.sh"
export PROJECT_BLUEPRINT_FILE=docker-blueprint.yml

# Delete temporary files older than 5 minutes
mkdir -p "$TEMP_DIR"
find "$TEMP_DIR" -mindepth 1 -type f -mmin +5 -delete

mkdir -p $LOCAL_DIR
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

if [[ -f "$PROJECT_BLUEPRINT_FILE" ]]; then
    [[ -z $PROJECT_CONTEXT ]] && \
    yq_read_value PROJECT_CONTEXT "project.context" "$PROJECT_BLUEPRINT_FILE"

    yq_read_value name "project.name" "$PROJECT_BLUEPRINT_FILE"
    [[ -z $GOT_PROJECT_NAME_FROM_ENV && -n $name ]] && export PROJECT_NAME="$name"
fi

# Parse global arguments
for arg in $@; do
    case $arg in
        --context)
            if [[ -z $2 ]]; then
                printf "${RED}ERROR${RESET}: Context name is required\n"
                exit 1
            fi

            export PROJECT_CONTEXT="$2"
            shift 2

            if [[ ! -f "docker-compose.$PROJECT_CONTEXT.yml" ]]; then
                printf "${RED}ERROR${RESET}: No docker-compose file found for context ${YELLOW}$PROJECT_CONTEXT${RESET}\n"
                exit 1
            fi

            ;;
        --)
            shift
            break
            ;;
    esac
done

source "$ROOT_DIR/includes/entrypoint/init-compose.sh"

init_default_service() {
    DEFAULT_SERVICE=$(cat $LOCAL_DIR/default_service 2>/dev/null)

    if [[ -z $DEFAULT_SERVICE ]] && [[ -f "$PROJECT_BLUEPRINT_FILE" ]]; then
        yq_read_value DEFAULT_SERVICE "default_service" "$PROJECT_BLUEPRINT_FILE"
        echo "$DEFAULT_SERVICE" >"$LOCAL_DIR/default_service"
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
