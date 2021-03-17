#!/bin/bash

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
# Build custom blueprint file
#
# Generate only when file is not present
# or force rebuild when the flag is supplied

if $FORCE_GENERATE; then
    rm -f "$PWD/$BLUEPRINT_FILE_FINAL"
elif [[ -f "$PWD/$BLUEPRINT_FILE_FINAL" ]]; then
    printf "${BLUE}INFO${RESET}: ${YELLOW}$BLUEPRINT_FILE_FINAL${RESET} already exists, skipping generation (run with --force to override).\n"
fi

if ! [[ -f "$PWD/$BLUEPRINT_FILE_FINAL" ]]; then

    #
    # Initialize path variables
    #

    BLUEPRINT_QUALIFIED_NAME=$(AS_FUNCTION=true bash $ENTRYPOINT pull $BLUEPRINT --get-qualified-name)

    debug_newline_print "Pulling blueprint '$BLUEPRINT_QUALIFIED_NAME'..."

    BLUEPRINT_DIR=$(AS_FUNCTION=true bash $ENTRYPOINT pull $BLUEPRINT)

    if [[ $? -ne 0 ]]; then
        printf "\n${RED}ERROR${RESET}: Unable to pull blueprint '$BLUEPRINT'.\n"
        exit 1
    fi

    non_debug_print " ${GREEN}done${RESET}\n"

    BLUEPRINT_FILE_TMP=$BLUEPRINT_DIR/blueprint.tmp
    BLUEPRINT_FILE_BASE=$BLUEPRINT_DIR/blueprint.yml

    if [[ -n "$ENV_NAME" ]]; then
        ENV_DIR=$BLUEPRINT_DIR/env/$ENV_NAME
    fi

    debug_newline_print "Generating blueprint file..."

    if [[ ! -f "$BLUEPRINT_FILE_BASE" ]]; then
        printf "\n${RED}ERROR${RESET}: Base blueprint.yml doesn't exist.\n"
        exit 1
    fi

    # Merge environment preset with base preset

    debug_print "Using base blueprint: ${BLUEPRINT_FILE_BASE#$BLUEPRINT_DIR/}"

    file="$ENV_DIR/blueprint.yml"
    if [[ -n $ENV_DIR ]] && [[ -f "$file" ]]; then
        debug_print "Using environment blueprint: ${file#$BLUEPRINT_DIR/}"
        printf -- "$(yq_merge $file $BLUEPRINT_FILE_BASE)" >"$BLUEPRINT_FILE_TMP"
    else
        cp "$BLUEPRINT_FILE_BASE" "$BLUEPRINT_FILE_TMP"
    fi

    # Collect modules to load from temporary preset file and CLI arguments

    yq_read_array MODULES "modules" "$BLUEPRINT_FILE_TMP" && non_debug_print "."

    MODULES_TO_LOAD=()

    for module in "${MODULES[@]}"; do
        MODULES_TO_LOAD+=($module)
    done

    for module in "${ARG_WITH[@]}"; do
        ALREADY_DEFINED=false

        for defined_module in "${MODULES_TO_LOAD[@]}"; do
            if [[ "$module" = "$defined_module" ]]; then
                ALREADY_DEFINED=true
                break
            fi
        done

        if ! $ALREADY_DEFINED; then
            MODULES_TO_LOAD+=($module)
        fi
    done

    source "$ROOT_DIR/includes/resolve-dependencies.sh" ${MODULES_TO_LOAD[@]}

    # Generate a list of YAML files to merge
    # depending on chosen modules

    FILES_TO_MERGE=()

    function append_file_to_merge {
        if [[ -f "$1" ]]; then
            FILES_TO_MERGE+=("$1")
        fi
    }

    append_file_to_merge "$BLUEPRINT_FILE_TMP"

    for module in "${MODULES_TO_LOAD[@]}"; do

        # Each module can extend base blueprint

        file="$BLUEPRINT_DIR/modules/$module/blueprint.yml"
        if [[ -f "$file" ]]; then
            debug_print "Using module blueprint: ${file#$BLUEPRINT_DIR/}"
            append_file_to_merge "$file"
        fi

        # If environment is specified, additionally load module
        # blueprint files specific to the environment

        file="$ENV_DIR/modules/$module/blueprint.yml"
        if [[ -d "$ENV_DIR" ]] && [[ -f "$file" ]]; then
            debug_print "Using environment module blueprint: ${file#$BLUEPRINT_DIR/}"
            append_file_to_merge "$file"
        fi

        non_debug_print "."
    done

    debug_print "Merging files:"
    for file in "${FILES_TO_MERGE[@]#$BLUEPRINT_DIR/}"; do
        debug_print "- $file"
    done

    if [[ -z "${FILES_TO_MERGE[1]}" ]]; then
        printf -- "$(cat "${FILES_TO_MERGE[0]}")" >"$BLUEPRINT_FILE_FINAL" && non_debug_print "."
    else
        printf -- "$(yq_merge ${FILES_TO_MERGE[@]})" >"$BLUEPRINT_FILE_FINAL" && non_debug_print "."
    fi

    # Remove the list of modules in order to fill it again
    # in the correct order and without duplicates
    yq -i eval "del(.modules)" "$BLUEPRINT_FILE_FINAL" && non_debug_print "."

    for module in "${MODULES_TO_LOAD[@]}"; do
        yq -i eval ".modules += [\"$module\"]" "$BLUEPRINT_FILE_FINAL"
    done

    # Remove `depends_on` property, since it is only used for modules
    yq -i eval "del(.depends_on)" "$BLUEPRINT_FILE_FINAL" && non_debug_print "."

    cd $BLUEPRINT_DIR

    hash=$(git rev-parse HEAD) 2> /dev/null && non_debug_print "."

    if [[ $? > 0 ]]; then
        unset hash
    fi

    cd $PROJECT_DIR

    if [[ -n $hash ]]; then
        yq -i eval ".version = \"$hash\"" "$BLUEPRINT_FILE_FINAL" && non_debug_print "."
    fi

    yq -i eval ".name = \"$BLUEPRINT\"" "$BLUEPRINT_FILE_FINAL" && non_debug_print "."

    if [[ -n $ENV_NAME ]]; then
        yq -i eval ".environment = \"$ENV_NAME\"" "$BLUEPRINT_FILE_FINAL" && non_debug_print "."
    fi

    yq_read_keys BUILD_ARGS_KEYS 'build_args'

    for variable in ${BUILD_ARGS_KEYS[@]}; do
        yq_read_value value "build_args.$variable"

        if [[ -n ${!variable+x} ]]; then
            value="${!variable:-}"
        fi

        yq -i eval ".build_args.$variable = \"$value\"" "$BLUEPRINT_FILE_FINAL" && non_debug_print "."
    done

    non_debug_print " ${GREEN}done${RESET}\n"

    debug_print "Created blueprint file: $BLUEPRINT_FILE_FINAL"
fi

rm -f "$BLUEPRINT_FILE_TMP"

COMMAND="$ENTRYPOINT build"

if $FORCE_GENERATE; then
    COMMAND="$COMMAND --force"
fi

bash $COMMAND
