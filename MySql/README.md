## 定时任务配置
# 编辑 cron 配置：
crontab -e
添加以下条目，每天凌晨 2 点运行备份脚本：

10 2 * * * /deploy/redis/redis_backup.sh
