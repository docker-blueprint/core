#!/bin/bash

printf "Modular ephemeral development environments.\n"
printf "\n"
printf "Usage:\n"
printf "  $EXE_COL$EXECUTABLE_NAME$RESET [${FLG_COL}options${RESET}] ${ARG_COL}<command>${RESET}"
printf "\tRun program command or 'exec' command in the default service\n"

printf "    ${FLG_COL}-h${RESET}, ${FLG_COL}--help${RESET}"
printf "\t\t\t"
printf "Display this help message\n"
printf "    ${FLG_COL}-T${RESET}"
printf "\t\t\t\tDisable pseudo-tty allocation. Propagates -T to 'docker-compose exec'\n"
printf "    ${FLG_COL}-c${RESET}, ${FLG_COL}--context${RESET} <name>"
printf "\tForce to use the given project context instead of default\n"
printf "\n"
printf "Examples:\n"
printf "  Create PHP development environment for Laravel framework\n"
printf "  with intl & gd extensions and MySQL & Redis integration:\n"
printf "    $EXE_COL$EXECUTABLE_NAME$RESET ${CMD_COL}new${RESET} ${ARG_COL}php${RESET} ${FLG_COL}--env${RESET} ${FLG_VAL_COL}laravel${RESET} ${FLG_COL}--with${RESET} ${FLG_VAL_COL}intl gd mysql redis${RESET}\n"
printf "\n"
printf "  Compile front-end assets:\n"
printf "    $EXE_COL$EXECUTABLE_NAME$RESET ${ARG_COL}npm run dev${RESET}"
printf "\t\t"
printf "Executes command in the default service"
printf "\n"
printf "    $EXE_COL$EXECUTABLE_NAME$RESET ${SRV_COL}app${RESET} ${CMD_COL}exec${RESET} ${ARG_COL}npm run dev${RESET}"
printf "\t"
printf "Does the same thing, but service name is specified explicitly"
printf "\n\n"
printf "  Connect to MySQL as root user:\n"
printf "    $EXE_COL$EXECUTABLE_NAME$RESET ${SRV_COL}database${RESET} ${CMD_COL}sudo${RESET} ${ARG_COL}mysql${RESET}\n"
printf "\n"
printf "Commands:\n"
printf "  [${SRV_COL}service${RESET}] [${CMD_COL}exec${RESET}] ${ARG_COL}<command>${RESET}"
printf "\t"
printf "Execute 'docker-compose exec' as current host user\n"

printf "  [${SRV_COL}service${RESET}] ${CMD_COL}sudo${RESET} ${ARG_COL}<command>${RESET}"
printf "\t"
printf "Execute 'docker-compose exec' as root against service\n"
printf "\t\t\t\t"
printf "(service parameter can be omitted to run against the default)\n"

FILES=("$ROOT_DIR/commands/"*.sh)

for file in "${FILES[@]}"; do
    command=$(basename "$file" .sh)

    case "$command" in
    help | module | env)
        continue
        ;;
    *)
        printf "$(bash $ENTRYPOINT $command --help | pr -To 2)\n"
        ;;
    esac
done
