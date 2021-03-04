#!/bin/bash

VARIABLES=($(env | awk -F= '{ print $1 }' | grep '^BLUEPRINT_'))

BUFFER="$1"

for variable in "${VARIABLES[@]}"; do
    # Escape variable value to use with sed
    value="$(echo ${!variable} | sed -E 's|[][\\/.*^$]|\\&|g')"
    # Uncomment the line where the variable is used
    BUFFER="$(echo "$BUFFER" | sed -E "s/#\s*(.*%$variable)/\1/g")"
    # Substitute the variable with its value
    BUFFER="$(echo "$BUFFER" | sed -E "s/%$variable/$value/g")"
done

printf "%s" "$BUFFER"
