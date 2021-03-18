#!/bin/bash

ENV_PREFIX=()

ENV_PREFIX+=("COMPOSE_PROJECT_NAME=${PROJECT_NAME}")

FILES=()

FILES+=("-f docker-compose.yml")

if [[ -n "$PROJECT_CONTEXT" ]]; then
    FILES+=("-f docker-compose.$PROJECT_CONTEXT.yml")
fi

export DOCKER_COMPOSE="env ${ENV_PREFIX[@]} docker-compose ${FILES[@]}"
