#!/bin/bash

# 配置参数
command_linebin="/usr/local/bin/mongosh"
username="root"
password="SYY54YsaXuBHndSe"
port="27017"

# 创建备份路径
bkdatapath="/mongo/backup/mongo_log_back/mongo$port"
bklogpath="/mongo/backup/mongo_log_back/log/$port"
mkdir -p "$bkdatapath" "$bklogpath"

# 获取当前时间
logfilename=$(date +"%Y%m%d")
current_time=$(date +"%Y-%m-%d %H:%M:%S")
ParamBakEndDate=$(date +%s)
ParamBakStartDate=$((ParamBakEndDate - 5 * 60))  # 时间范围：备份开始时间为当前时间 - 65分钟

# 记录备份开始日志
echo "[INFO][$current_time][BACKUP_START] MongoDB端口: $port" >> "$bklogpath/$logfilename.log"
echo "[INFO][$current_time][BACKUP_TIME] Start: $ParamBakStartDate, End: $ParamBakEndDate" >> "$bklogpath/$logfilename.log"

# 获取 oplog 起始时间
opmes=$($command_linebin mongodb://$username:$password@localhost:$port/admin --quiet <<< "db.printReplicationInfo()")
opstartmes=$(echo "$opmes" | grep "oplog first event time" | awk -F 'CST' '{print $1}' | awk -F 'oplog first event time: ' '{print $2}' | awk -F ' GMT' '{print $1}')
oplogRecordFirst=$(date -d "$opstartmes" +%s)

echo "[INFO][$current_time][OPLOG_START_TIME] $oplogRecordFirst" >> "$bklogpath/$logfilename.log"

# 检查备份时间范围是否有效
if [ $oplogRecordFirst -le $ParamBakStartDate ]; then
    echo "[INFO][$current_time][VALIDATION] 备份时间合理" >> "$bklogpath/$logfilename.log"
else
    echo "[ERROR][$current_time][VALIDATION] 备份时间不合理，请调整 oplog size 或备份频率。" >> "$bklogpath/$logfilename.log"
    exit 1
fi

# 执行备份
bkfilename=$(date +"%Y%m%d%H%M%S")
/usr/bin/mongodump -h localhost --port $port --authenticationDatabase admin -u$username -p$password -d local -c oplog.rs \
  --query '{"ts": {"$gte": {"$numberLong": "'$ParamBakStartDate'"}, "$lte": {"$numberLong": "'$ParamBakEndDate'"}}}' \
  -o "$bkdatapath/mongodboplog$bkfilename" >> "$bklogpath/$logfilename.log" 2>&1

# 检查备份是否成功
if [ -d "$bkdatapath/mongodboplog$bkfilename" ]; then
    echo "[INFO][$current_time][BACKUP_FILE] $bkdatapath/mongodboplog$bkfilename" >> "$bklogpath/$logfilename.log"
else
    echo "[ERROR][$current_time][BACKUP_FILE] 备份失败，没有生成备份文件" >> "$bklogpath/$logfilename.log"
    exit 1
fi

# 删除3天前的备份
keepbaktime=$(date -d '-3 days' "+%Y%m%d%H")*
if [ -d "$bkdatapath/mongodboplog$keepbaktime" ]; then
    rm -rf "$bkdatapath/mongodboplog$keepbaktime"
    echo "[INFO][$current_time][CLEANUP] 已删除历史备份: $bkdatapath/mongodboplog$keepbaktime" >> "$bklogpath/$logfilename.log"
fi

# 记录备份结束日志
current_time=$(date +"%Y-%m-%d %H:%M:%S")
echo "[INFO][$current_time][BACKUP_END] MongoDB端口: $port" >> "$bklogpath/$logfilename.log"
