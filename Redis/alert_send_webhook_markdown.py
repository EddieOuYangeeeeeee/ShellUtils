'''
Author       : OuYang
Date         : 2023-12-28 18:00:26
LastEditors: Do not edit
LastEditTime: 2024-12-01 22:06:28
Description  : 使用WechatBot发送webhook消息
'''

import sys
from requests import request
import platform
import socket
import logging
from datetime import datetime

# 备份数据库日志
backup_log_file = "/backup/redis/backup.log"
alarm_log_file = "/backup/redis/alarm.log"
logging.basicConfig(filename=alarm_log_file, level=logging.INFO, format='[%(asctime)s] - [%(levelname)s] - %(message)s')
logger = logging.getLogger(__name__)

def send_markdown(webhook_url, content):
    """
    发送markdown消息
    目前支持的markdown语法是如下的子集：
        1. 标题 （支持1至6级标题，注意#与文字中间要有空格）
        2. 加粗
        3. 链接
        4. 行内代码段（暂不支持跨行）
        5. 引用
        6. 字体颜色(只支持3种内置颜色), 绿色（color="info"），灰色（color="comment"），橙红色（color="warning"）
    :param content: markdown内容，最长不超过4096个字节，必须是utf8编码
    """
    payload = {
        "msgtype": "markdown",
        "markdown": {
            "content": content
        }
    }
    
    try:
        response = request(url=webhook_url, method="POST", json=payload)
        response.raise_for_status()  # 检查请求是否成功
        
        if response.json().get("errcode") == 0:
            logger.info("WebHook send markdown message succeeded.")
            logger.debug(f"Result: {response.json()}")
            return True
        else:
            logger.error(f"WebHook failed to send markdown message. {response.text}")
            logger.debug(f"Error details: {response.json()}")
            return False
            
    except Exception as e:
        logger.error(f"An error occurred while sending the WebHook message: {str(e)}")
        return False

def get_hostname():
    hostname = socket.gethostname()
    return hostname

def get_system_info():
    # 获取os类型
    os_type = platform.system()
    return os_type

def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.connect(("8.8.8.8", 80))
    return s.getsockname()[0]

# MySQL数据库全量备份文件为空
def markdown_mysql_full_backup(ip , hostname, time, shell_name, logfile):
    markdown = f"""
        **Redis数据库 备份文件为空**
            >主机IP：{ip}
            >主机名：{hostname}
            >时间：{time}
            >来源：{shell_name}
            >日志文件：{logfile}
    """
    return markdown

if __name__ == '__main__':
    # 接收选择的告警类型
    if len(sys.argv) < 2:
        logger.error("告警类型未提供，请使用 'full' 或 'incremental'")
        sys.exit(1)

    args = sys.argv[1]
    
    # WebHook URL
    webhook_url = "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=f13b1565-2c9b-4b96-898d-8181f5d01259"
    
    # Time
    time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    
    if args == 'full':
        message = markdown_mysql_full_backup(get_local_ip(),get_hostname(), time, shell_name="redis_backup.sh", logfile=backup_log_file)
    else:
        logger.error("无效的告警类型，请使用 'full'")
        sys.exit(1)

    # 发送消息
    send_markdown(webhook_url, message)
