#!/bin/sh

. /etc/rc.d/init.d/functions
export LANG=zh_CN.UTF-8

#一级菜单
menu1()
{
clear
cat <<EOF
----------------------------------------
|****   欢迎使用Cetnos优化脚本    ****|
----------------------------------------
1. 一键优化
2. 自定义优化
3. 退出
EOF
read -p "please enter your choice[1-3]:" num1
}

#二级菜单
menu2()
{
clear
cat <<EOF
----------------------------------------
|****Please Enter Your Choice:[0-18]****|
----------------------------------------
1. 修改字符集
2. 关闭selinux
3. 关闭firewalld
4. 精简开机启动
5. 修改文件描述符
6. 安装常用工具及修改yum源
7. 优化系统内核
8. 加快ssh登录速度
9. 禁用ctrl+alt+del重启
10.设置时间同步
11.history优化
12.关闭linux邮件收集
13.修改交换分区策略
14.设置最大打开文件数
15.修改环境变量
16.创建gfai用户
17.修改时区
18.返回上级菜单
19.退出
EOF
read -p "please enter your choice[1-18]:" num2
}

#1.修改字符集
localeset()
{
 echo "========================修改字符集========================="
 cat > /etc/locale.conf <<EOF
  LANG="zh_CN.UTF-8"
  #LANG="en_US.UTF-8"
  SYSFONT="latarcyrheb-sun16"
EOF
 source /etc/locale.conf
 echo "#cat /etc/locale.conf"
 cat /etc/locale.conf
 action "完成修改字符集" /bin/true
 echo "完成修改字符集"
 echo "==========================================================="
 sleep 2
}

#2.关闭selinux
selinuxset() 
{
 selinux_status=`grep "SELINUX=disabled" /etc/selinux/config | wc -l`
 echo "========================禁用SELINUX========================"
 if [ $selinux_status -eq 0 ];then
  sed  -i "s#SELINUX=enforcing#SELINUX=disabled#g" /etc/selinux/config
  setenforce 0
  echo '#grep SELINUX=disabled /etc/selinux/config'
  grep SELINUX=disabled /etc/selinux/config
  echo '#getenforce'
  getenforce
 else
  echo 'SELINUX已处于关闭状态'
  echo '#grep SELINUX=disabled /etc/selinux/config'
  grep SELINUX=disabled /etc/selinux/config
  echo '#getenforce'
  getenforce
 fi
 action "完成禁用SELINUX" /bin/true
 echo "完成禁用SELINUX"
 echo "==========================================================="
 sleep 2
}

#3.关闭firewalld
firewalldset()
{
 echo "=======================禁用firewalld========================"
 systemctl stop firewalld.service &> /dev/null
 echo '#firewall-cmd  --state'
 firewall-cmd  --state
 systemctl disable firewalld.service &> /dev/null
 echo '#systemctl list-unit-files | grep firewalld'
 systemctl list-unit-files | grep firewalld
 action "完成禁用firewalld，生产环境下建议启用！" /bin/true
 echo "完成禁用firewalld，生产环境下建议启用！" 
 echo "==========================================================="
 sleep 5
}

#4.精简开机启动
chkset()
{
 echo "=======================精简开机启动========================"
 systemctl disable auditd.service
 systemctl disable postfix.service
 systemctl disable dbus-org.freedesktop.NetworkManager.service
 echo '#systemctl list-unit-files | grep -E "auditd|postfix|dbus-org\.freedesktop\.NetworkManager"'
 systemctl list-unit-files | grep -E "auditd|postfix|dbus-org\.freedesktop\.NetworkManager"
 action "完成精简开机启动" /bin/true
 echo "==========================================================="
 sleep 2
}

#5.修改文件描述符
limitset()
{
 echo "======================修改文件描述符======================="
 echo '* - nofile 65535'>/etc/security/limits.conf
 ulimit -SHn 65535
 echo "#cat /etc/security/limits.conf"
 cat /etc/security/limits.conf
 echo "#ulimit -Sn ; ulimit -Hn"
 ulimit -Sn ; ulimit -Hn
 action "完成修改文件描述符" /bin/true
 echo "==========================================================="
 sleep 2
}

