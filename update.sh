#!/bin/bash

BASEDIR=$(dirname "$0")

common_lib_file="$BASEDIR/common.lib.sh"
if [ -f "$common_lib_file" ]; then
    . "$common_lib_file"
else
    echo "Required file does not exist at '$common_lib_file'." && return 1
fi

# Enable mainentance mode
enable_maintenance_mode

log_info "Updating images" &&
    docker-compose pull &&
    log_info "Stopping instance" &&
    "$BASEDIR/stop.sh" &&
    log_info "Starting instance" &&
    "$BASEDIR/start.sh"

# Disable mainentance mode
disable_maintenance_mode
