#!/bin/bash

PREFIX="BLUEPRINT_"

VARIABLES=($(env | awk -F= '{ print $1 }' | grep "^$PREFIX"))

BUFFER="$1"

for variable in "${VARIABLES[@]}"; do
    # Escape variable value to use with sed
    value="$(echo ${!variable} | sed -E 's|[][\\/.*^$]|\\&|g')"
    # Uncomment the line where the variable is used
    BUFFER="$(echo "$BUFFER" | sed -E "s/#\s*(.*%${variable#"$PREFIX"})/\1/g")"
    # Substitute the variable with its value
    BUFFER="$(echo "$BUFFER" | sed -E "s/%${variable#"$PREFIX"}/$value/g")"
done

printf "%s" "$BUFFER"
