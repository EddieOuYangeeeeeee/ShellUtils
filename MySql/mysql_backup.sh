#!/bin/bash
set -e

# MySQL 配置
MySql_USER="root"
MySql_PASSWORD="hw2dBxzB@123"
MySql_HOST="localhost"
BACKUP_DIR="/backup/mysql"
LOG_FILE="$BACKUP_DIR/backup.log"
LAST_BACKUP_FILE="$BACKUP_DIR/last_backup_pos.txt"
ALARM_SHELL_PATH="/deploy/mysql/alert_send_webhook_markdown.py"

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 日志函数
log_info() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") [INFO] $1" >> "$LOG_FILE"
}

send_webhook_message() {
    WEBHOOK_URL="$1"         # Webhook 接收消息的 URL
    MESSAGE="$2"             # 要发送的消息内容
    EVENT_TYPE="${3:-info}"  # 消息类型（可选，默认值为 info）

    # 创建 JSON 数据
    PAYLOAD=$(cat <<EOF
{
    "event_type": "$EVENT_TYPE",
    "message": "$MESSAGE",
    "timestamp": "$(date +%Y-%m-%dT%H:%M:%S)"
}
EOF
)

    # 发送 HTTP POST 请求
    curl -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "$WEBHOOK_URL"

    if [ $? -eq 0 ]; then
        log_info "$(date +"%Y-%m-%d %H:%M:%S") [INFO] Webhook message sent successfully: $MESSAGE"
    else
        log_info "$(date +"%Y-%m-%d %H:%M:%S") [ERROR] Failed to send webhook message: $MESSAGE"
    fi
}

# 压缩文件函数
compress_backup() {
    BACKUP_FILE="$1"
    COMPRESSED_FILE="$BACKUP_FILE.tar.gz"

    log_info "Compressing backup file: $BACKUP_FILE"
    tar -czf "$COMPRESSED_FILE" -C "$(dirname "$BACKUP_FILE")" "$(basename "$BACKUP_FILE")"

    if [ $? -eq 0 ]; then
        log_info "Backup file compressed successfully: $COMPRESSED_FILE"
        rm -f "$BACKUP_FILE"
        log_info "Original backup file deleted: $BACKUP_FILE"
    else
        log_info "Failed to compress backup file: $BACKUP_FILE"
        exit 1
    fi
}

# 全量备份函数
full_backup() {
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S") # 不使用特殊字符
    mkdir -p "$BACKUP_DIR/full"
    FULL_BACKUP_PATH="$BACKUP_DIR/full/full_backup_$TIMESTAMP.sql"

    log_info "Starting full backup at $TIMESTAMP"
    mysqldump -u "$MySql_USER" -p"$MySql_PASSWORD" -h "$MySql_HOST" --databases xxl_job --flush-logs > "$FULL_BACKUP_PATH"
    if [ ! -s "$FULL_BACKUP_PATH" ]; then
            log_info "Full backup failed: $FULL_BACKUP_PATH is empty"
            /usr/bin/python3 $ALARM_SHELL_PATH full
            exit 1
    fi

    if [ $? -eq 0 ]; then
        log_info "Full backup completed successfully at $TIMESTAMP"
        mysql -u "$MySql_USER" -p"$MySql_PASSWORD" -h "$MySql_HOST" -e "SHOW MASTER STATUS;" | awk 'NR==2 {print $1, $2}' > "$LAST_BACKUP_FILE"
        compress_backup "$FULL_BACKUP_PATH" # 压缩全量备份
    else
        log_info "Full backup failed at $TIMESTAMP"
        exit 1
    fi
}

# 增量备份函数
incremental_backup() {
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S") # 不使用特殊字符
    mkdir -p "$BACKUP_DIR/incremental"
    INCREMENTAL_BACKUP_PATH="$BACKUP_DIR/incremental/incremental_backup_$TIMESTAMP.sql"

    if [ -f "$LAST_BACKUP_FILE" ]; then
        BINLOG_FILE=$(awk '{print $1}' "$LAST_BACKUP_FILE")
        BINLOG_POS=$(awk '{print $2}' "$LAST_BACKUP_FILE")

        log_info "Starting incremental backup at $TIMESTAMP"
        mysqlbinlog --database="xxl_job" --start-position="$BINLOG_POS" "/var/lib/mysql/$BINLOG_FILE" > "$INCREMENTAL_BACKUP_PATH"

        # 判断增量备份是否为空
        if [ ! -s "$INCREMENTAL_BACKUP_PATH" ]; then
            log_info "Incremental backup failed: $INCREMENTAL_BACKUP_PATH is empty"
            /usr/bin/python3 $ALARM_SHELL_PATH incremental
            exit 1
        fi

        if [ $? -eq 0 ]; then
            log_info "Incremental backup completed successfully at $TIMESTAMP"
            mysql -u "$MySql_USER" -p"$MySql_PASSWORD" -h "$MySql_HOST" -e "SHOW MASTER STATUS;" | awk 'NR==2 {print $1, $2}' > "$LAST_BACKUP_FILE"
        else
            log_info "Incremental backup failed at $TIMESTAMP"
            exit 1
        fi
    else
        log_info "No last backup position found, performing full backup instead."
        full_backup
    fi
}

# 清理 14 天前的备份
cleanup_old_backups() {
    log_info "Starting cleanup of backups older than 14 days"
    find "$BACKUP_DIR/full" -type f -mtime +14 -delete
    find "$BACKUP_DIR/incremental" -type f -mtime +14 -delete
    log_info "Old backups cleaned up"
}

# 判断是否为周日
is_sunday() {
    [ "$(date +%u)" -eq 7 ]
}

# 执行策略
execute_strategy() {
    if is_sunday; then
        log_info "It's Sunday, performing full backup and cleaning old backups"
        full_backup
        cleanup_old_backups
    else
        log_info "It's a weekday, performing incremental backup"
        echo "It's a weekday, performing incremental backup"
        incremental_backup
    fi
}

# 主逻辑入口
execute_strategy