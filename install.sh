#!/bin/bash

REQUIREMENTS=(
    git
    docker
    docker-compose
)

for PROGRAM in "${REQUIREMENTS[@]}"; do
    if [[ -z "$(which $PROGRAM)" ]]; then
        echo "Error: '$PROGRAM' is not installed. Please install '$PROGRAM' first."
        exit 1
    fi
done

PROJECT_DIR=~/.docker-blueprint
ENTRYPOINT="$PROJECT_DIR/entrypoint.sh"

if [[ -d "$PROJECT_DIR" ]]; then
    echo "Updating docker-blueprint to the latest version..."
    cd "$PROJECT_DIR"
    git pull
else
    echo "Downloading the latest version of docker-blueprint..."
    git clone https://github.com/docker-blueprint/core.git "$PROJECT_DIR"
    chmod +x "$ENTRYPOINT"
fi

SUDO="$(which sudo 2>/dev/null)"

which docker-blueprint >/dev/null

if [[ $? > 0 ]]; then

    BIN_DIRS=(
        /usr/local/bin
        /usr/bin
    )

    for DIR in "${BIN_DIRS[@]}"; do
        if [[ -d "$DIR" ]]; then
            echo "Creating link in '$DIR'..."

            $SUDO ln -sf "$ENTRYPOINT" "$DIR/docker-blueprint"
            $SUDO ln -sf "$ENTRYPOINT" "$DIR/dob"

            if [[ $? -eq 0 ]]; then
                echo "Installed successuflly."
                echo ""
                echo "Run the program by typing 'dob' (or the long version: docker-blueprint)"
                exit 0
            else
                echo "Unable to create link."
                exit 1
            fi
        fi
    done

fi
