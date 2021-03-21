#!/bin/bash

DEBUG_PREFIX="MODULES"

debug_print "Running the command..."

shift

#
# Read arguments
#

ACTION=""

AVAILABLE_ACTIONS=(
    'add'
    'remove'
)

MODULES=()

MODE_FORCE=false
MODE_NO_SCRIPTS=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
    -h | --help)
        printf "${CMD_COL}modules${RESET} ${ARG_COL}<action>${RESET} [${ARG_COL}<module>${RESET}]"
        printf "\tAdd a module from the base blueprint to the current project\n"

        exit

        ;;
    -f | --force)
        MODE_FORCE=true

        ;;
    --no-scripts)
        MODE_NO_SCRIPTS=true

        ;;
    *)
        if [[ -z "$ACTION" ]]; then
            ACTION="$1"
        else
            MODULES+=("$1")
        fi

        ;;
    esac

    shift
done

if [[ -z "$ACTION" ]]; then
    bash $ENTRYPOINT modules --help

    printf "${GREEN}%s${RESET}:\n" "Available actions"

    for action in "${AVAILABLE_ACTIONS[@]}"; do
        printf -- "- %s\n" "$action"
    done

    exit 1
fi

VALID_ACTION=false
for action in "${AVAILABLE_ACTIONS[@]}"; do
    if [[ "$action" = "$ACTION" ]]; then
        VALID_ACTION=true
        break
    fi
done

if ! $VALID_ACTION; then
    printf -- "${RED}ERROR${RESET}: Unknown action '%s'\n" "$ACTION"
    exit 1
fi

yq_read_value BLUEPRINT 'from'
BLUEPRINT_QUALIFIED_NAME=$(AS_FUNCTION=true bash $ENTRYPOINT pull $BLUEPRINT --get-qualified-name)

BLUEPRINT_DIR=$(AS_FUNCTION=true bash $ENTRYPOINT pull $BLUEPRINT)

if [[ -z "$ENV_NAME" ]]; then
    yq_read_value ENV_NAME "environment"
fi

if [[ -n "$ENV_NAME" ]]; then
    ENV_DIR=$BLUEPRINT_DIR/env/$ENV_NAME
fi

MODULES_LIST=()
ENV_MODULES_LIST=()
BASE_MODULES_LIST=()

for module in $ENV_DIR/modules/*; do
    name="$(basename "$module")"
    ENV_MODULES_LIST+=("$name")
    MODULES_LIST+=("$name")
done

for module in $BLUEPRINT_DIR/modules/*; do
    name="$(basename "$module")"
    BASE_MODULES_LIST+=("$name")
    MODULES_LIST+=("$name")
done

if [[ ${#MODULES[@]} -eq 0 ]]; then
    bash $ENTRYPOINT modules --help

    if [[ ${#MODULES_LIST[@]} > 0 ]]; then
        printf "${GREEN}Available modules${RESET}:\n"

        for module in "${MODULES_LIST[@]}"; do
            IS_ENV_MODULE=false
            IS_BASE_MODULE=false

            for env_module in "${ENV_MODULES_LIST[@]}"; do
                if [[ "$module" = "$env_module" ]]; then
                    IS_ENV_MODULE=true
                    break
                fi
            done

            for base_module in "${BASE_MODULES_LIST[@]}"; do
                if [[ "$module" = "$base_module" ]]; then
                    IS_BASE_MODULE=true
                    break
                fi
            done

            if $IS_BASE_MODULE && $IS_ENV_MODULE; then
                printf -- "- %s (${YELLOW}extended${RESET} by $ENV_NAME)\n" "$module"
            elif ! $IS_BASE_MODULE && $IS_ENV_MODULE; then
                printf -- "- %s (${CYAN}provided${RESET} by $ENV_NAME)\n" "$module"
            else
                printf -- "- %s\n" "$module"
            fi
        done
    else
        printf "The base blueprint '${YELLOW}$BLUEPRINT_QUALIFIED_NAME${RESET}' has no modules.\n"
    fi
    exit 1
else
    for MODULE in "${MODULES[@]}"; do
        FOUND=false
        for module in "${MODULES_LIST[@]}"; do
            if [[ "$module" == "$MODULE" ]]; then
                FOUND=true
                break
            fi
        done

        if ! $FOUND; then
            printf -- "${RED}ERROR${RESET}: Unable to find module '%s'.\n" "$MODULE"
            exit 1
        fi
    done
fi

for MODULE in "${MODULES[@]}"; do
    if ! $MODE_NO_SCRIPTS; then
        script_paths=()

        # Add base blueprint module scripts first
        path="$BLUEPRINT_DIR/modules/$MODULE/scripts/$ACTION.sh"
        if [[ -f "$path" ]]; then
            script_paths+=("$path")
        fi

        # Then add environment module scripts
        path="$ENV_DIR/modules/$MODULE/scripts/$ACTION.sh"
        if [[ -f "$path" ]]; then
            script_paths+=("$path")
        fi

        status=0

        for path in "${script_paths[@]}"; do
            printf "Running script for module '$MODULE'...\n"
            debug_print "Running script: ${path#$BLUEPRINT_DIR/}"
            command="bash -c \"$(cat "$path")\""
            bash $ENTRYPOINT $DEFAULT_SERVICE exec "$command"

            status=$?

            if [[ $status > 0 ]]; then
                break
            fi
        done

        if [[ $status > 0 ]]; then
            printf -- "${RED}ERROR${RESET}: Module script returned non-zero code: ${path#$BLUEPRINT_DIR/}\n"
            exit $status
        fi
    fi

    case "$ACTION" in
    add)
        exists="$(yq eval ".modules[] | select(. == \"$MODULE\")" "$PROJECT_BLUEPRINT_FILE")"
        if [[ -z "$exists" ]]; then
            yq eval ".modules = ((.modules // []) + [\"$MODULE\"])" -i "$PROJECT_BLUEPRINT_FILE"
            printf -- "Added module '%s' to the project blueprint.\n" "$MODULE"
        else
            printf -- "${BLUE}INFO${RESET}: Project blueprint already has module '%s'.\n" "$MODULE"
        fi
        ;;
    remove)
        exists="$(yq eval ".modules[] | select(. == \"$MODULE\")" "$PROJECT_BLUEPRINT_FILE")"
        if [[ -n "$exists" ]]; then
            yq eval "del(.modules[] | select(. == \"$MODULE\"))" -i "$PROJECT_BLUEPRINT_FILE"
            printf -- "Removed module '%s' from the project blueprint.\n" "$MODULE"
        else
            printf -- "${BLUE}INFO${RESET}: Project blueprint doesn't have module '%s'.\n" "$MODULE"
        fi
        ;;
    esac
done



if ! $MODE_FORCE; then
    printf "Do you want to rebuild the project? (run with ${FLG_COL}--force${RESET} to always build)\n"
    printf "${YELLOW}WARNING${RESET}: This will ${RED}overwrite${RESET} existing docker files [y/N] "
    read -n 1 -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        bash $ENTRYPOINT build --force
    fi
else
    bash $ENTRYPOINT build --force
fi
