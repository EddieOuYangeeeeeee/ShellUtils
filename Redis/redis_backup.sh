#!/bin/bash
###
 # @Author: Eddie
 # @Date: 2024-12-01 21:26:20
 # @LastEditors: Do not edit
 # @LastEditTime: 2024-12-01 22:12:00
###

# 配置备份目录和 Redis 数据目录
BACKUP_DIR="/backup/redis"
BACKUP_LOG="/backup/redis/backup.log"
REDIS_DATA_DIR="/data/redis"
RDB_FILE="dump.rdb"
ALARM_SHELL_PATH="/deploy/redis/alert_send_webhook_markdown.py"

# 获取当前日期和星期几
CURRENT_DATE=$(date +%F)
DAY_OF_WEEK=$(date +%u)

# 备份文件名（包括日期）
BACKUP_FILE="${BACKUP_DIR}/redis_backup_${CURRENT_DATE}.tar.gz"

mkdir -p "$BACKUP_DIR"

# 日志函数
log_info() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") [INFO] $1" >> "$BACKUP_LOG"
}

log_error() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") [ERROR] $1" >> "$BACKUP_LOG"
}

# 复制 Redis 数据文件到备份目录
copy_redis_data() {
    log_info "Copying Redis data file to backup directory..."
    cp "${REDIS_DATA_DIR}/${RDB_FILE}" "${BACKUP_DIR}/"
    if [[ $? -ne 0 ]]; then
        log_error "Failed to copy Redis data file!"
        exit 1
    fi
}

# 压缩备份文件
compress_backup() {
    log_info "Compressing backup file ${BACKUP_FILE}..."
    tar -czf "${BACKUP_FILE}" -C "${BACKUP_DIR}" "${RDB_FILE}"
    if [[ $? -ne 0 ]]; then
        log_error "Failed to compress the backup file!"
        exit 1
    fi
}

# 检查备份文件是否有效
check_backup() {
    log_info "Checking if backup file ${BACKUP_FILE} is valid..."
    if [[ -f "${BACKUP_FILE}" && -s "${BACKUP_FILE}" ]]; then
        log_info "Backup successful: ${BACKUP_FILE}"
    else
        log_error "Backup failed, compressed file is invalid!"
        /usr/bin/python3 $ALARM_SHELL_PATH full
        exit 1
    fi
}

# 清理过期的备份文件
cleanup_old_backups() {
    log_info "Cleaning up old backup files..."
    if [[ ${DAY_OF_WEEK} -eq 7 ]]; then
        # 每周日删除 7 天前的备份
        deleted_files=$(find "${BACKUP_DIR}" -name "redis_backup_*" -mtime +7 -exec rm -f {} \;)
        if [[ -n $deleted_files ]]; then
            log_info "Deleted backups older than 7 days"
        else
            log_info "No old backups found to delete."
        fi
    fi
}

# 删除临时的 dump.rdb 文件
cleanup_temp_files() {
    log_info "Deleting temporary backup files..."
    rm -f "${BACKUP_DIR}/${RDB_FILE}"
}

# 执行备份操作
perform_backup() {
    copy_redis_data
    compress_backup
    check_backup
    cleanup_old_backups
    cleanup_temp_files
}

# 执行备份
perform_backup
/usr/bin/python3 $ALARM_SHELL_PATH full