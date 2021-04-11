#!/bin/bash

BLUEPRINT="$1"

if [[ -z $SILENT ]]; then
    SILENT=true
fi

if [[ -z "$BLUEPRINT" ]]; then
    yq_read_value BLUEPRINT 'from'
    export BLUEPRINT
fi

debug_print "Populating environment variables for blueprint: ${BLUEPRINT}"

if [[ -z "$BLUEPRINT_QUALIFIED_NAME" ]]; then
    # Get blueprint fully-qualified name to show to the user
    export BLUEPRINT_QUALIFIED_NAME="$(AS_FUNCTION=true bash "$ENTRYPOINT" pull "$BLUEPRINT" --get-qualified-name)"
fi

debug_print "BLUEPRINT_QUALIFIED_NAME=${BLUEPRINT_QUALIFIED_NAME}"

if ! $SILENT; then
    printf "Pulling blueprint '$BLUEPRINT_QUALIFIED_NAME'...\n"
fi

if [[ -z "$BLUEPRINT_DIR" ]]; then
    # Try to pull the blueprint and get the returned directory path
    export BLUEPRINT_DIR="$(AS_FUNCTION=true bash "$ENTRYPOINT" pull "$BLUEPRINT")"
fi

debug_print "BLUEPRINT_DIR=${BLUEPRINT_DIR}"

if [[ $? -ne 0 ]]; then
    printf "${RED}ERROR${RESET}: Unable to pull blueprint '$BLUEPRINT'.\n"
    exit 1
fi

if [[ -z "$ENV_NAME" ]]; then
    yq_read_value ENV_NAME "environment"
    export ENV_NAME
fi

debug_print "ENV_NAME=${ENV_NAME}"

if [[ -z "$ENV_DIR" ]] && [[ -n "$ENV_NAME" ]]; then
    export ENV_DIR="$BLUEPRINT_DIR/env/$ENV_NAME"

    if [[ ! -d "$ENV_DIR" ]]; then
        printf "${RED}ERROR${RESET}: Environment '$ENV_NAME' doesn't exist\n"
        exit 1
    fi
fi

debug_print "ENV_DIR=${ENV_DIR}"
