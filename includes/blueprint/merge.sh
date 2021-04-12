#!/bin/bash

BLUEPRINT_FILE_TMP=$BLUEPRINT_DIR/blueprint.tmp
BLUEPRINT_FILE_BASE=$BLUEPRINT_DIR/blueprint.yml

! $SILENT && debug_newline_print "Generating blueprint file..."

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

export BLUEPRINT_FILE_TMP
