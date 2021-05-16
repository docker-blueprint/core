#!/bin/bash

# Blueprint PULL command
#
# This command resolves blueprint name in format [VENDOR/]NAME[:TAG] and
# tries to clone the repository from GitHub.
# Default vendor is `docker-blueprint`, default tag is `master`.
#
# If NAME is a local directory & has at least one slash (/) the command
# generates sha1 hash of the path and copies this directory instead.
# This mode is useful for local blueprint development.
#
# This command supports two modes:
# - interactive (AS_FUNCTION=false): prints the progress to stdout
# - bash function (AS_FUNCTION=true): prints only the result to stdout
#
# Function mode allows to use this command in conjunction
# with others (i.e. create).

debug_switch_context "PULL"

#
# Read arguments
#

shift # Remove command name from the argument list

CLEAN_INSTALL=false
MODE_DRY_RUN=false
MODE_GET_QUALIFIED=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
    -h | --help)
        if [[ "$WITH_USAGE" -eq 1 ]]; then printf "Usage:\n"; fi
        printf "${CMD_COL}pull${RESET} [${ARG_COL}<blueprint>${RESET}] [${FLG_COL}options${RESET}]"
        printf "\tDownload the latest version of a blueprint\n"

        printf "  ${FLG_COL}--clean${RESET}"
        printf "\t\t\tRemove already existing copy of a blueprint and install fresh download\n"

        exit

        ;;
    --clean)
        CLEAN_INSTALL=true
        ;;
    --dry-run)
        MODE_DRY_RUN=true
        ;;
    --get-qualified-name)
        MODE_GET_QUALIFIED=true
        ;;
    *)
        if [[ -z $BLUEPRINT ]]; then
            BLUEPRINT="$1"
        fi
        ;;
    esac

    shift
done

if [[ -z "$BLUEPRINT" ]]; then
    ! $AS_FUNCTION && debug_print "No blueprint name provided - trying to resolve from $PROJECT_BLUEPRINT_FILE..."

    # Try to read blueprint name from docker-blueprint.yml
    if [[ -f "$PROJECT_BLUEPRINT_FILE" ]]; then
        yq_read_value BLUEPRINT 'from'
        if [[ -z "$BLUEPRINT" ]]; then
            ! $AS_FUNCTION && printf "${RED}ERROR${RESET}: Unable to resolve blueprint from project blueprint file.\n\n"
            WITH_USAGE=1 bash $ENTRYPOINT pull --help
            exit 1
        else
            ! $AS_FUNCTION && debug_print "Found blueprint '$BLUEPRINT' in project blueprint file"
        fi
    else
        bash $ENTRYPOINT pull --help
        exit 1
    fi
fi

#
# Parse blueprint name and branch
#

IFS=':' read -r -a BLUEPRINT_PART <<<$BLUEPRINT

BLUEPRINT=${BLUEPRINT_PART[0]}

if [[ -z ${BLUEPRINT_PART[1]} ]]; then
    BLUEPRINT_BRANCH="master"
else
    BLUEPRINT_BRANCH=${BLUEPRINT_PART[1]}
fi

#
# Parse blueprint maintainer and name
#

IFS='/' read -r -a BLUEPRINT_PART <<<$BLUEPRINT

BLUEPRINT_MAINTAINER=${BLUEPRINT_PART[0]}
BLUEPRINT_NAME=${BLUEPRINT_PART[1]}

if [[ -z ${BLUEPRINT_PART[1]} ]]; then
    # This is an official blueprint
    BLUEPRINT_MAINTAINER="docker-blueprint"
    BLUEPRINT_NAME=${BLUEPRINT_PART[0]}
else
    # This is a third-party blueprint
    BLUEPRINT_MAINTAINER=${BLUEPRINT_PART[0]}
    BLUEPRINT_NAME=${BLUEPRINT_PART[1]}
fi

BLUEPRINT_QUALIFIED_NAME="$BLUEPRINT_MAINTAINER/$BLUEPRINT_NAME:$BLUEPRINT_BRANCH"

if $MODE_GET_QUALIFIED; then
    if $AS_FUNCTION; then
        printf $BLUEPRINT_QUALIFIED_NAME
    else
        echo $BLUEPRINT_QUALIFIED_NAME
    fi
    exit
fi

#
# Check if blueprint is a local directory
#

