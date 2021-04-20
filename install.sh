#!/bin/bash

HIGHLIGHT="\033[1;33m"
RESET="\033[0;0m"

REQUIREMENTS=(
    git
)

for PROGRAM in "${REQUIREMENTS[@]}"; do
    if [[ -z "$(which $PROGRAM)" ]]; then
        echo "Error: '$PROGRAM' is not installed. Please install '$PROGRAM' first."
        exit 1
    fi
done

is_wsl=false

if grep -qEi "(Microsoft|WSL)" /proc/version &>/dev/null; then
    is_wsl=true
fi

can_install_docker=false

is_ubuntu=false
if lsb_release -si &>/dev/null | grep -qEi "Ubuntu"; then
    is_ubuntu=true
    can_install_docker=true
fi

#
# docker installer
#

if [[ -z "$(which docker)" ]]; then
    printf "You do not appear to have 'docker' installed (${HIGHLIGHT}https://docker.com${RESET})\n"

    if $is_wsl; then
        printf "We detected that you are running this installer under WSL.\n"
        printf "Please install Docker for Desktop for the best experience:\n"
        printf "${HIGHLIGHT}https://www.docker.com/products/docker-desktop${RESET}\n"
        printf "\n"
        printf "Do you want to continue installing? [y/N] "
        read -n 1 -r REPLY
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        if $can_install_docker; then
            printf "We can attempt to automatically install 'docker' using convinience script:\n"
            printf "${HIGHLIGHT}https://docs.docker.com/engine/install/ubuntu/#install-using-the-convenience-script${RESET}\n"
            printf "\n"
            printf "Do you want to automatically install 'docker'? [Y/n] "
            read -n 1 -r REPLY
            echo ""
            if [[ -z "$REPLY" ]] || [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "Trying to install 'docker'..."
                curl -fsSL https://get.docker.com | sh
                if [[ $? > 0 ]]; then
                    echo "Unable to install 'docker', skipping..."
                fi

                if $is_ubuntu; then
                    sudo apt-get install -y uidmap
                    curl -fsSL https://get.docker.com/rootless | sh
                fi
            fi
        fi
    fi
    echo ""
fi

#
# docker-compose installer
#

if [[ -z "$(which docker-compose)" ]]; then
    printf "You do not appear to have 'docker-compose' installed (${HIGHLIGHT}https://docs.docker.com/compose/install${RESET})\n"

    printf "We can attempt to automatically install 'docker-compose' using curl:\n"
    printf "${HIGHLIGHT}https://docs.docker.com/compose/install/#install-compose-on-linux-systems${RESET}\n"
    printf "\n"
    printf "Do you want to automatically install 'docker-compose'? [Y/n] "
    read -n 1 -r REPLY
    echo ""
    if [[ -z "$REPLY" ]] || [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Trying to install 'docker-compose'..."
        sudo curl -L "https://github.com/docker/compose/releases/download/1.29.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        if [[ $? > 0 ]]; then
            echo "Unable to install 'docker-compose', skipping..."
        else
            sudo chmod +x /usr/local/bin/docker-compose
        fi
    fi
    echo ""
fi

#
# yq installer
#

if [[ -z "$(which yq)" ]]; then
    printf "You do not appear to have 'yq' installed (${HIGHLIGHT}https://github.com/mikefarah/yq${RESET})\n"
    printf "For the best experience it is recommended to install a standalone version of 'yq'\n"
    printf "\n"
    printf "Do you want to attempt to automatically install 'yq'? [Y/n] "
    read -n 1 -r REPLY
    echo ""
    if [[ -z "$REPLY" ]] || [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Trying to install using webi..."
        curl -sS https://webinstall.dev/yq@4 | bash
        printf "\n"
        printf "${HIGHLIGHT}Please restart your shell in order for the changes to take effect${RESET}\n"
        printf "\n"
    fi
fi

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
