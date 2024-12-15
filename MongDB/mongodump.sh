#!/bin/bash

# 配置参数
mongosh_bin="/usr/local/bin/mongosh"
mongodump_bin="/usr/bin/mongodump"
username="root"
password="SYY54YsaXuBHndSe"
port="27017"
bkdatapath="/mongo/backup/mongo_log_back/mongo$port"
bklogpath="/mongo/backup/mongo_log_back/log/$port"
logfilename=$(date -d today +"%Y%m%d").log
bkfilename=$(date -d today +"%Y%m%d%H%M%S")
full_backup_marker="$bkdatapath/full_backup_marker"
mkdir -p "$bkdatapath" "$bklogpath"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$bklogpath/$logfilename"
}

log "=================================== MongoDB 增量备份开始 - 端口: $port ==================================="

# 设置备份时间参数
ParamBakEndDate=$(date +%s)
DiffTime=$((65 * 60))
ParamBakStartDate=$((ParamBakEndDate - DiffTime))
log "备份开始时间: $(date -d @$ParamBakStartDate '+%Y-%m-%d %H:%M:%S'), 结束时间: $(date -d @$ParamBakEndDate '+%Y-%m-%d %H:%M:%S')"

# 确保全量备份存在
if [ ! -f "$full_backup_marker" ]; then
    log "未检测到全量备份，开始执行全量备份..."
    ${mongodump_bin} --host localhost --port $port --username $username --password $password --authenticationDatabase admin --out "$bkdatapath/full_backup_$bkfilename" >> "$bklogpath/$logfilename" 2>&1
    if [ $? -eq 0 ]; then
        touch "$full_backup_marker"
        log "全量备份成功，标记文件已创建：$full_backup_marker"
    else
        log "全量备份失败，停止执行后续操作！"
        exit 1
    fi
else
    log "全量备份标记已存在，跳过全量备份。"
fi

# 检查 oplog 开始时间
command_line="${mongosh_bin} mongodb://$username:$password@localhost:$port/admin"
opmes=$(/bin/echo "db.printReplicationInfo()" | $command_line --quiet)
opstartmes=$(echo "$opmes" | grep "oplog first event time" | awk -F 'oplog first event time: ' '{print $2}' | awk -F ' GMT' '{print $1}')
oplogRecordFirst=$(date -d "$opstartmes" +%s)
log "oplog 开始时间: $opstartmes ($(date -d @$oplogRecordFirst '+%Y-%m-%d %H:%M:%S'))"

if [ $oplogRecordFirst -le $ParamBakStartDate ]; then
    log "oplog 时间范围满足备份要求。"
else
    log "oplog 时间范围不足，可能导致数据不完整，请检查 oplog size 或调整备份频率！"
fi

# 执行增量备份
log "开始执行增量备份..."
${mongodump_bin} -h localhost --port $port --authenticationDatabase admin -u$username -p$password \
    -d local -c oplog.rs \
    --query "{ts: {\$gte: Timestamp($ParamBakStartDate, 1), \$lte: Timestamp($ParamBakEndDate, 9999)}}" \
    -o "$bkdatapath/mongodboplog$bkfilename" >> "$bklogpath/$logfilename" 2>&1

if [ $? -eq 0 ] && [ -d "$bkdatapath/mongodboplog$bkfilename" ]; then
    log "增量备份成功，文件路径: $bkdatapath/mongodboplog$bkfilename"
else
    log "增量备份失败，请检查！"
    exit 1
fi

# 再次检查 oplog 范围
opmes=$(/bin/echo "db.printReplicationInfo()" | $command_line --quiet)
opstartmes=$(echo "$opmes" | grep "oplog first event time" | awk -F 'oplog first event time: ' '{print $2}' | awk -F ' GMT' '{print $1}')
oplogRecordFirst=$(date -d "$opstartmes" +%s)
log "备份后 oplog 开始时间: $opstartmes ($(date -d @$oplogRecordFirst '+%Y-%m-%d %H:%M:%S'))"

if [ $oplogRecordFirst -le $((ParamBakEndDate - 61 * 60)) ]; then
    log "oplog 数据完整性检查通过。"
else
    log "备份后 oplog 范围不足，可能导致数据丢失，请检查！"
fi

# 删除 3 天前的备份文件
log "清理 3 天前的备份文件..."
find "$bkdatapath" -type d -name "mongodboplog*" -mtime +3 -exec rm -rf {} \; >> "$bklogpath/$logfilename" 2>&1
log "备份清理完成。"

log "=================================== MongoDB 增量备份结束 ==================================="
