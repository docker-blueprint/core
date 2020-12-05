#!/bin/bash

printf "Modular ephemeral development environments.\n"
printf "\n"
printf "Usage:\n"
printf "  $EXE_COL$EXECUTABLE_NAME$RESET ${ARG_COL}<command>${RESET}"
printf "\t\t\tRun program command or 'exec' command in the default service\n"
printf "  $EXE_COL$EXECUTABLE_NAME$RESET ${FLG_COL}-h${RESET}|${FLG_COL}--help${RESET}"
printf "\t\t\tDisplay this help message\n"
printf "\n"
printf "Examples:\n"
printf "  Create PHP development environment for Laravel framework\n"
printf "  with intl & gd extensions and MySQL & Redis integration:\n"
printf "    $EXE_COL$EXECUTABLE_NAME$RESET ${CMD_COL}new${RESET} ${ARG_COL}php${RESET} ${FLG_COL}--env${RESET} ${FLG_VAL_COL}laravel${RESET} ${FLG_COL}--with${RESET} ${FLG_VAL_COL}intl gd mysql redis${RESET}\n"
printf "\n"
printf "  Compile front-end assets:\n"
printf "    $EXE_COL$EXECUTABLE_NAME$RESET ${ARG_COL}npm run dev${RESET}"
printf "\t\tExecutes command in the default service\n"
printf "    $EXE_COL$EXECUTABLE_NAME$RESET ${SRV_COL}app${RESET} ${CMD_COL}exec${RESET} ${ARG_COL}npm run dev${RESET}"
printf "\tDoes the same thing, but service name is specified explicitly\n"
printf "\n"
printf "  Connect to MySQL as root user:\n"
printf "    $EXE_COL$EXECUTABLE_NAME$RESET ${SRV_COL}database${RESET} ${CMD_COL}sudo${RESET} ${ARG_COL}mysql${RESET}\n"
printf "\n"
printf "Commands:\n"
printf "  [${SRV_COL}service${RESET} ${CMD_COL}exec${RESET}] ${ARG_COL}<command>${RESET}"
printf "\tExecute 'docker-compose exec' as current host user\n"

printf "  [${SRV_COL}service${RESET}] ${CMD_COL}sudo${RESET} ${ARG_COL}<command>${RESET}"
printf "\tExecute 'docker-compose exec' as root against service\n"
printf "                          \t(service parameter can be omitted to run against the default)\n"

FILES=("$ROOT_DIR/commands/"*.sh)

for file in "${FILES[@]}"; do
    command=$(basename "$file" .sh)

    if [[ $command != "help" ]]; then
        printf "$(bash $ENTRYPOINT $command --help | pr -To 2)\n"
    fi
done
