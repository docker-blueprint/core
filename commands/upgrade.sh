#!/bin/bash

debug_switch_context "UPGRADE"

debug_print "Running the command..."

shift

MODE_FORCE=false
MODE_NO_BUILD=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
    -h | --help)
        printf "${CMD_COL}upgrade${RESET}"
        printf "\t\t\tUpgrade the blueprint version to the latest version\n"
        exit
        ;;
    -f | --force)
        MODE_FORCE=true
        ;;
    --no-build)
        MODE_NO_BUILD=true
        ;;
    esac

    shift
done

yq_read_value BLUEPRINT 'from'
yq_read_value PREVIOUS_VERSION 'version'

debug_print "Current version: $PREVIOUS_VERSION"

source "$ROOT_DIR/includes/blueprint/populate_env.sh" ""

cd "$BLUEPRINT_DIR"

target_branch="$(echo "$BLUEPRINT_QUALIFIED_NAME" | cut -d: -f2)"

CHECKPOINT="$(git rev-parse origin/$target_branch)"
if [[ $? -eq 0 ]]; then
    if [[ "$CHECKPOINT" != "$PREVIOUS_VERSION" ]]; then
        printf "New version available: ${CYAN}$CHECKPOINT${RESET}\n"
    else
        printf "Already using latest version\n"
        exit
    fi
else
    printf "${RED}ERROR${RESET}: Unable to checkout version $CHECKPOINT\n"
    exit 1
fi

cd "$PROJECT_DIR"

debug_print "New version: $CHECKPOINT"

if ! $MODE_NO_BUILD; then
    if ! $MODE_FORCE; then
        printf "Do you want to rebuild the project? (run with ${FLG_COL}--force${RESET} to always build)\n"
        printf "${YELLOW}WARNING${RESET}: This will ${RED}overwrite${RESET} existing docker files [y/N] "
        read -n 1 -r REPLY
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            yq_write_value "version" "$CHECKPOINT"
            bash $ENTRYPOINT up --force
        fi
    else
        yq_write_value "version" "$CHECKPOINT"
        bash $ENTRYPOINT up --force
    fi
else
    yq_write_value "version" "$CHECKPOINT"
    printf "Updated version to the latest without rebuilding\n"
    printf "You can build manually later with 'docker-blueprint build --force'\n"
    printf "\n"
fi
