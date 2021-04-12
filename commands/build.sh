#!/bin/bash

DEBUG_PREFIX="BUILD"

debug_print "Running the command..."

# Blueprint BUILD command

shift

#
# Read arguments
#

MODE_FORCE=false
MODE_DRY_RUN=false
MODE_SKIP_COMPOSE=false
MODE_SKIP_DOCKERFILE=false
MODE_NO_CACHE=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            printf "${CMD_COL}build${RESET} [${FLG_COL}options${RESET}]"
            printf "\t\tBuild containerized technology stack defined in docker-blueprint.yml\n"

            printf "  ${FLG_COL}-f${RESET}, ${FLG_COL}--force${RESET}"
            printf "\t\t\tAlways generate new docker files. This ${RED}WILL OVERWRITE${RESET} existing files\n"

            printf "  ${FLG_COL}--dry-run${RESET}"
            printf "\t\tRun the command without writing any files\n"

            printf "  ${FLG_COL}--skip-compose${RESET}"
            printf "\t\tDon't generate docker-compose files\n"

            printf "  ${FLG_COL}--skip-dockerfile${RESET}"
            printf "\t\tDon't generate dockerfiles\n"

            printf "  ${FLG_COL}--no-cache${RESET}"
            printf "\t\t\tDon't use docker image cache\n"

            exit

            ;;
        -f|--force)
            MODE_FORCE=true
            ;;
        --dry-run)
            MODE_DRY_RUN=true
            ;;
        --skip-compose|--no-compose)
            MODE_SKIP_COMPOSE=true
            ;;
        --skip-dockerfile|--no-dockerfile)
            MODE_SKIP_DOCKERFILE=true
            ;;
        --no-cache)
            MODE_NO_CACHE=true
            ;;
    esac

    shift
done

if [[ ! -f "$PWD/$PROJECT_BLUEPRINT_FILE" ]]; then
    printf "${RED}ERROR${RESET}: docker-blueprint.yml doesn't exist.\n"
    printf "Create one by running: ${BLUE}docker-blueprint ${GREEN}new${RESET}\n"
    exit 1
fi

#
# Initialize path variables
#

printf "Loading blueprint..."

# Use base metadata from `docker-blueprint.yml` in order to derive full blueprint

yq_read_value BLUEPRINT 'from' && printf "."
yq_read_value ENV_NAME 'environment' && printf "."
yq_read_array MODULES_TO_LOAD 'modules' && printf "."

printf " ${GREEN}done${RESET}\n"

BLUEPRINT_HASH="$(printf "%s" "$BLUEPRINT$(date +%s)" | openssl dgst -sha1 | sed 's/^.* //')"
BLUEPRINT_PATH="$TEMP_DIR/blueprint-$BLUEPRINT_HASH"

source "$ROOT_DIR/includes/blueprint/compile.sh" $BLUEPRINT 2>"$BLUEPRINT_PATH"

if [[ $? -ne 0 ]]; then
    printf "\n${RED}ERROR${RESET}: Unable to compile blueprint '$BLUEPRINT'.\n"
    exit 1
fi

DEBUG_PREFIX="BUILD"

debug_newline_print "Resolving dependencies..."

source "$ROOT_DIR/includes/resolve-dependencies.sh" ${MODULES_TO_LOAD[@]}

non_debug_print " ${GREEN}done${RESET}\n"

#
# Read generated configuration
#

debug_newline_print "Reading configuration..."

# Read values from merged blueprint

yq_read_value DEFAULT_SERVICE "default_service" "$BLUEPRINT_PATH" && non_debug_print "."
yq_read_keys BUILD_ARGS_KEYS "build_args" "$BLUEPRINT_PATH" && non_debug_print "."

echo "$DEFAULT_SERVICE" > "$LOCAL_DIR/default_service"

BUILD_ARGS=()
SCRIPT_VARS=()

add_variable() {
    debug_print "Added variable $1='$2'"
    BUILD_ARGS+=("--build-arg $1='$2'")
    SCRIPT_VARS+=("BLUEPRINT_$1=$2")
}

