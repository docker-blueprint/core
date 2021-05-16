#!/bin/bash

debug_switch_context "COMPILE"

debug_print "Running the command..."

BLUEPRINT="$1"

if [[ -z "$BLUEPRINT" ]]; then
    printf "${RED}ERROR${RESET}: \$BLUEPRINT cannot be empty\n"
    exit 1
fi

if [[ -z "$TEMP_DIR" ]]; then
    printf "${RED}ERROR${RESET}: \$TEMP_DIR cannot be empty\n"
    exit 1
fi

if [[ -z $SILENT ]]; then
    SILENT=false
fi

SILENT=$SILENT source "$ROOT_DIR/includes/blueprint/populate_env.sh" $BLUEPRINT

yq_read_value CHECKPOINT 'version'

# Set the blueprint repository to the version specified.
# This allows to always safely reproduce previous versions of the blueprint.
if [[ -n $CHECKPOINT ]]; then
    cd "$BLUEPRINT_DIR"
    git checkout $CHECKPOINT 2> /dev/null
    if [[ $? -eq 0 ]]; then
        ! $SILENT && printf "Version: ${CYAN}$CHECKPOINT${RESET}\n"
    else
        printf "${RED}ERROR${RESET}: Unable to checkout version $CHECKPOINT\n"
        exit 1
    fi
    cd "$PROJECT_DIR"

    if [[ -n "$ENV_NAME" ]] && [[ ! -d "$ENV_DIR" ]]; then
        printf "${RED}ERROR${RESET}: Environment '$ENV_NAME' does not exist for version $CHECKPOINT\n"
        exit 1
    fi
else
    if ! $SILENT; then
        printf "${YELLOW}WARNING${RESET}: Blueprint version is not specified - future upstream changes can potentially break this project!\n"
        printf "Use ${EXE_COL}docker-blueprint${RESET} ${CMD_COL}lock${RESET} to lock the project to the current version of the blueprint\n"
    fi
fi

! $SILENT && non_debug_print "Generating blueprint file..."

source "$ROOT_DIR/includes/blueprint/merge.sh" # export BLUEPRINT_FILE_TMP

# Collect modules to load from temporary preset file and CLI arguments

yq_read_array MODULES "modules" "$BLUEPRINT_FILE_TMP" && \
    ! $SILENT && non_debug_print "."

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

if [[ ${#MODULES_TO_LOAD[@]} > 0 ]]; then
    SILENT=$SILENT source "$ROOT_DIR/includes/resolve-dependencies.sh" ${MODULES_TO_LOAD[@]}
fi

# Generate a list of YAML files to merge
# depending on chosen modules

FILES_TO_MERGE=()

function append_file_to_merge() {
    if [[ -f "$1" ]]; then
        FILES_TO_MERGE+=("$1")
    fi
}

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

    ! $SILENT && non_debug_print "."
done

# Merge user-provided blueprint file last to overwrite all the properties
append_file_to_merge "$BLUEPRINT_FILE_TMP"

debug_print "Merging files:"
for file in "${FILES_TO_MERGE[@]#$BLUEPRINT_DIR/}"; do
    debug_print "- $file"
done

if [[ -z "${FILES_TO_MERGE[1]}" ]]; then
    printf -- "$(cat "${FILES_TO_MERGE[0]}")" >"$BLUEPRINT_FILE_TMP" && \
        ! $SILENT && non_debug_print "."
else
    printf -- "$(yq_merge ${FILES_TO_MERGE[@]})" >"$BLUEPRINT_FILE_TMP" && \
        ! $SILENT && non_debug_print "."
fi

# Get current blueprint commit hash...

cd $BLUEPRINT_DIR

hash=$(git rev-parse HEAD) 2>/dev/null

if [[ $? > 0 ]]; then
    unset hash
fi

! $SILENT && non_debug_print "."

cd $PROJECT_DIR

# ... and store it for the version lock
if [[ -n $hash ]]; then
    yq -i eval ".version = \"$hash\" | .version style=\"single\"" "$BLUEPRINT_FILE_TMP" && \
        ! $SILENT && non_debug_print "."
fi

# Store blueprint name
yq -i eval ".from = \"$BLUEPRINT\" | .from style=\"single\"" "$BLUEPRINT_FILE_TMP" && \
    ! $SILENT && non_debug_print "."

# Store blueprint environment
if [[ -n $ENV_NAME ]]; then
    yq -i eval ".environment = \"$ENV_NAME\" | .environment style=\"single\"" "$BLUEPRINT_FILE_TMP" && \
        ! $SILENT && non_debug_print "."
fi

# Save build arguments to give the user ability to overwrite them later
yq_read_keys BUILD_ARGS_KEYS 'build_args' "$BLUEPRINT_FILE_TMP" && \
    ! $SILENT && non_debug_print "."

for variable in ${BUILD_ARGS_KEYS[@]}; do
    yq_read_value value "build_args.$variable" "$BLUEPRINT_FILE_TMP" && \
        ! $SILENT && non_debug_print "."

    if [[ -n ${!variable+x} ]]; then
        value="${!variable:-}"
    fi

    yq -i eval ".build_args.$variable = \"$value\" | .build_args.$variable style=\"single\"" "$BLUEPRINT_FILE_TMP" && \
        ! $SILENT && non_debug_print "."
done

! $SILENT && non_debug_print " ${GREEN}done${RESET}\n"

debug_print "Created blueprint file: $BLUEPRINT_FILE_TMP"

BLUEPRINT_HASH="$(printf "%s" "$BLUEPRINT$(date +%s)" | openssl dgst -sha1 | sed 's/^.* //')"
BLUEPRINT_PATH="$TEMP_DIR/blueprint-$BLUEPRINT_HASH"

mv "$BLUEPRINT_FILE_TMP" "$BLUEPRINT_PATH"

export BLUEPRINT_PATH