#6.安装常用工具及修改yum源
yumset()
{
  mkdir -p /backup/yum.repos.d
  mv /etc/yum.repos.d/* /backup/yum.repos.d
  curl -o /etc/yum.repos.d/Centos7.repo http://mirrors.aliyun.com/repo/Centos-7.repo &> /dev/null
  yum clean all && yum makecache
  yum install -y conntrack ipvsadm ipset jq sysstat wget iptables libseccomp vim net-tools telnet iftop zip lrzsz &> /dev/null
  log "系统更新和基础依赖安装完成"
}
# yumset()
# {
#  echo "=================安装常用工具及修改yum源==================="
#  yum install wget -y &> /dev/null
#  if [ $? -eq 0 ];then
#   cd /etc/yum.repos.d/
#   \cp CentOS-Base.repo CentOS-Base.repo.$(date +%F)
#   ping -c 1 mirrors.aliyun.com &> /dev/null
#   if [ $? -eq 0 ];then
#    wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo &> /dev/null
#    yum clean all &> /dev/null
#    yum makecache &> /dev/null
#   else
#    echo "无法连接网络"
#        exit $?
#     fi
#  else
#   echo "wget安装失败"
#   exit $?
#  fi
#  yum -y install ntpdate lsof net-tools telnet vim lrzsz tree nmap nc sysstat &> /dev/null
#  action "完成安装常用工具及修改yum源" /bin/true
#  echo "==========================================================="
#  sleep 2
# }

#7. 优化系统内核
kernelset()
{
 echo "======================优化系统内核========================="
 chk_nf=`cat /etc/sysctl.conf | grep conntrack |wc -l`
 if [ $chk_nf -eq 0 ];then
  cat >>/etc/sysctl.conf<<EOF
   net.ipv4.tcp_fin_timeout = 30
   net.ipv4.tcp_tw_reuse = 1
   net.ipv4.tcp_tw_recycle = 1
   net.ipv4.tcp_syncookies = 1
   net.ipv4.tcp_keepalive_time = 1200
   net.ipv4.tcp_timestamps = 0
   net.ipv4.ip_local_port_range = 1024 65000
   net.ipv4.tcp_max_syn_backlog = 65536
   net.ipv4.tcp_max_tw_buckets = 36000
   net.ipv4.route.gc_timeout = 100
   net.ipv4.tcp_syn_retries = 2
   net.ipv4.tcp_synack_retries = 2
   net.ipv4.tcp_mem = 94500000 915000000 927000000
   net.ipv4.tcp_max_orphans = 3276800
   net.core.netdev_max_backlog = 32768
   net.core.somaxconn = 32768
   net.core.wmem_default = 8388608
   net.core.rmem_default = 8388608
   net.core.rmem_max = 16777216
   net.core.wmem_max = 16777216
   net.ipv4.igmp_max_memberships =512
EOF
  sysctl -p
 else
  echo "优化项已存在。"
 fi
 action "内核调优完成" /bin/true
 echo "内核调优完成"
 echo "==========================================================="
 sleep 2
}

#8.加快ssh登录速度
sshset()
{
 echo "======================加快ssh登录速度======================"
 sed -i 's#^GSSAPIAuthentication yes$#GSSAPIAuthentication no#g' /etc/ssh/sshd_config
 sed -i 's/#UseDNS yes/UseDNS no/g' /etc/ssh/sshd_config
 systemctl restart sshd.service
 echo "#grep GSSAPIAuthentication /etc/ssh/sshd_config"
 grep GSSAPIAuthentication /etc/ssh/sshd_config
 echo "#grep UseDNS /etc/ssh/sshd_config"
 grep UseDNS /etc/ssh/sshd_config
 action "完成加快ssh登录速度" /bin/true
 echo "完成加快ssh登录速度"
 echo "==========================================================="
 sleep 2
}

#9. 禁用ctrl+alt+del重启
restartset()
{
 echo "===================禁用ctrl+alt+del重启===================="
 rm -rf /usr/lib/systemd/system/ctrl-alt-del.target
 action "完成禁用ctrl+alt+del重启" /bin/true
 echo "==========================================================="
 sleep 2
}

#10. 设置时间同步
ntpdateset()
{
 echo "=======================设置时间同步========================"
 yum -y install ntpdate &> /dev/null
 if [ $? -eq 0 ];then
  /usr/sbin/ntpdate time.windows.com
  echo "* */5 * * * /usr/sbin/ntpdate ntp.aliyun.com &>/dev/null" >> /var/spool/cron/root
 else
  echo "ntpdate安装失败"
  exit $?
 fi
 action "完成设置时间同步" /bin/true
 echo "==========================================================="
 sleep 2
}

