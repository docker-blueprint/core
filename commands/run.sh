#!/bin/bash

shift

#
# Read arguments
#

case $1 in
    -h|--help)
        printf "run <command>\t\t\tRun a command in a predefined environment\n"
        exit

        ;;
    *)
        COMMAND=$1
esac

read_keys POSSIBLE_COMMANDS "commands" "docker-blueprint.yml"

if [[ -z "$COMMAND" ]]; then
    bash $ENTRYPOINT run --help

    if [[ ${#POSSIBLE_COMMANDS[@]} > 0 ]]; then
        printf "${GREEN}Possible commands${RESET}:"
        for key in "${POSSIBLE_COMMANDS[@]}"; do
            printf " $key"
        done
        printf "\n"
    else
        printf "${YELLOW}This project has no commands\n"
    fi

    exit 1
fi

read_keys ENVIRONMENT_KEYS "commands.$COMMAND.environment" "docker-blueprint.yml"

echo "Setting environment..."

for key in "${ENVIRONMENT_KEYS[@]}"; do
    read_value value "commands.$COMMAND.environment.$key" "docker-blueprint.yml"
    if [[ -n ${value+x} ]]; then
        export $key=$value
    fi

    echo "$key=${!key}"
done

read_value command_string "commands.$COMMAND.command" "docker-blueprint.yml"

bash $ENTRYPOINT up -d
bash $ENTRYPOINT "$command_string"

for key in "${ENVIRONMENT_KEYS[@]}"; do
    unset $key
done

bash $ENTRYPOINT up -d
