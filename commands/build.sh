#!/bin/bash

debug_switch_context "BUILD"

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
    -h | --help)
        printf "${CMD_COL}build${RESET} [${FLG_COL}options${RESET}] [${ARG_COL}<tag>${RESET}]"
        printf "\tBuild containerized technology stack defined in docker-blueprint.yml\n"

        printf "  ${FLG_COL}-f${RESET}, ${FLG_COL}--force${RESET}"
        printf "\t\t\tAlways generate new docker files. This ${RED}WILL OVERWRITE${RESET} existing files\n"

        printf "  ${FLG_COL}--dry-run${RESET}"
        printf "\t\t\tRun the command without writing any files\n"

        printf "  ${FLG_COL}--skip-compose${RESET}"
        printf "\t\tDon't generate docker-compose files\n"

        printf "  ${FLG_COL}--skip-dockerfile${RESET}"
        printf "\t\tDon't generate dockerfiles\n"

        printf "  ${FLG_COL}--no-cache${RESET}"
        printf "\t\t\tDon't use docker image cache\n"

        exit
        ;;
    -f | --force)
        MODE_FORCE=true
        ;;
    --dry-run)
        MODE_DRY_RUN=true
        ;;
    --skip-compose | --no-compose)
        MODE_SKIP_COMPOSE=true
        ;;
    --skip-dockerfile | --no-dockerfile)
        MODE_SKIP_DOCKERFILE=true
        ;;
    --no-cache)
        MODE_NO_CACHE=true
        ;;
    *)
        TARGET_IMAGE=$1
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

# export BLUEPRINT_PATH
source "$ROOT_DIR/includes/blueprint/compile.sh" "$BLUEPRINT"

if [[ $? -ne 0 ]]; then
    printf "\n${RED}ERROR${RESET}: Unable to compile blueprint '$BLUEPRINT'.\n"
    exit 1
fi

debug_switch_context "BUILD"

debug_newline_print "Resolving dependencies..."

source "$ROOT_DIR/includes/resolve-dependencies.sh" ${MODULES_TO_LOAD[@]}

non_debug_print " ${GREEN}done${RESET}\n"

#
# Read generated configuration
#

# export SCRIPT_VARS
# export SCRIPT_VARS_ENV
# export SCRIPT_VARS_BUILD_ARGS
source "$ROOT_DIR/includes/get-script-vars.sh"

#
# Build docker-compose.yml
#

printf "Building docker-compose files...\n"

# Select all unique docker-compose files (even in disabled modules)
if ! $MODE_SKIP_COMPOSE; then
    FILE_NAMES=($(
        find "$BLUEPRINT_DIR" -name "docker-compose*.yml" -type f |
            xargs basename -a |
            sort |
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

    docker_compose_file_paths=()

    # Add base file if it exists
    file="$BLUEPRINT_DIR/$name"
    if [[ -f "$file" ]]; then
        docker_compose_file_paths+=("$file")
    fi

    # Then add environment file if it exists
    file="$ENV_DIR/$name"
    if [[ -f "$file" ]]; then
        docker_compose_file_paths+=("$file")
    fi

    # For each enabled module add files to merge
    for module in ${MODULES_TO_LOAD[@]}; do

        # Add base blueprint module files first
        file="$BLUEPRINT_DIR/modules/$module/$name"
        if [[ -f "$file" ]]; then
            docker_compose_file_paths+=("$file")
        fi

        # Then add environment module files
        file="$ENV_DIR/modules/$module/$name"
        if [[ -f "$file" ]]; then
            docker_compose_file_paths+=("$file")
        fi
    done

    debug_print "Merging files:"

    for file in ${docker_compose_file_paths[@]}; do
        debug_print "- ${file#$BLUEPRINT_DIR/}"
        if [[ ! -f "$CURRENT_DOCKER_COMPOSE_FILE" ]]; then
            cp -f "$file" "$CURRENT_DOCKER_COMPOSE_FILE"
        else
            printf -- "$(
                yq_merge \
                    "$CURRENT_DOCKER_COMPOSE_FILE" "$file"
            )" >"$CURRENT_DOCKER_COMPOSE_FILE"
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

        # Substitute blueprint variables

        while read -r line || [[ -n "$line" ]]; do
            echo $(substitute_vars "$line" "~") >>"$temp_file"
            non_debug_print "."
        done <"$CURRENT_DOCKER_COMPOSE_FILE"

        mv -f "$temp_file" "$CURRENT_DOCKER_COMPOSE_FILE"
        rm -f "$temp_file" && touch "$temp_file"

        # Remove lines with non-substituted variables

        while read -r line || [[ -n "$line" ]]; do
            if [[ "$line" =~ "~" ]]; then

                if [[ -n "$replaced" ]]; then
                    echo "$replaced" >>"$temp_file"
                fi
            else
                echo "$line" >>"$temp_file"
            fi

            non_debug_print "."
        done <"$CURRENT_DOCKER_COMPOSE_FILE"

        IFS="$OLD_IFS"

        if ! $MODE_DRY_RUN; then
            mv -f "$temp_file" "$CURRENT_DOCKER_COMPOSE_FILE"
        fi

        rm -f "$temp_file"

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
    SCRIPT_VARS_BUILD_ARGS+=("--no-cache")
fi

command="$DOCKER_COMPOSE build ${SCRIPT_VARS_BUILD_ARGS[@]}"

debug_print "Running command: $command"

status=0

if ! $MODE_DRY_RUN; then
    eval "$command"
    status=$?
fi

if [[ $status -eq 0 ]] && [[ -n "$TARGET_IMAGE" ]]; then
    printf "Applying tag ${YELLOW}$TARGET_IMAGE${RESET} to the newly built image...\n"
    if ! $MODE_DRY_RUN; then
        docker tag "${PROJECT_NAME}_${DEFAULT_SERVICE}" "$TARGET_IMAGE"
        status=$?
    fi
fi

if [[ "$status" > 0 ]]; then
    printf "${RED}ERROR${RESET}: Couldn't finish building blueprint.\n"
    exit $status
fi

    fi
fi



