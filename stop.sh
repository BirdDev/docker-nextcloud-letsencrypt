#!/bin/bash

BASEDIR=$(dirname "$0")

common_lib_file="$BASEDIR/common.lib.sh"
if [ -f "$common_lib_file" ]; then
    . "$common_lib_file"
else
    echo "Required file does not exist at '$common_lib_file'." && return 1
fi

docker-compose down
