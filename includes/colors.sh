#!/bin/bash

# Is stdout is a terminal?
if [[ -t 1 ]] && [[ -z ${DOCKER_BLUEPRINT_NO_COLOR:+x} ]]; then

    # Does it support colors?
    ncolors=$(tput colors)

    if [[ $ncolors -ge 8 ]]; then
        export BLACK="\033[0;30m"
        export RED="\033[0;31m"
        export GREEN="\033[0;32m"
        export ORANGE="\033[0;33m"
        export BLUE="\033[0;34m"
        export PURPLE="\033[0;35m"
        export CYAN="\033[0;36m"
        export LIGHT_GRAY="\033[0;37m"
        export DARK_GRAY="\033[1;30m"
        export LIGHT_RED="\033[1;31m"
        export LIGHT_GREEN="\033[1;32m"
        export YELLOW="\033[1;33m"
        export LIGHT_BLUE="\033[1;34m"
        export LIGHT_PURPLE="\033[1;35m"
        export LIGHT_CYAN="\033[1;36m"
        export WHITE="\033[1;37m"
        export RESET="\033[0;0m"
    fi
fi

export EXE_COL=$BLUE
export SRV_COL=$LIGHT_GRAY
export CMD_COL=$GREEN
export ARG_COL=$RESET
export FLG_COL=$RED
export FLG_VAL_COL=$RESET

export ICON_EMPTY=" "
export ICON_CHECK="\xE2\x9C\x94"
