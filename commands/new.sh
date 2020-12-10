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
    bash $ENTRYPOINT create --help
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
                bash $ENTRYPOINT create --help
                exit 1
            fi

            ;;

        -e|--env)
            ENV_NAME=$2
            shift

            if [[ -z "$ENV_NAME" ]]; then
                bash $ENTRYPOINT create --help
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
                bash $ENTRYPOINT create --help
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

if ! [[ -f docker-blueprint.yml ]] || $FORCE_GENERATE; then

    #
    # Initialize path variables
    #

    BLUEPRINT_QUALIFIED_NAME=$(AS_FUNCTION=true bash $ENTRYPOINT pull $BLUEPRINT --get-qualified-name)

    printf "Pulling blueprint '$BLUEPRINT_QUALIFIED_NAME'..."

    BLUEPRINT_DIR=$(AS_FUNCTION=true bash $ENTRYPOINT pull $BLUEPRINT)

    if [[ $? -ne 0 ]]; then
        printf "\n${RED}ERROR${RESET}: Unable to pull blueprint '$BLUEPRINT'.\n"
        exit 1
    fi

    printf " ${GREEN}done${RESET}\n"

    BLUEPRINT_FILE_TMP=$BLUEPRINT_DIR/blueprint.tmp
    BLUEPRINT_FILE_BASE=$BLUEPRINT_DIR/blueprint.yml

    if [[ -n "$ENV_NAME" ]]; then
        ENV_DIR=$BLUEPRINT_DIR/env/$ENV_NAME
    fi

    printf "Generating blueprint file..."

    # Merge environment preset with base preset

    if [[ -n $ENV_DIR ]] && [[ -f "$ENV_DIR/blueprint.yml" ]]; then
        printf -- "$(yq merge -a append $ENV_DIR/blueprint.yml $BLUEPRINT_FILE_BASE)" > "$BLUEPRINT_FILE_TMP"
    else
        cp "$BLUEPRINT_FILE_BASE" "$BLUEPRINT_FILE_TMP"
    fi

    # Collect modules to load from
    # temporary preset file and CLI arguments

    read_array MODULES "modules" "$BLUEPRINT_FILE_TMP" && printf "."

    MODULES_TO_LOAD=()

    for module in "${MODULES[@]}"; do
        MODULES_TO_LOAD+=($module)
    done

    for module in "${ARG_WITH[@]}"; do
        MODULES_TO_LOAD+=($module)
    done

    # Rearrange modules according to depends_on
    # such as dependencies always come first
    # Notice: cyclic dependencies WILL cause undefined behavior

    i=0
    MODULE_STACK=()

    while [[ $i < ${#MODULES_TO_LOAD[@]} ]]; do

        module="${MODULES_TO_LOAD[i]}"

        FOUND=false

        for entry in "${MODULE_STACK[@]}"; do
            if [[ $entry == $module ]]; then
                FOUND=true; break
            fi
        done

        if ! $FOUND; then
            MODULE_STACK+=("$module")
        fi

        # Read depends_on from each module file

        if [[ -f "$BLUEPRINT_DIR/modules/$module/blueprint.yml" || \
              -f "$BLUEPRINT_DIR/modules/$module.yml" ]]; then

            if [[ -f "$BLUEPRINT_DIR/modules/$module/blueprint.yml" ]]; then
                read_array DEPENDS_ON 'depends_on' "$BLUEPRINT_DIR/modules/$module/blueprint.yml"
            else
                read_array DEPENDS_ON 'depends_on' "$BLUEPRINT_DIR/modules/$module.yml"
            fi

            FOUND=false

            # For each dependency, check whether it
            # already has been added to the list

            for dependency in "${DEPENDS_ON[@]}"; do
                FOUND=false

                for entry in "${MODULE_STACK[@]}"; do
                    if [[ $entry == $dependency ]]; then
                        FOUND=true; break
                    fi
                done

                # If dependency has not been already added,
                # replace current module with the dependency
                # and append module to the end of the list

                if ! $FOUND; then
                    stack_length=${#MODULE_STACK[@]}
                    MODULE_STACK[stack_length - 1]="$dependency"
                    MODULE_STACK+=("$module")
                fi
            done
        fi

        ((i = i + 1))

        printf "."

    done

    MODULES_TO_LOAD=("${MODULE_STACK[@]}")

    # Generate a list of YAML files to merge
    # depending on chosen modules

    FILES_TO_MERGE=()

    function append_file_to_merge {
        if [[ -f "$1" ]]; then
            FILES_TO_MERGE+=("$1")
        fi
    }

    for module in "${MODULES_TO_LOAD[@]}"; do

        # Each module can extend preset YAML file

        if [[ -f "$BLUEPRINT_DIR/modules/$module/blueprint.yml" ]]; then
            append_file_to_merge "$BLUEPRINT_DIR/modules/$module/blueprint.yml"
        else
            append_file_to_merge "$BLUEPRINT_DIR/modules/$module.yml"
        fi

        # If environment is specified, additionally load module
        # configuration files specific to the environment

        if [[ -d "$ENV_DIR" ]]; then
            if [[ -f "$ENV_DIR/modules/$module/blueprint.yml" ]]; then
                append_file_to_merge "$ENV_DIR/modules/$module/blueprint.yml"
            else
                append_file_to_merge "$ENV_DIR/modules/$module.yml"
            fi
        fi

        printf "."
    done

    FILES_TO_MERGE+=("$BLUEPRINT_FILE_TMP")

    if [[ -z "${FILES_TO_MERGE[1]}" ]]; then
        printf -- "$(yq read "${FILES_TO_MERGE[0]}")" > "$BLUEPRINT_FILE_FINAL" && printf "."
    else
        printf -- "$(yq merge -a append ${FILES_TO_MERGE[@]})" > "$BLUEPRINT_FILE_FINAL" && printf "."
    fi

    printf -- "$(yq delete $BLUEPRINT_FILE_FINAL 'modules')" > "$BLUEPRINT_FILE_FINAL" && printf "."

    for module in "${MODULES_TO_LOAD[@]}"; do
        yq write $BLUEPRINT_FILE_FINAL 'modules[+]' "$module" -i
    done

    printf -- "$(yq delete $BLUEPRINT_FILE_FINAL 'depends_on')" > "$BLUEPRINT_FILE_FINAL" && printf "."

    cd $BLUEPRINT_DIR

    hash=$(git rev-parse HEAD) 2> /dev/null && printf "."

    if [[ $? > 0 ]]; then
        unset hash
    fi

    cd $PROJECT_DIR

    if [[ -n $hash ]]; then
        yq write $BLUEPRINT_FILE_FINAL 'blueprint.version' "$hash" -i && printf "."
    fi

    yq write $BLUEPRINT_FILE_FINAL 'blueprint.name' "$BLUEPRINT" -i && printf "."

    if [[ -n $ENV_NAME ]]; then
        yq write $BLUEPRINT_FILE_FINAL 'blueprint.env' "$ENV_NAME" -i && printf "."
    fi

    read_keys BUILD_ARGS_KEYS 'build_args'

    for variable in ${BUILD_ARGS_KEYS[@]}; do
        read_value value "build_args.$variable"

        if [[ -n ${!variable+x} ]]; then
            value="${!variable:-}"
        fi

        yq write $BLUEPRINT_FILE_FINAL "build_args.$variable" "$value" -i && printf "."
    done

    printf " ${GREEN}done${RESET}\n"

else
    printf "${YELLOW}WARNING${RESET}: docker-blueprint.yml already exists, skipping generation (run with --force to override)\n"
fi

rm -f "$BLUEPRINT_FILE_TMP"

bash $ENTRYPOINT build
