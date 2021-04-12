#!/bin/bash

if [[ -z $SILENT ]]; then
    SILENT=false
fi

debug_print "Resolving dependencies..."

MODULES_TO_LOAD=($@)
MODULES_TO_DISABLE=()

debug_print "Requested modules: ${MODULES_TO_LOAD[*]}"

source "$ROOT_DIR/includes/blueprint/merge.sh" # export BLUEPRINT_FILE_TMP

# Collect modules to load from temporary preset file and CLI arguments

yq_read_array MERGED_MODULES_TO_LOAD "modules" "$BLUEPRINT_FILE_TMP"

rm "$BLUEPRINT_FILE_TMP"

for module in "${MERGED_MODULES_TO_LOAD[@]}"; do
    # Remove duplicates
    FOUND=false
    for existing_module in "${MODULES_TO_LOAD[@]}"; do
        if [[ "$module" = "$existing_module" ]]; then
            FOUND=true
            break
        fi
    done

    if ! $FOUND; then
        MODULES_TO_LOAD+=($module)
    fi
done

# Resolve all modules and their dependencies
# Notice: cyclic dependencies WILL cause undefined behavior

i=0

while [[ $i -lt ${#MODULES_TO_LOAD[@]} ]]; do

    module="${MODULES_TO_LOAD[i]}"

    module_dirs=()

    path="$BLUEPRINT_DIR/modules/$module"
    if [[ -d "$path" ]]; then
        debug_print "Found module '$module'"
        module_dirs+=("$path")
    fi

    path="$ENV_DIR/modules/$module"
    if [[ -d "$path" ]]; then
        debug_print "Found environment module '$module'"
        module_dirs+=("$path")
    fi

    if [[ ${#module_dirs[@]} -eq 0 ]]; then
        printf "${RED}ERROR${RESET}: Module '$module' not found.\n"
        exit 1
    fi

    FOUND=false

    for entry in "${MODULES_TO_LOAD[@]}"; do
        if [[ $entry == $module ]]; then
            FOUND=true
            break
        fi
    done

    # Read disables from each module file

    for dir in "${module_dirs[@]}"; do
        file="$dir/blueprint.yml"
        if [[ -f "$file" ]]; then
            yq_read_array DISABLES 'disables' "$file"

            if [[ ${#DISABLES[@]} > 0 ]]; then
                debug_print "Module '$module' disables: ${DISABLES[*]}"
            fi

            # For each dependency to be disabled, add it to the list

            for dependency in "${DISABLES[@]}"; do
                MODULES_TO_DISABLE+=("$dependency")
            done
        fi
    done

    # Read depends_on from each module file

    for dir in "${module_dirs[@]}"; do
        file="$dir/blueprint.yml"
        if [[ -f "$file" ]]; then
            yq_read_array DEPENDS_ON 'depends_on' "$file"

            if [[ ${#DEPENDS_ON[@]} > 0 ]]; then
                debug_print "Module '$module' dependencies: ${DEPENDS_ON[*]}"
            fi

            FOUND=false

            # For each dependency, check whether it
            # already has been added to the list

            for dependency in "${DEPENDS_ON[@]}"; do
                FOUND=false

                for entry in "${MODULES_TO_LOAD[@]}"; do
                    if [[ $entry == $dependency ]]; then
                        FOUND=true
                        break
                    fi
                done

                # If dependency has not been already added,
                # replace current module with the dependency
                # and append module to the end of the list

                if ! $FOUND; then
                    # Add missing dependencies for the current module
                    # If those dependencies have their own dependencies,
                    # they will also be checked and added on the next
                    # iteration.
                    MODULES_TO_LOAD+=("$dependency")
                fi
            done
        fi
    done

    ((i = i + 1))

    ! $SILENT && non_debug_print "."

done

debug_print "Resolved module list: ${MODULES_TO_LOAD[*]}"

debug_print "Modules to disable: ${MODULES_TO_DISABLE[*]}"

PROCESSED_MODULE_LIST=()

for module in "${MODULES_TO_LOAD[@]}"; do
    IS_DISABLED=false
    for disabled_module in "${MODULES_TO_DISABLE[@]}"; do
        if [[ "$module" = "$disabled_module" ]]; then
            IS_DISABLED=true
            break
        fi
    done

    if ! $IS_DISABLED; then
        PROCESSED_MODULE_LIST+=("$module")
    fi
done

MODULES_TO_LOAD=(${PROCESSED_MODULE_LIST[@]})

debug_print "Final module list: ${MODULES_TO_LOAD[*]}"