add_variable "BLUEPRINT_DIR" "${BLUEPRINT_DIR#"$PWD/"}"
add_variable "ENV_DIR" "${ENV_DIR#"$PWD/"}"
add_variable "ENV_NAME" "$ENV_NAME"

for variable in ${BUILD_ARGS_KEYS[@]}; do
    yq_read_value value "build_args.$variable" "$BLUEPRINT_PATH" && non_debug_print "."

    # Replace build argument value with env variable value if it is set
    if [[ -n ${!variable+x} ]]; then
        value="${!variable:-}"
    fi

    add_variable "$variable" "$value" && non_debug_print "."
done

yq_read_keys DEPENDENCIES_KEYS "dependencies" "$BLUEPRINT_PATH" && non_debug_print "."

for key in "${DEPENDENCIES_KEYS[@]}"; do
    yq_read_array DEPS "dependencies.$key" "$BLUEPRINT_PATH" && non_debug_print "."
    key="$(echo "$key" | tr [:lower:] [:upper:])"
    add_variable "DEPS_$key" "${DEPS[*]}"
done

yq_read_keys PURGE_KEYS "purge" "$BLUEPRINT_PATH" && non_debug_print "."

for key in "${PURGE_KEYS[@]}"; do
    yq_read_array PURGE "purge.$key" "$BLUEPRINT_PATH" && non_debug_print "."
    key="$(echo "$key" | tr [:lower:] [:upper:])"
    add_variable "PURGE_$key" "${PURGE[*]}"
done

env_name="$(echo "$ENV_NAME" | tr [:lower:] [:upper:] | tr - _)"

if [[ -n "$ENV_NAME" ]]; then
    add_variable "ENV_${env_name}_DIR" "$ENV_DIR"
fi

for module in "${MODULES_TO_LOAD[@]}"; do
    module_name="$(echo "$module" | tr [:lower:] [:upper:] | tr "/-" _)"

    path="${BLUEPRINT_DIR#"$PWD/"}/modules/$module"
    if [[ -d "$path" ]]; then
        add_variable "MODULE_${module_name}_DIR" "$path"
    fi

    path="${ENV_DIR#"$PWD/"}/modules/$module"
    if [[ -d "$path" ]]; then
        add_variable "ENV_${env_name}_MODULE_${module_name}_DIR" "$path"
    fi
done

non_debug_print " ${GREEN}done${RESET}\n"

#
# Build docker-compose.yml
#

printf "Building docker-compose files...\n"

# Select all unique docker-compose files (even in disabled modules)
if ! $MODE_SKIP_COMPOSE; then
    FILE_NAMES=($(
        find "$BLUEPRINT_DIR" -name "docker-compose*.yml" -type f | \
        xargs basename -a | \
        sort | \
        uniq
    ))
fi

