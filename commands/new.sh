#!/bin/bash

DEBUG_PREFIX="NEW"

debug_print "Running the command..."

# Blueprint NEW command
#
# This command generates `docker-blueprint.yml` file and uses it to further
# generate `docker-compose.yml` & `dockerfile` and call `docker-compose` to
# build the container and bring up all the required services.
#
# Apart from service building this command also does:
# - Post build container initialization by calling commands from
# `postbuild_commands` section
# - Optional directory chowning to keep it in sync with local project
# - Commenting out .env directives that are already defined in
# `docker-compose.yml`

shift

if [[ -z "$1" ]]; then
    bash $ENTRYPOINT new --help
    exit 1
fi

FORCE_GENERATE=false

#
# Read arguments
#

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -m|--with)
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

        -e|--env)
            ENV_NAME=$2
            shift

            if [[ -z "$ENV_NAME" ]]; then
                bash $ENTRYPOINT new --help
                exit 1
            fi

            ;;

        -f|--force)
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

        -h|--help)
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

            exit

            ;;

        *)
            if [[ -z "$1" ]]; then
                bash $ENTRYPOINT new --help
                exit 1
            fi

            BLUEPRINT=$1
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
    rm -f "$PWD/$BLUEPRINT_FILE_FINAL"
elif [[ -f "$PWD/$BLUEPRINT_FILE_FINAL" ]]; then
    printf "${RED}ERROR${RESET}: ${YELLOW}$BLUEPRINT_FILE_FINAL${RESET} already exists (run with --force to override).\n"
    exit 1
fi

if ! [[ -f "$PWD/$BLUEPRINT_FILE_FINAL" ]]; then

    BLUEPRINT_HASH="$(printf "%s" "$BLUEPRINT$(date +%s)" | openssl dgst -sha1 | sed 's/^.* //')"
    BLUEPRINT_PATH="$TEMP_DIR/blueprint-$BLUEPRINT_HASH"
    BLUEPRINT_DIR="$(dirname "$BLUEPRINT_PATH")"

    source "$ROOT_DIR/includes/blueprint/compile.sh" $BLUEPRINT 2>"$BLUEPRINT_PATH"
    DEBUG_PREFIX="NEW"

    # Populate project blueprint

    # Create empty YAML file
    echo "---" > "$BLUEPRINT_FILE_FINAL"

    fields_to_set=(
        'from'
        'user'
        'version'
        'environment'
        'default_service'
    )

    # Set blueprint field values
    for field in ${fields_to_set[@]}; do
        value="$(yq eval ".$field // \"\"" "$BLUEPRINT_PATH")"

        if [[ -n "$value" ]]; then
            yq eval ".$field = \"$value\"" -i "$BLUEPRINT_FILE_FINAL"
        fi
    done

    fields_to_merge=(
        'build_args'
        'project'
        'commands'
    )

    # Merge blueprint key-value fields
    for field in ${fields_to_merge[@]}; do
        yq eval-all ".$field = ((.$field // {}) as \$item ireduce ({}; . *+ \$item)) | select(fi == 0)" -i \
            "$BLUEPRINT_FILE_FINAL" "$BLUEPRINT_PATH"
    done

    # Append modules that were defined with `--with` option
    for module in "${ARG_WITH[@]}"; do
        yq eval ".modules = ((.modules // []) + [\"$module\"])" -i "$BLUEPRINT_FILE_FINAL"
    done

    rm -f "$BLUEPRINT_PATH"

fi

COMMAND="$ENTRYPOINT up"

if $FORCE_GENERATE; then
    COMMAND="$COMMAND --force"
fi

bash $COMMAND
