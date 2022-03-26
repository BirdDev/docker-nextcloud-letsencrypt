#!/bin/bash

BASEDIR=$(dirname "$0")

env_vars_file="$BASEDIR/.env"
if [ -f "$env_vars_file" ]; then
    . "$env_vars_file"
else
    echo "Required file does not exist at '$env_vars_file'." && return 1
fi

linux_commons_file="$BASEDIR/linux-commons/lib.commons.sh"
if [ -f "$linux_commons_file" ]; then
    . "$linux_commons_file"
else
    echo "Required file does not exist at '$linux_commons_file'." && return 1
fi

require_enabled_maintenance_mode() {
    if docker exec --user www-data "$APP_CONTAINER_NAME" php occ maintenance:mode | grep enabled; then
        return 0
    else
        echo "Maintenance mode is required to be enabled" &&
            return 1
    fi
}

enable_maintenance_mode() {
    docker exec --user www-data "$APP_CONTAINER_NAME" php occ maintenance:mode --on
}

disable_maintenance_mode() {
    docker exec --user www-data "$APP_CONTAINER_NAME" php occ maintenance:mode --off
}

dump_database() {
    require_root_user &&
    require_enabled_maintenance_mode &&
        docker exec --user www-data "$DB_CONTAINER_NAME" mysqldump --single-transaction -h localhost -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" --protocol=tcp >"$__LOCAL_DIR/cloud-db-dump.sql"
}
