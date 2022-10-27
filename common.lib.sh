#!/bin/bash

BASEDIR=$(dirname "$0")

linux_commons_file="$BASEDIR/linux-commons/lib.commons.sh"
if [ -f "$linux_commons_file" ]; then
    . "$linux_commons_file"
else
    echo "Required file does not exist at '$linux_commons_file'." && return 1
fi

env_vars_file="$BASEDIR/.env"
if [ -f "$env_vars_file" ]; then
    . "$env_vars_file"
else
    log_fail "Required file does not exist at '$env_vars_file'." && return 1
fi

occ_exec() {
    [ -z "$*" ] && log_invalid_args "No command given." && return 1

    docker exec --user www-data "$APP_CONTAINER_NAME" php occ "$@"
}

is_maintenance_mode_enabled() {
    occ_exec maintenance:mode | grep enabled &&
        return 0 ||
        return 1
}

require_enabled_maintenance_mode() {
    if is_maintenance_mode_enabled; then
        return 0
    else
        log_fail "Maintenance mode is required to be enabled." &&
            return 1
    fi
}

enable_maintenance_mode() {
    if is_maintenance_mode_enabled; then
        log_warn "Maintenance mode already enabled. Skip enabling maintenance mode." &&
            return 0
    fi

    occ_exec maintenance:mode --on &&
        log_success "Maintenance mode enabled" &&
        return 0

    log_fail "Failed to enable maintenance mode" &&
        return 1
}

disable_maintenance_mode() {
    if ! is_maintenance_mode_enabled; then
        log_warn "Maintenance mode is not enabled. Skip disabling maintenance mode." &&
            return 0
    fi

    occ_exec maintenance:mode --off &&
        log_success "Maintenance mode disabled" &&
        return 0

    log_fail "Failed to disable maintenance mode" &&
        return 1
}

dump_database() {
    local _db_dump_dir _db_dump_file
    _db_dump_dir="$__LOCAL_DIR"
    _db_dump_file="$_db_dump_dir/cloud-db-dump.sql"

    __internal_dump_database() {
        require_root_user &&
            require_enabled_maintenance_mode &&
            touch "$_db_dump_file" &&
            sudo_set_file_permission 'root:root' '400' "$_db_dump_file"
        docker exec --user www-data "$DB_CONTAINER_NAME" mysqldump -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" --single-transaction --protocol=tcp >"$_db_dump_file"
    }

    __internal_dump_database

    log_step_result "Database backup to '$_db_dump_file'"
}

backup_database() {
    require_root_user ||
        return 1

    local _maintenance_mode_enabled
    _maintenance_mode_enabled=$(is_maintenance_mode_enabled)

    if [ ! "$_maintenance_mode_enabled" ]; then
        enable_maintenance_mode ||
            return 1
    fi

    dump_database

    if [ ! "$_maintenance_mode_enabled" ]; then
        disable_maintenance_mode ||
            return 1
    fi

    log_step_result 'Backup database'
}

restore_database() {
    require_root_user ||
        return 1

    local _maintenance_mode_enabled
    _maintenance_mode_enabled=$(is_maintenance_mode_enabled)

    if [ ! "$_maintenance_mode_enabled" ]; then
        enable_maintenance_mode ||
            log_warn "Failed to enable maintenance mode"
    fi

    local _db_dump_dir _db_dump_file
    _db_dump_dir="$__LOCAL_DIR"
    _db_dump_file="$_db_dump_dir/cloud-db-dump.sql"

    [ ! -f "$_db_dump_file" ] && log_fail "DB dump file '$_db_dump_file' not found." && return 1

    docker exec --user www-data "$DB_CONTAINER_NAME" mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" -e "DROP DATABASE $MYSQL_DATABASE" --protocol=tcp &&
        log_success "Dropped database '$MYSQL_DATABASE'" &&
        docker exec --user www-data "$DB_CONTAINER_NAME" mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "CREATE DATABASE $MYSQL_DATABASE CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci" --protocol=tcp &&
        log_success "Created database '$MYSQL_DATABASE'" &&
        log_info 'Restoring database' &&
        mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" --protocol=tcp <"$_db_dump_file" &&
        log_success "Restored database '$MYSQL_DATABASE'"

    log_step_result "Restore database '$MYSQL_DATABASE'"

    log_info 'Generating data fingerprints' &&
        occ_exec maintenance:data-fingerprint &&
        log_success "Generate data fingerprints"

    if [ ! "$_maintenance_mode_enabled" ]; then
        disable_maintenance_mode ||
            return 1
    fi
}
