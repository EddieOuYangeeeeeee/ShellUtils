#!/bin/bash

set -e

# MySQL 配置
MySql_USER="root"
MySql_PASSWORD="hw2dBxzB@123"
MySql_HOST="localhost"

# 日志文件路径
LOG_FILE="/backup/mysql/restore.log"

# 日志输出函数
log_info() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") [INFO] $1" >> "$LOG_FILE"
}

log_error() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") [ERROR] $1" >> "$LOG_FILE"
}

# 检查是否提供增量备份目录参数
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <incremental_backup_dir>"
    exit 1
fi

INCREMENTAL_BACKUP_DIR="$1"

# 检查增量备份目录是否存在
if [ ! -d "$INCREMENTAL_BACKUP_DIR" ]; then
    log_error "增量备份目录不存在: $INCREMENTAL_BACKUP_DIR"
    echo "增量备份目录不存在: $INCREMENTAL_BACKUP_DIR"
    exit 1
fi

# 确认提示
echo "****** 警告 ******"
echo "此脚本将从增量备份目录恢复数据库的增量备份"
echo "请确保数据库已经恢复到最新的全量备份状态！"
echo "备份目录: $INCREMENTAL_BACKUP_DIR"
read -p "您是否确认已完成全量备份恢复并继续执行？(y/n): " CONFIRMATION

if [[ "$CONFIRMATION" != "y" && "$CONFIRMATION" != "Y" ]]; then
    echo "操作已取消"
    exit 0
fi

# 获取所有增量备份文件（按时间顺序）
sql_files=$(ls "$INCREMENTAL_BACKUP_DIR"/incremental_backup_*.sql 2>/dev/null | sort)

# 检查是否有备份文件
if [ -z "$sql_files" ]; then
    log_error "没有找到增量备份文件"
    echo "没有找到增量备份文件"
    exit 1
fi

# 恢复每一个增量备份文件
for sql_file in $sql_files; do
    log_info "正在恢复增量备份: $sql_file"
    echo "正在恢复增量备份: $sql_file"

    # 执行恢复操作
    mysql -u "$MySql_USER" -p"$MySql_PASSWORD" -h "$MySql_HOST" < "$sql_file"
    if [ $? -ne 0 ]; then
        log_error "恢复 $sql_file 时出错"
        echo "恢复 $sql_file 时出错"
        exit 1
    else
        log_info "增量备份 $sql_file 恢复成功"
        echo "增量备份 $sql_file 恢复成功"
    fi
done

log_info "所有增量备份已成功恢复"
echo "所有增量备份已成功恢复"
