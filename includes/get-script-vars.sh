#!/bin/bash

if [[ -z "$BLUEPRINT_PATH" ]]; then
    # export BLUEPRINT_PATH
    SILENT=false source "$ROOT_DIR/includes/blueprint/compile.sh" "$BLUEPRINT"
fi

# Read values from merged blueprint

debug_newline_print "Reading configuration..."

yq_read_keys BUILD_ARGS_KEYS "build_args" "$BLUEPRINT_PATH" && non_debug_print "."

SCRIPT_VARS=()

add_variable() {
    debug_print "Added variable $1='$2'"
    SCRIPT_VARS+=("BLUEPRINT_$1=$2")
}

add_variable "BLUEPRINT_DIR" "${BLUEPRINT_DIR#"$PWD/"}"
add_variable "ENV_DIR" "${ENV_DIR#"$PWD/"}"
add_variable "ENV_NAME" "$ENV_NAME"

for variable in ${BUILD_ARGS_KEYS[@]}; do
    yq_read_value value "build_args.$variable" "$BLUEPRINT_PATH" && non_debug_print "."

    # Replace build argument value with env variable value if it is set
    if [[ -n ${!variable+x} ]]; then
        value="${!variable:-}"
    fi

    add_variable "$variable" "$value" && non_debug_print "."
done

yq_read_keys DEPENDENCIES_KEYS "dependencies" "$BLUEPRINT_PATH" && non_debug_print "."

for key in "${DEPENDENCIES_KEYS[@]}"; do
    yq_read_array DEPS "dependencies.$key" "$BLUEPRINT_PATH" && non_debug_print "."
    key="$(echo "$key" | tr [:lower:] [:upper:])"
    add_variable "DEPS_$key" "${DEPS[*]}"
done

yq_read_keys PURGE_KEYS "purge" "$BLUEPRINT_PATH" && non_debug_print "."

for key in "${PURGE_KEYS[@]}"; do
    yq_read_array PURGE "purge.$key" "$BLUEPRINT_PATH" && non_debug_print "."
    key="$(echo "$key" | tr [:lower:] [:upper:])"
    add_variable "PURGE_$key" "${PURGE[*]}"
done

env_name="$(echo "$ENV_NAME" | tr [:lower:] [:upper:] | tr - _)"

if [[ -n "$ENV_NAME" ]]; then
    add_variable "ENV_${env_name}_DIR" "$ENV_DIR"
fi

for module in "${MODULES_TO_LOAD[@]}"; do
    module_name="$(echo "$module" | tr [:lower:] [:upper:] | tr "/-" _)"

    path="${BLUEPRINT_DIR#"$PWD/"}/modules/$module"
    if [[ -d "$path" ]]; then
        add_variable "MODULE_${module_name}_DIR" "$path"
    fi

    path="${ENV_DIR#"$PWD/"}/modules/$module"
    if [[ -d "$path" ]]; then
        add_variable "ENV_${env_name}_MODULE_${module_name}_DIR" "$path"
    fi
done

non_debug_print " ${GREEN}done${RESET}\n"

export SCRIPT_VARS

SCRIPT_VARS_BUILD_ARGS=()

for var in "${SCRIPT_VARS[@]}"; do
    name="$(echo "$var" | cut -d'=' -f1)"
    value="$(echo "$var" | cut -d'=' -f2)"
    SCRIPT_VARS_BUILD_ARGS+=("--build-arg $name='$value'")
done

export SCRIPT_VARS_BUILD_ARGS

SCRIPT_VARS_ENV=()

for var in "${SCRIPT_VARS[@]}"; do
    name="$(echo "$var" | cut -d'=' -f1)"
    value="$(echo "$var" | cut -d'=' -f2)"
    SCRIPT_VARS_ENV+=("-e $name='$value'")
done

export SCRIPT_VARS_ENV
