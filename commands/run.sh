#!/bin/bash

debug_switch_context "RUN"

shift

#
# Read arguments
#

while [[ "$#" -gt 0 ]]; do
    case $1 in
    -h | --help)
        printf "${CMD_COL}run${RESET} ${ARG_COL}<command>${RESET}"
        printf "\t\t\tRun a command in specified environment\n"

        printf "  ${FLG_COL}-T${RESET}"
        printf "\t\t\t\tDisable pseudo-tty allocation. Propagates -T to 'docker-compose exec'\n"

        exit

        ;;
    -T)
        MODE_NO_TTY='true'
        ;;
    *)
        COMMAND=$1
        break
        ;;
    esac

    shift
done

SILENT=true source "$ROOT_DIR/includes/blueprint/populate_env.sh" ""

# export BLUEPRINT_PATH
SILENT=true source "$ROOT_DIR/includes/blueprint/compile.sh" "$BLUEPRINT"
debug_switch_context "RUN"

yq_read_keys POSSIBLE_COMMANDS "commands" "$BLUEPRINT_PATH"

if [[ -z "$COMMAND" ]]; then
    bash $ENTRYPOINT run --help

    if [[ ${#POSSIBLE_COMMANDS[@]} > 0 ]]; then
        printf "${GREEN}Possible commands${RESET}:\n"
        for key in "${POSSIBLE_COMMANDS[@]}"; do
            printf -- "- $key\n"
        done
        printf "\n"
    else
        printf "${YELLOW}This project has no commands\n"
    fi

    exit 1
fi

COMMAND_ROOT="commands.[\"$COMMAND\"]"

yq_read_value PROGRAM "$COMMAND_ROOT.script" "$BLUEPRINT_PATH"

if [[ -z "$PROGRAM" ]]; then
    printf "${YELLOW}No command '$COMMAND'\n"
    exit 1
fi

debug_print "Setting up command to run..."

ENV_PREFIX=()
ENTRYPOINT_ARGS=()

yq_read_keys ENVIRONMENT_KEYS "$COMMAND_ROOT.environment" "$BLUEPRINT_PATH"

for key in "${ENVIRONMENT_KEYS[@]}"; do
    yq_read_value value "$COMMAND_ROOT.environment.$key" "$BLUEPRINT_PATH"

    # If there is already an environment variable
    # defined in the current environemnt
    if [[ -n ${!key} ]]; then
        # Then pass it to the program
        ENV_PREFIX+=("$key=\"${!key}\"")
        debug_print "Setting environment variable from current environment: $key=\"${!key}\""
    else
        # Otherwise set it to the value defined in the blueprint
        ENV_PREFIX+=("$key=\"$value\"")
        debug_print "Setting environment variable: $key=\"$value\""
    fi
done

i=0

for arg in "${@:2}"; do
    ((i = i + 1))
    ENV_PREFIX+=("ARG_$i=\"$arg\"")

    debug_print "Setting argument as environment variable: ARG_$i=\"$arg\""
done

ENV_PREFIX+=("COMMAND_NAME=\"$COMMAND\"")

yq_read_value RUNTIME "$COMMAND_ROOT.runtime" "$BLUEPRINT_PATH"

if [[ -z "$RUNTIME" ]]; then
    RUNTIME='sh -c'
fi

debug_print "Runtime: $RUNTIME"

if [[ -z $MODE_NO_TTY ]]; then
    yq_read_value MODE_NO_TTY "$COMMAND_ROOT.no_tty" "$BLUEPRINT_PATH"
    MODE_NO_TTY="$(echo $MODE_NO_TTY | grep -P '^yes|true|1$')"
fi

if [[ -n "$MODE_NO_TTY" ]]; then
    ENTRYPOINT_ARGS+=('-T')
fi

COMMAND_VERB="exec"

yq_read_value MODE_AS_ROOT "$COMMAND_ROOT.as_root" "$BLUEPRINT_PATH"
MODE_AS_ROOT="$(echo $MODE_AS_ROOT | grep -P '^yes|true|1$')"

[[ -n "$MODE_AS_ROOT" ]] && COMMAND_VERB="sudo"

yq_read_value SERVICE "$COMMAND_ROOT.service" "$BLUEPRINT_PATH"

if [[ -z "$SERVICE" ]]; then
    SERVICE="$DEFAULT_SERVICE"
fi

debug_print "Service: $SERVICE"

yq_read_value CONTEXT "$COMMAND_ROOT.context" "$BLUEPRINT_PATH"

if [[ -n "$CONTEXT" ]]; then
    export PROJECT_CONTEXT=$CONTEXT
    debug_print "Using COMMAND context: $CONTEXT"
elif [[ -n "$PROJECT_CONTEXT" ]]; then
    debug_print "Using DEFAULT context: $PROJECT_CONTEXT"
fi

debug_print "Program to run:\n%s\n" "$PROGRAM"

# Escape backslashes first
PROGRAM="$(echo "$PROGRAM" | sed -E 's/\\/\\\\/g')"
# Escape variable sign ($) to execute it inside runtime
PROGRAM="$(echo "$PROGRAM" | sed -E 's/\$/\\\$/g')"
# Then escape double-quotes, since they are used to enclose the program
PROGRAM="$(echo "$PROGRAM" | sed -E 's/"/\\"/g')"

command="env ${ENV_PREFIX[*]} $RUNTIME \"$PROGRAM\""

debug_print "Running..."

bash $ENTRYPOINT ${ENTRYPOINT_ARGS[*]} $SERVICE $COMMAND_VERB "$command"

for key in "${ENVIRONMENT_KEYS[@]}"; do
    unset $key
done
