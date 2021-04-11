#!/bin/bash

if [[ -z $SILENT ]]; then
    SILENT=false
fi

MODULES_TO_LOAD=($@)

debug_print "Requested modules: ${MODULES_TO_LOAD[*]}"

# Resolve all modules and their dependencies
# Notice: cyclic dependencies WILL cause undefined behavior

i=0

while [[ $i -le ${#MODULES_TO_LOAD[@]} ]]; do

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

    # Read depends_on from each module file

    for dir in "${module_dirs[@]}"; do
        file="$dir/blueprint.yml"
        if [[ -f "$file" ]]; then
            yq_read_array DEPENDS_ON 'depends_on' "$file"

            debug_print "Module '$module' dependencies: ${DEPENDS_ON[*]}"

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