#11. history优化
historyset() {
    echo "========================history优化========================"
    chk_his=$(grep -c HISTTIMEFORMAT /etc/profile)

    if [ "$chk_his" -eq 0 ]; then
        cat >> /etc/profile <<'EOF'
# don't put duplicate lines in the history. See bash(1) for more options
# ... and ignore same successive entries.
export HISTCONTROL=ignoreboth

# set the time format for the history file.
export HISTTIMEFORMAT="%Y.%m.%d %H:%M:%S "

log_bash_eternal_history()
{
  local rc=$?
  # Use regular expression to parse history format and extract date and command
  [[ $(history 1) =~ ^\ *[0-9]+\ +([^\ ]+\ [^\ ]+)\ +(.*)$ ]]
  local date_part="${BASH_REMATCH[1]}"
  local command_part="${BASH_REMATCH[2]}"

  # Get the remote host IP from the `who` command
  local remote_host=$(who | grep -E 'pts/[0-9]+' | tail -n 1 | sed -E 's/.*\((.*)\)/\1/')

  # If no remote host IP found, set as "local"
  remote_host=${remote_host:-"local"}

  # Record the command if it's not a duplicate or one of the excluded commands
  if [ "$command_part" != "$ETERNAL_HISTORY_LAST" -a "$command_part" != "ls" -a "$command_part" != "ll" ]
  then
    # Log format: [YYYY.MM.DD HH:MM:SS] [hostname] [remote_host] [user] [exit_code] command
    echo "[$date_part] [$HOSTNAME] [$remote_host] [$USER] [$rc] $command_part" >> ~/.command_history
    export ETERNAL_HISTORY_LAST="$command_part"
  fi
}

PROMPT_COMMAND="log_bash_eternal_history"
EOF
        source /etc/profile
    else
        echo "优化项已存在。"
    fi

    action "完成history优化" /bin/true
    echo "完成history优化"
    echo "==========================================================="
    sleep 2
}
# historyset()
# {
#  echo "========================history优化========================"
#  chk_his=`cat /etc/profile | grep HISTTIMEFORMAT |wc -l`
#  if [ $chk_his -eq 0 ];then
#   cat >> /etc/profile <<'EOF'
# #设置history格式
# export HISTTIMEFORMAT="[%Y-%m-%d %H:%M:%S] [`whoami`] [`who am i|awk '{print $NF}'|sed -r 's#[()]##g'`]: "
# #记录shell执行的每一条命令
# export PROMPT_COMMAND='\
# if [ -z "$OLD_PWD" ];then
#     export OLD_PWD=$PWD;
# fi;
# if [ ! -z "$LAST_CMD" ] && [ "$(history 1)" != "$LAST_CMD" ]; then
#     logger -t `whoami`_shell_dir "[$OLD_PWD]$(history 1)";
# fi;
# export LAST_CMD="$(history 1)";
# export OLD_PWD=$PWD;'
# EOF
#   source /etc/profile
#  else
#   echo "优化项已存在。"
#  fi
#  action "完成history优化" /bin/true
#  echo "完成history优化"
#  echo "==========================================================="
#  sleep 2
# }

#12. 关闭linux邮件收集
mailset()
{
 echo "=====================关闭linux邮件收集======================="
 if ! grep "unset MAILCHECK" /etc/profile &>/dev/null; then
  echo "unset MAILCHECK">> /etc/profile
  echo "#unset MAILCHECK >> /etc/profile"
 else
  echo "优化项已存在。"
 fi
 action "完成关闭linux邮件收集" /bin/true
 echo "完成关闭linux邮件收集"
 echo "==========================================================="
 sleep 2
}

