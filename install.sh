#!/bin/bash

REQUIREMENTS=(
    git
    docker
    docker-compose
)

for PROGRAM in "${REQUIREMENTS[@]}"; do
    if [[ -z $(which $PROGRAM) ]]; then
        echo "Error: '$PROGRAM' is not installed. Please install '$PROGRAM' first."
        exit 1
    fi
done

PROJECT_DIR=~/.docker-blueprint

if [[ -d "$PROJECT_DIR" ]]; then
    echo "Updating docker-blueprint to the latest version..."
    cd "$PROJECT_DIR"
    git pull
else
    echo "Downloading the latest version of docker-blueprint..."
    git clone https://github.com/docker-blueprint/core.git "$PROJECT_DIR"
    chmod +x "$PROJECT_DIR/entrypoint.sh"
fi

if [[ -z $(which docker-blueprint) ]]; then

    BIN_DIRS=(
        /usr/local/bin
        /usr/bin
    )

    for DIR in "${BIN_DIRS[@]}"; do
        if [[ -d "$DIR" ]]; then
            echo "Creating link in '$DIR'..."

            sudo ln -sf "$PROJECT_DIR/entrypoint.sh" "$DIR/docker-blueprint"

            if [[ $? -eq 0 ]]; then
                echo "Installed successuflly."
                echo ""
                echo "Run the program by typing 'docker-blueprint'"
                exit 0
            else
                echo "Unable to create link."
                exit 1
            fi
        fi
    done

fi
