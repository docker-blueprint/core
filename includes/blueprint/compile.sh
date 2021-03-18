#!/bin/bash

DEBUG_PREFIX="COMPILE"

debug_print "Running the command..."

BLUEPRINT="$1"

# Get blueprint fully-qualified name to show to the user
BLUEPRINT_QUALIFIED_NAME=$(AS_FUNCTION=true bash $ENTRYPOINT pull $BLUEPRINT --get-qualified-name)

debug_newline_print "Pulling blueprint '$BLUEPRINT_QUALIFIED_NAME'..."

# Try to pull the blueprint and get the returned directory path
BLUEPRINT_DIR=$(AS_FUNCTION=true bash $ENTRYPOINT pull $BLUEPRINT)

if [[ $? -ne 0 ]]; then
    printf "\n${RED}ERROR${RESET}: Unable to pull blueprint '$BLUEPRINT'.\n"
    exit 1
fi

non_debug_print " ${GREEN}done${RESET}\n"

yq_read_value CHECKPOINT 'version'

# Set the blueprint repository to the version specified.
# This allows to always safely reproduce previous versions of the blueprint.
if [[ -n $CHECKPOINT ]]; then
    cd "$BLUEPRINT_DIR"
    git checkout $CHECKPOINT 2> /dev/null
    if [[ $? -eq 0 ]]; then
        printf "Version: ${CYAN}$CHECKPOINT${RESET}\n"
    else
        printf "${RED}ERROR${RESET}: Unable to checkout version $CHECKPOINT\n"
        exit 1
    fi
    cd "$PROJECT_DIR"
fi

BLUEPRINT_FILE_TMP=$BLUEPRINT_DIR/blueprint.tmp
BLUEPRINT_FILE_BASE=$BLUEPRINT_DIR/blueprint.yml

if [[ -z "$ENV_NAME" ]]; then
    yq_read_value ENV_NAME "environment" "$PROJECT_BLUEPRINT_FILE"
fi

if [[ -n "$ENV_NAME" ]]; then
    ENV_DIR=$BLUEPRINT_DIR/env/$ENV_NAME
fi

debug_newline_print "Generating blueprint file..."

if [[ ! -f "$BLUEPRINT_FILE_BASE" ]]; then
    printf "\n${RED}ERROR${RESET}: Base blueprint.yml doesn't exist.\n"
    exit 1
fi

# Start by making a copy of the base blueprint file

cp "$BLUEPRINT_FILE_BASE" "$BLUEPRINT_FILE_TMP"

# Merge environment blueprint

debug_print "Using base blueprint: ${BLUEPRINT_FILE_BASE#$BLUEPRINT_DIR/}"

file="$ENV_DIR/blueprint.yml"
if [[ -n $ENV_DIR ]] && [[ -f "$file" ]]; then
    debug_print "Using environment blueprint: ${file#$BLUEPRINT_DIR/}"
    printf -- "$(yq_merge $BLUEPRINT_FILE_TMP $file)" >"$BLUEPRINT_FILE_TMP"
fi

# Merge project blueprint

if [[ -f "$PROJECT_BLUEPRINT_FILE" ]]; then
    debug_print "Using project blueprint: ${PROJECT_BLUEPRINT_FILE}"
    printf -- "$(yq_merge $BLUEPRINT_FILE_TMP $PROJECT_BLUEPRINT_FILE)" >"$BLUEPRINT_FILE_TMP"
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

if [[ ${#MODULES_TO_LOAD[@]} > 0 ]]; then
    source "$ROOT_DIR/includes/resolve-dependencies.sh" ${MODULES_TO_LOAD[@]}
fi

# Generate a list of YAML files to merge
# depending on chosen modules

FILES_TO_MERGE=()

function append_file_to_merge() {
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
    printf -- "$(cat "${FILES_TO_MERGE[0]}")" >"$BLUEPRINT_FILE_TMP" && non_debug_print "."
else
    printf -- "$(yq_merge ${FILES_TO_MERGE[@]})" >"$BLUEPRINT_FILE_TMP" && non_debug_print "."
fi

# Get current blueprint commit hash...

cd $BLUEPRINT_DIR

hash=$(git rev-parse HEAD) 2>/dev/null && non_debug_print "."

if [[ $? > 0 ]]; then
    unset hash
fi

cd $PROJECT_DIR

# ... and store it for the version lock
if [[ -n $hash ]]; then
    yq -i eval ".version = \"$hash\" | .version style=\"double\"" "$BLUEPRINT_FILE_TMP" && non_debug_print "."
fi

# Store blueprint name
yq -i eval ".from = \"$BLUEPRINT\" | .from style=\"double\"" "$BLUEPRINT_FILE_TMP" && non_debug_print "."

# Store blueprint environment
if [[ -n $ENV_NAME ]]; then
    yq -i eval ".environment = \"$ENV_NAME\" | .environment style=\"double\"" "$BLUEPRINT_FILE_TMP" && non_debug_print "."
fi

# Save build arguments to give the user ability to overwrite them later
yq_read_keys BUILD_ARGS_KEYS 'build_args' "$BLUEPRINT_FILE_TMP" && non_debug_print "."

for variable in ${BUILD_ARGS_KEYS[@]}; do
    yq_read_value value "build_args.$variable" "$BLUEPRINT_FILE_TMP" && non_debug_print "."

    if [[ -n ${!variable+x} ]]; then
        value="${!variable:-}"
    fi

    yq -i eval ".build_args.$variable = \"$value\"" "$BLUEPRINT_FILE_TMP" && non_debug_print "."
done

non_debug_print " ${GREEN}done${RESET}\n"

debug_print "Created blueprint file: $BLUEPRINT_FILE_TMP"

# Output compiled blueprint content to stderr,
# since stdout is used for progress reporting
cat "$BLUEPRINT_FILE_TMP" >&2

rm -f "$BLUEPRINT_FILE_TMP"
