#!/bin/bash

# Is stdout is a terminal?
if [[ -t 1 ]] && [[ -z ${DOCKER_BLUEPRINT_NO_COLOR:+x} ]]; then

    # Does it support colors?
    ncolors=$(tput colors)

    if [[ $ncolors -ge 8 ]]; then
        export BLACK="\u001b[30m"
        export RED="\u001b[31m"
        export GREEN="\u001b[32m"
        export YELLOW="\u001b[33m"
        export BLUE="\u001b[34m"
        export MAGENTA="\u001b[35m"
        export CYAN="\u001b[36m"
        export WHITE="\u001b[37m"
        export RESET="\u001b[0m"
    fi
fi

export CMD_COL=$YELLOW
export ARG_COL=$RESET
export FLG_COL=$YELLOW
