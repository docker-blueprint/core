#!/bin/bash

PROGRAM="$1"
# Escape backslashes first
PROGRAM="$(echo "$PROGRAM" | sed -E 's/\\/\\\\/g')"
# Escape variable sign ($) to execute it inside runtime
PROGRAM="$(echo "$PROGRAM" | sed -E 's/\$/\\\$/g')"
# Then escape double-quotes, since they are used to enclose the program
PROGRAM="$(echo "$PROGRAM" | sed -E 's/"/\\"/g')"

echo "$PROGRAM"