if [[ -d $BLUEPRINT ]] && [[ $BLUEPRINT =~ "/" || $BLUEPRINT =~ "." || $BLUEPRINT =~ ".." ]]; then
    mkdir -p "$LOCAL_DIR/blueprints/.local"

    HASH=$(echo -n "$BLUEPRINT" | openssl dgst -sha1 | sed 's/^.* //')
    BLUEPRINT_DIR="$LOCAL_DIR/blueprints/.local/$HASH"

    if ! $AS_FUNCTION; then
        echo "Copying '$BLUEPRINT'..."
    fi

    rm -rf $BLUEPRINT_DIR
    cp -rf $BLUEPRINT $BLUEPRINT_DIR
else
    #
    # Build path for the resolved blueprint
    #

    if [[ $BLUEPRINT_MAINTAINER = "docker-blueprint" ]]; then
        BLUEPRINT_DIR="$LOCAL_DIR/blueprints/_/$BLUEPRINT_NAME"
    else
        BLUEPRINT_DIR="$LOCAL_DIR/blueprints/$BLUEPRINT_MAINTAINER/$BLUEPRINT_NAME"
    fi

    PREVIOUS_DIR=$PWD

    if $AS_FUNCTION; then
        GIT_ARGS="-q"
    fi

    #
    # Try to clone or update blueprint repository
    #

    if ! $AS_FUNCTION; then
        echo "Pulling blueprint '$BLUEPRINT_QUALIFIED_NAME'..."
    fi

    if $CLEAN_INSTALL; then
        echo "Removing previous version of the blueprint..."
        rm -rf $BLUEPRINT_DIR
    fi

    if [[ ! -d $BLUEPRINT_DIR ]]; then
        BASE_URL="https://github.com/$BLUEPRINT_MAINTAINER/$BLUEPRINT_NAME"

        #
        # Check if repository exists and is a blueprint
        #

        if curl --output /dev/null --silent --head --fail "$BASE_URL/blob/master/blueprint.yml"; then
            if ! $MODE_DRY_RUN; then
                GIT_TERMINAL_PROMPT=0 \
                    git clone "$BASE_URL.git" $GIT_ARGS \
                    $BLUEPRINT_DIR
            fi
        else
            printf "${RED}ERROR${RESET}: Provided repository is not a blueprint.\n"
            exit 1
        fi
    else
        PREVIOUS_DIR="$PWD"
        cd "$BLUEPRINT_DIR"
        git checkout master &>/dev/null
        git pull &>/dev/null
        if [[ $? -gt 0 ]]; then
            cd "$PREVIOUS_DIR"
            printf "${RED}ERROR${RESET}: Blueprint directory has local changes\n"
            printf "You can clear local changes with 'docker-blueprint pull --clean'\n"
            exit 1
        fi
        cd "$PREVIOUS_DIR"
    fi
fi

if ! $MODE_DRY_RUN; then

    #
    # Reset to specified branch or tag
    #

    cd $BLUEPRINT_DIR

    # Always checkout master first
    git checkout master &>/dev/null

    BRANCHES=($(git --no-pager branch -a --list --color=never | grep -v HEAD | sed -e 's/\s*remotes\/origin\///' | sed -E 's/\* //' | sed -E 's/\s+//' | sort | uniq))
    TAGS=($(git --no-pager tag --list --color=never))

    for tag in "${TAGS[@]}"; do
        BRANCHES+=($tag)
    done

    FOUND=false

    for branch in "${BRANCHES[@]}"; do
        if [[ $BLUEPRINT_BRANCH = $branch ]]; then
            if $AS_FUNCTION; then
                git checkout $BLUEPRINT_BRANCH &>/dev/null
            else
                git checkout $BLUEPRINT_BRANCH
            fi
            FOUND=true
            break
        fi
    done

    if ! $FOUND; then
        if ! $AS_FUNCTION; then
            printf "${RED}ERROR${RESET}: Unable to find version '$BLUEPRINT_BRANCH'.\n"
        fi
        exit 1
    else
        if ! $AS_FUNCTION; then
            echo "Successfuly pulled version '$BLUEPRINT_BRANCH'."
        fi
    fi

    yq_read_value CHECKPOINT 'version'

    # Set the blueprint repository to the version specified.
    # This allows to always safely reproduce previous versions of the blueprint.
    if [[ -n "$CHECKPOINT" ]]; then
        if ! $AS_FUNCTION; then
            printf "${BLUE}INFO${RESET}: Version lock applied: ${CYAN}$CHECKPOINT${RESET}\n"
            git checkout $CHECKPOINT 2>/dev/null
        else
            git checkout $CHECKPOINT &>/dev/null
        fi
    else
        ! $AS_FUNCTION && printf "${BLUE}INFO${RESET}: No version lock found - using latest version.\n"
    fi

    cd $PREVIOUS_DIR

fi

if $AS_FUNCTION; then
    printf $BLUEPRINT_DIR
fi
