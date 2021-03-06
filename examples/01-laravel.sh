#!/bin/bash

printf "  Laravel application development environment\n"
printf "\n"
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