for name in ${FILE_NAMES[@]}; do
    CURRENT_DOCKER_COMPOSE_FILE="$PWD/$name"

    # Make sure file doesn't exist in the project directory,
    # otherwise print a warning and skip it

    if $MODE_FORCE; then
        if ! $MODE_DRY_RUN; then
            rm -f "$CURRENT_DOCKER_COMPOSE_FILE"
        fi
    elif [[ -f "$CURRENT_DOCKER_COMPOSE_FILE" ]]; then
        printf "${BLUE}INFO${RESET}: ${YELLOW}$name${RESET} already exists, skipping generation (run with --force to override).\n"
        continue
    fi

    debug_newline_print "Generating ${YELLOW}$name${RESET}..."

    # Find all files with the same name
    FILES=($(find "$BLUEPRINT_DIR" -name "$name" -type f))

    FILTERED_FILES=()

    # Add base file if it exists
    file="$BLUEPRINT_DIR/$name"
    if [[ -f "$file" ]]; then
        FILTERED_FILES+=("$file")
    fi

    # For each enabled module check whether
    # the file needs to get merged
    for module in ${MODULES_TO_LOAD[@]}; do
        for item in ${FILES[@]}; do
            # If the file doesn't belong to the given module then skip it
            if [[ -z "$(echo "$item" | grep "modules/$module")" ]]; then
                continue
            fi

            # If the file is in an environment directory
            if [[ -n "$(echo "$item" | grep "env/")" ]]; then
                # And if the current environment is empty
                # or the given directory is not for the current environment
                if [[ -z $ENV_NAME ]] ||
                   [[ -z "$(echo "$item" | grep "env/$ENV_NAME")" ]]; then
                    # Then skip the file
                    continue
                fi
            fi

            FILTERED_FILES+=("$item")
        done
    done

    debug_print "Merging files:"

    for file in ${FILTERED_FILES[@]}; do
        debug_print "- ${file#$BLUEPRINT_DIR/}"
        if [[ ! -f "$CURRENT_DOCKER_COMPOSE_FILE" ]]; then
            cp -f "$file" "$CURRENT_DOCKER_COMPOSE_FILE"
        else
            printf -- "$(
                yq_merge \
                "$CURRENT_DOCKER_COMPOSE_FILE" "$file"
            )" > "$CURRENT_DOCKER_COMPOSE_FILE"
        fi

        non_debug_print "."
    done

    if [[ -f "$CURRENT_DOCKER_COMPOSE_FILE" ]]; then
        # Remove empty lines
        sed -ri '/^\s*$/d' "$CURRENT_DOCKER_COMPOSE_FILE"

        substitute_vars() {
            env "${SCRIPT_VARS[@]}" \
            bash "$ROOT_DIR/includes/preprocessor/substitute-vars.sh" $@
        }

        temp_file="$TEMP_DIR/$name"
        mkdir -p "$(dirname "$temp_file")"
        rm -f "$temp_file" && touch "$temp_file"

        OLD_IFS="$IFS" # Source https://stackoverflow.com/a/18055300/2467106
        IFS=
        while read -r line || [[ -n "$line" ]]; do
            echo $(substitute_vars "$line" "~") >> "$temp_file"
            non_debug_print "."
        done <"$CURRENT_DOCKER_COMPOSE_FILE"
        IFS="$OLD_IFS"

        if ! $MODE_DRY_RUN; then
            mv -f "$temp_file" "$CURRENT_DOCKER_COMPOSE_FILE"
        fi

        debug_print "Created docker-compose file: '$name':"

        non_debug_print " ${GREEN}done${RESET}\n"
    fi
done

#
# Build dockerfile
#

printf "Building dockerfiles...\n"

for file in $BLUEPRINT_DIR/[Dd]ockerfile*; do
    # https://stackoverflow.com/a/43606356/2467106
    # http://mywiki.wooledge.org/BashPitfalls#line-57
    [ -e "$file" ] || continue

    DOCKER_FILE=$(basename "$file")

    CURRENT_DOCKERFILE="$PWD/$DOCKER_FILE"

    if $MODE_SKIP_DOCKERFILE; then
        continue
    fi

    if $MODE_FORCE; then
        if ! $MODE_DRY_RUN; then
            rm -f "$CURRENT_DOCKERFILE"
        fi
    elif [[ -f "$CURRENT_DOCKERFILE" ]]; then
        printf "${BLUE}INFO${RESET}: ${YELLOW}$DOCKER_FILE${RESET} already exists, skipping generation (run with --force to override).\n"
        continue
    fi

    env "${SCRIPT_VARS[@]}" bash $ENTRYPOINT process "$file"

    if [[ $? > 0 ]]; then
        printf "\n${RED}ERROR${RESET}: There was an error processing $file\n"
        exit 1
    fi

    if ! $MODE_DRY_RUN; then
        cp "$file.out" "$CURRENT_DOCKERFILE"
    fi

    if [[ $? > 0 ]]; then
        printf "\n${RED}ERROR${RESET}: Unable to copy processed file\n"
        exit 1
    fi

    # Clean up after processing
    rm -f "$file.out"
done

#
# Build containers
#

if $MODE_NO_CACHE; then
    BUILD_ARGS+=("--no-cache")
fi

command="$DOCKER_COMPOSE build ${BUILD_ARGS[@]}"

debug_print "Running command: $command"

if ! $MODE_DRY_RUN; then
    eval "$command"
fi


