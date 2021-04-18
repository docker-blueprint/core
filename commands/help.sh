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
printf "    ${FLG_COL}--context${RESET} <name>"
printf "\tForce to use the given project context instead of default\n"
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
