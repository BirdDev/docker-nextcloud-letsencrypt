#!/bin/bash

BASEDIR=$(dirname "$0")

common_lib_file="$BASEDIR/common.lib.sh"
if [ -f "$common_lib_file" ]; then
    . "$common_lib_file"
else
    log_fail "Required file does not exist at '$common_lib_file'." && return 1
fi

backup_database() {
    local _maintenance_mode_enabled
    _maintenance_mode_enabled=$(is_maintenance_mode_enabled)

    if [ ! "$_maintenance_mode_enabled" ]; then
        enable_maintenance_mode || return 1
    fi

    dump_database

    if [ ! "$_maintenance_mode_enabled" ]; then
        disable_maintenance_mode
    fi
}

backup_database
