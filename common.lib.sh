#!/bin/bash

BASEDIR=$(dirname "$0")

env_vars_file="$BASEDIR/.env"
if [ -f "$env_vars_file" ]; then
    . "$env_vars_file"
else
    log_fail "Required file does not exist at '$env_vars_file'." && return 1
fi

linux_commons_file="$BASEDIR/linux-commons/lib.commons.sh"
if [ -f "$linux_commons_file" ]; then
    . "$linux_commons_file"
else
    log_fail "Required file does not exist at '$linux_commons_file'." && return 1
fi

is_maintenance_mode_enabled() {
    docker exec --user www-data "$APP_CONTAINER_NAME" php occ maintenance:mode | grep enabled &&
        return 0 ||
        return 1
}

require_enabled_maintenance_mode() {
    if is_maintenance_mode_enabled; then
        return 0
    else
        log_fail "Maintenance mode is required to be enabled" &&
            return 1
    fi
}

enable_maintenance_mode() {
    is_maintenance_mode_enabled ||
        docker exec --user www-data "$APP_CONTAINER_NAME" php occ maintenance:mode --on
}

disable_maintenance_mode() {
    is_maintenance_mode_enabled &&
        docker exec --user www-data "$APP_CONTAINER_NAME" php occ maintenance:mode --off
}

dump_database() {
    local _db_dump_dir
    _db_dump_dir="$__LOCAL_DIR/cloud-db-dump.sql"

    __internal_dump_database() {
        require_root_user &&
            require_enabled_maintenance_mode &&
            docker exec --user www-data "$DB_CONTAINER_NAME" mysqldump -h localhost -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" --single-transaction --protocol=tcp >"$_db_dump_dir"
    }

    if __internal_dump_database; then
        log_success "Database backup to '$_db_dump_dir' ${STATUS_DONE}"
    else
        log_fail "Database backup to '$_db_dump_dir' ${STATUS_FAILED}"
    fi
}
