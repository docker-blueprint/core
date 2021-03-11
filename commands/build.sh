#!/bin/bash

# Blueprint BUILD command

shift

#
# Read arguments
#

MODE_FORCE=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            printf "${CMD_COL}build${RESET} [${FLG_COL}options${RESET}]"
            printf "\t\tBuild containerized technology stack defined in docker-blueprint.yml\n"

            printf "  ${FLG_COL}-f${RESET}, ${FLG_COL}--force${RESET}"
            printf "\t\t\tAlways generate new docker files\n"

            exit

            ;;
        -f|--force)
            MODE_FORCE=true
            ;;
    esac

    shift
done

#
# Initialize path variables
#

printf "Loading blueprint..."

yq_read_value BLUEPRINT 'blueprint.name' && printf "."
yq_read_value CHECKPOINT 'blueprint.version' && printf "."
yq_read_value ENV_NAME 'blueprint.env' && printf "."
yq_read_array MODULES_TO_LOAD 'modules' && printf "."

BLUEPRINT_DIR=$(AS_FUNCTION=true bash $ENTRYPOINT pull $BLUEPRINT)

if [[ $? -ne 0 ]]; then
    printf "\n${RED}ERROR${RESET}: Unable to pull blueprint '$BLUEPRINT'.\n"
    exit 1
fi

printf " ${GREEN}done${RESET}\n"

# Set the blueprint repository to the version specified.
# This allows to always safely reproduce previous versions of the blueprint.
if [[ -n $CHECKPOINT ]]; then
    cd $BLUEPRINT_DIR
    git checkout $CHECKPOINT 2> /dev/null
    if [[ $? -eq 0 ]]; then
        printf "Version: ${CYAN}$CHECKPOINT${RESET}\n"
    else
        printf "${RED}ERROR${RESET}: Unable to checkout version $CHECKPOINT\n"
        exit 1
    fi
    cd $PROJECT_DIR
fi

# Set the project environment directory
if [[ -n "$ENV_NAME" ]]; then
    ENV_DIR=$BLUEPRINT_DIR/env/$ENV_NAME

    if [[ ! -d $ENV_DIR ]]; then
        printf "${RED}ERROR${RESET}: Environment ${YELLOW}$ENV_NAME${RESET} doesn't exist\n"
        exit 1
    fi
fi

source "$ROOT_DIR/includes/resolve-dependencies.sh" ${MODULES_TO_LOAD[@]}

#
# Read generated configuration
#

debug_newline_print "Reading configuration..."

yq_read_value DEFAULT_SERVICE "default_service" && non_debug_print "."
yq_read_keys BUILD_ARGS_KEYS "build_args" && non_debug_print "."

echo "$DEFAULT_SERVICE" > "$DIR/default_service"

BUILD_ARGS=()
SCRIPT_VARS=()

add_variable() {
    BUILD_ARGS+=("--build-arg $1='$2'")
    SCRIPT_VARS+=("BLUEPRINT_$1=$2")
}

add_variable "BLUEPRINT_DIR" "$BLUEPRINT_DIR"
add_variable "ENV_DIR" "$ENV_DIR"

for variable in ${BUILD_ARGS_KEYS[@]}; do
    yq_read_value value "build_args.$variable" && non_debug_print "."

    # Replace build argument value with env variable value if it is set
    if [[ -n ${!variable+x} ]]; then
        value="${!variable:-}"
    fi

    add_variable "$variable" "$value" && non_debug_print "."
done

yq_read_keys DEPENDENCIES_KEYS "dependencies" && non_debug_print "."

for key in "${DEPENDENCIES_KEYS[@]}"; do
    yq_read_array DEPS "dependencies.$key" && non_debug_print "."
    key="$(echo "$key" | tr [:lower:] [:upper:])"
    add_variable "DEPS_$key" "${DEPS[*]}"
done

yq_read_keys PURGE_KEYS "purge" && non_debug_print "."

for key in "${PURGE_KEYS[@]}"; do
    yq_read_array PURGE "purge.$key" && non_debug_print "."
    key="$(echo "$key" | tr [:lower:] [:upper:])"
    add_variable "PURGE_$key" "${PURGE[*]}"
done

env_name="$(echo "$ENV_NAME" | tr [:lower:] [:upper:] | tr - _)"

for module in "${MODULES_TO_LOAD[@]}"; do
    module_name="$(echo "$module" | tr [:lower:] [:upper:] | tr "/-" _)"

    path="$BLUEPRINT_DIR/modules/$module"
    if [[ -d "$path" ]]; then
        add_variable "MODULE_${module_name}_DIR" "$path"
    fi

    path="$ENV_DIR/modules/$module"
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
FILE_NAMES=($(
    find "$BLUEPRINT_DIR" -name "docker-compose*.yml" -type f | \
    xargs basename -a | \
    sort | \
    uniq
))

for name in ${FILE_NAMES[@]}; do
    CURRENT_DOCKER_COMPOSE_FILE="$PWD/$name"

    # Make sure file doesn't exist in the project directory,
    # otherwise print a warning and skip it

    if $MODE_FORCE; then
        rm -f "$CURRENT_DOCKER_COMPOSE_FILE"
    elif [[ -f "$CURRENT_DOCKER_COMPOSE_FILE" ]]; then
        printf "${YELLOW}WARNING${RESET}: $name already exists, skipping generation (run with --force to override).\n"
        continue
    fi

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
    done

    if [[ -f "$CURRENT_DOCKER_COMPOSE_FILE" ]]; then
        # Remove empty lines
        sed -ri '/^\s*$/d' "$CURRENT_DOCKER_COMPOSE_FILE"

        debug_print "Created docker-compose file: '$name':"

        printf "Generated ${YELLOW}$name${RESET}\n"
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

    if $MODE_FORCE; then
        rm -f "$CURRENT_DOCKERFILE"
    elif [[ -f "$CURRENT_DOCKERFILE" ]]; then
        printf "${YELLOW}WARNING${RESET}: $DOCKER_FILE already exists, skipping generation (run with --force to override).\n"
        continue
    fi

    env "${SCRIPT_VARS[@]}" bash $ENTRYPOINT process "$file"

    if [[ $? > 0 ]]; then
        printf "\n${RED}ERROR${RESET}: There was an error processing $file\n"
        exit 1
    fi

    cp "$file.out" "$CURRENT_DOCKERFILE"

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

eval "$DOCKER_COMPOSE build ${BUILD_ARGS[@]}"