#13. 修改交换分区策略
swapset()
{
 echo "=====================修改交换分区策略======================="
 if ! grep "vm.swappiness=10" /etc/sysctl.conf &>/dev/null; then
  cat >> /etc/sysctl.conf << EOF
   vm.swappiness=10
   echo "vm.swappiness=10"
EOF
 else
  echo "优化项已存在。"
 fi
 action "完成修改交换分区策略" /bin/true
 echo "完成修改交换分区策略"
 echo "=========================================================="
 sleep 2
}

#14. 设置最大打开文件数
fileset()
{
 echo "=====================设置最大打开文件数======================="
 if ! grep "* soft nofile 65535" /etc/security/limits.conf &>/dev/null; then
  cat >> /etc/security/limits.conf << EOF
   *   soft nproc   65535  
   *   hard nproc   65535  
   *   soft nofile   65535  
   *   hard nofile   65535 
EOF
 else
  echo "优化项已存在。"
 fi
 action "完成设置最大打开文件数" /bin/true
 echo "完成设置最大打开文件数"
 echo "==========================================================="
 sleep 2
}

#15. 修改环境变量
envset()
{
 echo "=====================修改环境变量======================="
 if ! grep "ulimit -d unlimited" /etc/profile &>/dev/null; then
 cat >> /etc/profile << EOF
  ulimit -u 65535  
  ulimit -n 65535
  ulimit -d unlimited  
  ulimit -m unlimited  
  ulimit -s unlimited  
  ulimit -t unlimited  
  ulimit -v unlimited
EOF
 else
  echo "优化项已存在。"
 fi
 action "完成修改环境变量" /bin/true
 echo "完成修改环境变量"
 echo "======================================================"
 sleep 2
}

#16. 创建gfai用户
gfaiset()
{
 echo "=====================创建gfai用户======================="
 if ! id "gfai" &>/dev/null; then
  useradd gfai
  echo "#useradd gfai"
  echo gfai | passwd --stdin gfai &>/dev/null
  echo "#gfai | passwd --stdin gfai &>/dev/null"
  if [ ! -d "/home/gfai/softwares/" ];then
   su - gfai -c "mkdir softwares"
   echo "su - gfai -c mkdir softwares"
  fi
 else
  echo "gfai用户已存在。"
 fi
 action "完成创建gfai用户" /bin/true
 echo "完成创建gfai用户"
 echo "======================================================="
 sleep 2
}

#17. 修改时区
zoneset()
{
 echo "=====================修改时区======================="
 zone=$(date |awk '{print $6}')
 if [ "$zone" != "CST" ]; then
  timedatectl set-timezone 'Asia/Shanghai'
 else
  echo "时区不需要修改。"
 fi
 action "完成修改时区" /bin/true
 echo "完成修改时区"
 echo "======================================================="
 sleep 2
}

action() {
  local STRING rc

  STRING=$1
  echo -n "$STRING "
  shift
  "$@" && success $"$STRING" || failure $"$STRING"
  rc=$?
  echo
  return $rc
}

#控制函数
main()
{
 menu1
 case $num1 in
  1)
   localeset
   selinuxset
   firewalldset
   chkset
   limitset
   #yumset
   kernelset
   sshset
   restartset
   #ntpdateset
   historyset
   mailset
   swapset
   fileset
   envset
   gfaiset
   zoneset
 ;;
  2)
   menu2
   case $num2 in
    1)
     localeset
   ;;
    2)
     selinuxset
   ;;
    3)
     firewalldset
   ;;
    4)
     chkset
   ;;
    5)
     limitset
   ;;
    6)                 
     yumset
     ;;
    7)
     kernelset
   ;;
    8)
     sshset
   ;;
    9)
     restartset
   ;;
    10)
     ntpdateset
   ;;
    11)
     historyset
   ;;
    12)
     mailset
   ;;
    13)
     swapset
   ;;
    14)
     fileset
   ;;
    15)
     envset
   ;;
    16)
     gfaiset
   ;;
    17)
     zoneset
   ;;
    18)
     main
   ;;
    19)
     exit
   ;;
    *)
     echo 'Please select a number from [1-18].'
   ;;
   esac
 ;;
  3)
   exit
 ;;
  *)
  echo 'Err:Please select a number from [1-3].'
  sleep 3
  main
 ;;
 esac
}
main $*
