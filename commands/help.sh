#!/bin/bash

printf "Development software stack builder for docker.\n"
printf "\n"
printf "Usage:\n"
printf "  $EXECUTABLE_NAME <command>     Run program command or 'exec' command in the default service\n"
printf "  $EXECUTABLE_NAME -h|--help     Display this help message\n"
printf "\n"
printf "Example:\n"
printf "  # Create PHP development environment for Laravel framework with MySQL and Redis:\n"
printf "  $EXECUTABLE_NAME create php --env laravel --with mysql redis\n"
printf "\n"
printf "  # Compile front-end assets:\n"
printf "  $EXECUTABLE_NAME npm run dev   # Executes command in the default service\n"
printf "\n"
printf "Commands:\n"
printf "\n"
printf "  exec <service> <command>\tExecute 'docker-compose exec' as current host user\n"
printf "  [service] sudo <command>\tExecute 'docker-compose exec' as root against service\n"
printf "                          \t(service parameter can be omitted to run against the default)\n"

FILES=("$ROOT_DIR/commands/"*.sh)

for file in "${FILES[@]}"; do
    command=$(basename "$file" .sh)

    if [[ $command != "help" ]]; then
        printf "\n"
        printf "$(bash $ENTRYPOINT $command --help | pr -To 2)\n"
    fi
done
