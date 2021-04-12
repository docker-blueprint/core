#!/bin/bash

DEBUG_PREFIX="MODULES"

debug_print "Running the command..."

shift

#
# Read arguments
#

ACTION=""

AVAILABLE_ACTIONS=(
    'list'
    'add'
    'remove'
)

MODULES=()

MODE_FORCE=false
MODE_QUIET=false
MODE_NO_SCRIPTS=false
MODE_PRINT_ACTIVE_ONLY=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
    -h | --help)
        printf "${CMD_COL}modules${RESET} ${ARG_COL}<action>${RESET} [${ARG_COL}<module>${RESET}]"
        printf "\tAdd or remove a modules from the base blueprint to the current project\n"

        printf "  ${FLG_COL}-a${RESET}, ${FLG_COL}--active${RESET}"
        printf "\t\tOnly list active modules\n"

        printf "  ${FLG_COL}--no-scripts${RESET}"
        printf "\t\tDon't attempt to run scripts\n"

        exit
        ;;
    -f | --force)
        MODE_FORCE=true
        ;;
    -q | --quiet)
        MODE_QUIET=true
        ;;
    --no-scripts)
        MODE_NO_SCRIPTS=true
        ;;
    -a | --active)
        MODE_PRINT_ACTIVE_ONLY=true
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

source "$ROOT_DIR/includes/blueprint/populate_env.sh" ""

yq_read_array MODULES_TO_LOAD 'modules'
EXPLICIT_MODULES_LIST=(${MODULES_TO_LOAD[@]})
source "$ROOT_DIR/includes/resolve-dependencies.sh" ${MODULES_TO_LOAD[@]}
ACTIVE_MODULES_LIST=(${MODULES_TO_LOAD[@]})

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

if [[ ${#MODULES[@]} -eq 0 ]] || [[ "$ACTION" = "list" ]]; then
    bash $ENTRYPOINT modules --help

    if [[ ${#MODULES_LIST[@]} > 0 ]]; then
        printf "${GREEN}Available modules${RESET}:\n"

        for module in "${MODULES_LIST[@]}"; do
            IS_ENV_MODULE=false
            IS_BASE_MODULE=false
            IS_ACTIVE_MODULE=false
            IS_EXPLICIT_MODULE=false

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

            for active_module in "${ACTIVE_MODULES_LIST[@]}"; do
                if [[ "$module" = "$active_module" ]]; then
                    IS_ACTIVE_MODULE=true
                    break
                fi
            done

            for explicit_module in "${EXPLICIT_MODULES_LIST[@]}"; do
                if [[ "$module" = "$explicit_module" ]]; then
                    IS_EXPLICIT_MODULE=true
                    break
                fi
            done

            attributes=()

            if $IS_BASE_MODULE && $IS_ENV_MODULE; then
                attributes+=("${YELLOW}extended${RESET} by $ENV_NAME")
            elif ! $IS_BASE_MODULE && $IS_ENV_MODULE; then
                attributes+=("${CYAN}provided${RESET} by $ENV_NAME")
            fi

            if $IS_EXPLICIT_MODULE; then
                attributes+=("specified in ${BLUE}docker-blueprint.yml${RESET}")
            fi

            attribute_text=""

            if [[ ${#attributes[@]} > 0 ]]; then
                attribute_text+="("

                i=1

                for attribute in "${attributes[@]}"; do
                    attribute_text+="$attribute"
                    if [[ $i < ${#attributes[@]} ]]; then
                        attribute_text+=", "
                    fi
                    ((i = i + 1))
                done

                attribute_text+=")"
            fi

            icon="$ICON_EMPTY"

            if $IS_ACTIVE_MODULE; then
                icon="$ICON_CHECK"
            elif $MODE_PRINT_ACTIVE_ONLY; then
                continue
            fi

            printf -- "$icon %s $attribute_text\n" "$module"
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

            PROGRAM="$(source "$ROOT_DIR/includes/script/prepare.sh" "$(cat "$path")")"

            command="bash -c \"$PROGRAM\""
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

if ! $MODE_QUIET; then
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
fi
