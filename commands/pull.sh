#!/bin/bash

# Blueprint PULL command
#
# This command resolves blueprint name in format [VENDOR/]NAME[:TAG] and
# tries to clone the repository from GitHub.
# Default vendor is `docker-blueprint`, default tag is `origin/master`.
#
# If NAME is a local directory & has at least one slash (/) the command
# generates sha1 hash of the path and copies this directory instead.
# This mode is made for convinient blueprint development.
#
# This command supports two modes:
# - interactive (AS_FUNCTION=false): prints the progress to stdout
# - bash function (AS_FUNCTION=true): prints only the result to stdout
#
# Function mode allows to use this command in conjunction
# with others (i.e. create).

shift

#
# Read arguments
#

case $1 in
    -h|--help)
        printf "${CMD_COL}pull${RESET} ${ARG_COL}<blueprint>${RESET}"
        printf "\t\tDownload the latest version of blueprint\n"

        exit

        ;;
    *)
        if [[ -z "$1" ]]; then
            bash $ENTRYPOINT pull --help
            exit 1
        fi

        BLUEPRINT=$1
esac

if [[ -z "$1" ]]; then
    echo "Usage: $EXECUTABLE_NAME pull <blueprint>"
    exit 1
fi

BLUEPRINT=$1

shift

#
# Check if blueprint is a local directory
#

if [[ -d $BLUEPRINT ]] && [[ $BLUEPRINT =~ "/" || $BLUEPRINT =~ "." || $BLUEPRINT =~ ".." ]]; then
    mkdir -p "$DIR/blueprints/@"

    HASH=$(echo -n "$BLUEPRINT" | openssl dgst -sha1 | sed 's/^.* //')
    BLUEPRINT_DIR="$DIR/blueprints/@/$HASH"

    if ! $AS_FUNCTION; then
        echo "Copying '$BLUEPRINT'..."
    fi

    rm -rf $BLUEPRINT_DIR
    cp -rf $BLUEPRINT $BLUEPRINT_DIR

    if $AS_FUNCTION; then
        echo $BLUEPRINT_DIR
    fi

    exit
fi

#
# Parse blueprint maintainer and name
#

IFS='/' read -r -a BLUEPRINT_PART <<< $BLUEPRINT

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

#
# Parse blueprint name and branch
#

IFS=':' read -r -a BLUEPRINT_PART <<< $BLUEPRINT_NAME

BLUEPRINT_NAME=${BLUEPRINT_PART[0]}

if [[ -z ${BLUEPRINT_PART[1]} ]]; then
    BLUEPRINT_BRANCH="master"
else
    BLUEPRINT_BRANCH=${BLUEPRINT_PART[1]}
fi

#
# Build path for the resolved blueprint
#

if [[ $BLUEPRINT_MAINTAINER = "docker-blueprint" ]]; then
    BLUEPRINT_DIR="$DIR/blueprints/_/$BLUEPRINT_NAME"
else
    BLUEPRINT_DIR="$DIR/blueprints/$BLUEPRINT_MAINTAINER/$BLUEPRINT_NAME"
fi

PREVIOUS_DIR=$PWD

if $AS_FUNCTION; then
    GIT_ARGS="-q"
fi

#
# Try to clone or update blueprint repository
#

if [[ -d $BLUEPRINT_DIR ]]; then
    cd $BLUEPRINT_DIR
    git pull $GIT_ARGS
    cd $PREVIOUS_DIR
else
    BASE_URL="https://github.com/$BLUEPRINT_MAINTAINER/$BLUEPRINT_NAME"

    #
    # Check if repository exists and is a blueprint
    #

    if curl --output /dev/null --silent --head --fail "$BASE_URL/blob/master/blueprint.yml"; then
        GIT_TERMINAL_PROMPT=0 \
        git clone "$BASE_URL.git" $GIT_ARGS \
        $BLUEPRINT_DIR
    else
        echo "Provided repository is not a blueprint."
        exit 1
    fi
fi

#
# Reset to specified branch or tag
#

cd $BLUEPRINT_DIR

# Always synchronize with remote
git -c advice.detachedHead=false reset --hard "origin/master" > /dev/null

BRANCHES="$(git --no-pager branch -a --list --color=never | grep -v HEAD | grep remotes/origin | sed -e 's/\s*remotes\/origin\///')"
TAGS="$(git --no-pager tag --list --color=never)"

for tag in "${TAGS[@]}"; do
    BRANCHES+=($tag)
done

FOUND=false

for branch in "${BRANCHES[@]}"; do
    if [[ $BLUEPRINT_BRANCH = $branch ]]; then
        if ! $AS_FUNCTION; then
            echo "Found version '$BLUEPRINT_BRANCH'."
        fi
        git -c advice.detachedHead=false reset --hard $BLUEPRINT_BRANCH > /dev/null
        FOUND=true
        break
    fi
done

if ! $FOUND; then
    if ! $AS_FUNCTION; then
        echo "${RED}ERROR${RESET}: Unable to find version '$BLUEPRINT_BRANCH'."
    fi
    exit 1
fi

cd $PREVIOUS_DIR

if $AS_FUNCTION; then
    echo $BLUEPRINT_DIR
fi
