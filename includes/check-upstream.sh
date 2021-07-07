#!/bin/bash

if [[ -z "$CHECK_UPSTREAM_WAS_CALLED" ]]; then

    export CHECK_UPSTREAM_WAS_CALLED=1

    new_version_available_flag_file="$CACHE_DIR/.new-version-available"
    update_check_timestamp_file="$CACHE_DIR/.update-check-timestamp"
    update_check_interval=86400 # One day in seconds

    current_timestamp="$(date +%s)"
    previous_timestamp=0

    if [[ -f "$update_check_timestamp_file" ]]; then
        previous_timestamp="$(cat "$update_check_timestamp_file")"
    fi

    timestamp_delta=$(($current_timestamp - $previous_timestamp))

    if [[ "$timestamp_delta" -gt "$update_check_interval" ]]; then
        echo "$current_timestamp" >"$update_check_timestamp_file"

        PREVIOUS_DIR=$PWD

        cd $ROOT_DIR
        git remote update >/dev/null
        git status -uno | grep 'branch is behind' >/dev/null
        cd $PREVIOUS_DIR

        if [[ $? > 0 ]]; then
            rm -f "$new_version_available_flag_file"
            exit # No new commits
        else
            touch "$new_version_available_flag_file"
        fi
    fi

    if [[ -f "$new_version_available_flag_file" ]]; then
        printf "\n"
        printf "New version is available!\n"
        printf "Install with ${EXE_COL}docker-blueprint${RESET} ${CMD_COL}update${RESET}\n"
        printf "\n"
    fi

fi
