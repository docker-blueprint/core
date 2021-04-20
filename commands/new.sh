#!/bin/bash

debug_switch_context "NEW"

debug_print "Running the command..."

shift

if [[ -z "$1" ]]; then
    bash $ENTRYPOINT new --help
    exit 1
fi

FORCE_GENERATE=false
MODE_DRY_RUN=false

UP_ARGS=()

#
# Read arguments
#

while [[ "$#" -gt 0 ]]; do
    case $1 in
    -m | --with)
        ARG_WITH=()

        while [[ -n "$2" ]] && [[ "$2" != -* ]]; do
            ARG_WITH+=($2)
            shift
        done

        if [[ -z "${ARG_WITH[0]}" ]]; then
            bash $ENTRYPOINT new --help
            exit 1
        fi
        ;;
    -e | --env)
        ENV_NAME=$2
        shift

        if [[ -z "$ENV_NAME" ]]; then
            bash $ENTRYPOINT new --help
            exit 1
        fi
        ;;
    -f | --force)
        FORCE_GENERATE=true
        ;;
    --clean)
        printf "This will ${RED}completely wipe out${RESET} current directory.\n"
        read -p "Are you sure? [y/N] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf $(ls -A $PWD)
        else
            printf "${YELLOW}You answered 'no', stopping here.\n"
            exit 1
        fi
        ;;
    -h | --help)
        printf "${CMD_COL}new${RESET} ${ARG_COL}<blueprint>${RESET} [${FLG_COL}options${RESET}]"
        printf "\tCreate containerized technology stack for the project in current directory\n"

        printf "  ${FLG_COL}-e${RESET}, ${FLG_COL}--env${RESET} ${FLG_VAL_COL}<environment>${RESET}"
        printf "\tSet technology-specific environment (for example framework)\n"

        printf "  ${FLG_COL}-m${RESET}, ${FLG_COL}--with${RESET} ${FLG_VAL_COL}<module>${RESET} ..."
        printf "\tA list of modules to include from this technology blueprint\n"

        printf "  ${FLG_COL}-f${RESET}, ${FLG_COL}--force${RESET}"
        printf "\t\t\tAlways generate new docker-blueprint.yml, even if it already exists\n"

        printf "  ${FLG_COL}--clean${RESET}"
        printf "\t\t\tRemove all files in current directory before building a blueprint\n"

        printf "  ${FLG_COL}--dry-run${RESET}"
        printf "\t\t\tRun the command without writing any files\n"

        printf "  ${FLG_COL}--no-cache${RESET}"
        printf "\t\t\tDon't use docker image cache\n"

        printf "  ${FLG_COL}--no-chown${RESET}"
        printf "\t\t\tPass --no-chown to 'sync' command\n"

        printf "  ${FLG_COL}--no-scripts${RESET}"
        printf "\t\tDon't attempt to run scripts\n"

        exit
        ;;
    --dry-run)
        MODE_DRY_RUN=true
        ;;
    --no-cache)
        UP_ARGS+=("--no-cache")
        ;;
    --no-chown)
        UP_ARGS+=("--no-chown")
        ;;
    --no-scripts)
        UP_ARGS+=("--no-scripts")
        ;;
    *)
        if [[ -z "$1" ]]; then
            bash $ENTRYPOINT new --help
            exit 1
        fi

        BLUEPRINT=$1
        ;;
    esac

    shift
done

#
# Build project blueprint file
#
# Generate only when the file is not present
# or force rebuild when the FORCE flag is supplied
#

if $FORCE_GENERATE; then
    rm -f "$PWD/$PROJECT_BLUEPRINT_FILE"
elif [[ -f "$PWD/$PROJECT_BLUEPRINT_FILE" ]]; then
    printf "${RED}ERROR${RESET}: ${YELLOW}$PROJECT_BLUEPRINT_FILE${RESET} already exists (run with --force to override).\n"
    exit 1
fi

if ! [[ -f "$PWD/$PROJECT_BLUEPRINT_FILE" ]]; then

    # export BLUEPRINT_PATH
    SILENT=true source "$ROOT_DIR/includes/blueprint/compile.sh" "$BLUEPRINT"
    debug_switch_context "NEW"

    # Populate project blueprint

    # Create empty YAML file
    echo "---" >"$PWD/$PROJECT_BLUEPRINT_FILE"

    fields_to_set=(
        'from'
        'user'
        'version'
        'environment'
        'default_service'
    )

    # Set blueprint field values
    for field in ${fields_to_set[@]}; do
        debug_print "Updating blueprint field: $field"

        yq_read_value value "$field" "$BLUEPRINT_PATH"

        if ! $MODE_DRY_RUN && [[ -n "$value" ]]; then
            yq_write_value "$field" "$value" "$PROJECT_BLUEPRINT_FILE"
        fi
    done

    environment="$(yq_read_value "environment" "$BLUEPRINT_PATH")"
    if ! $MODE_DRY_RUN && [[ -n "$environment" ]]; then
        debug_print "Setting environment: $environment"

        bash $ENTRYPOINT environment set "$environment" --quiet
    fi

    fields_to_merge=(
        'build_args'
        'project'
    )

    # Merge blueprint key-value fields
    for field in ${fields_to_merge[@]}; do
        debug_print "Merging blueprint field: $field"

        yq_read_value value "$field" "$BLUEPRINT_PATH"

        if ! $MODE_DRY_RUN && [[ -n "$value" ]]; then
            yq eval-all ".$field = ((.$field // {}) as \$item ireduce ({}; . *+ \$item)) | select(fi == 0)" -i \
                "$PROJECT_BLUEPRINT_FILE" "$BLUEPRINT_PATH"
        fi
    done

    # Append modules that were defined with `--with` option
    for module in "${ARG_WITH[@]}"; do
        debug_print "Adding module: $module"

        if ! $MODE_DRY_RUN; then
            bash $ENTRYPOINT modules add "$module" --quiet --no-scripts

            if [[ $? > 0 ]]; then
                printf "${RED}ERROR${RESET}: The was an error while adding module '$module'\n"
                exit 1
            fi
        fi
    done

    rm -f "$BLUEPRINT_PATH"

fi

if $FORCE_GENERATE; then
    UP_ARGS+=("--force")
fi

command="$ENTRYPOINT up ${UP_ARGS[@]}"

debug_print "Running command: $command"

if ! $MODE_DRY_RUN; then
    bash $command
fi
