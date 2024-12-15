#!/bin/bash
###
 # @Author: Eddie
 # @Date: 2024-12-04 20:05:14
 # @LastEditTime: 2024-12-04 23:04:13
### 

#!/bin/bash

# 设置脚本的退出规则
set -euo pipefail

# 全局变量配置
LOG_FILE="./yaml/k8s_setup.log"
MASTER_IP="192.168.142.102"
# 不能与本机网络冲突
POD_NETWORK_CIDR="10.244.0.0/16"
K8S_VERSION="1.23.1"
DOCKER_VERSION="19.03.14"

# 日志记录函数
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"
}


# 1. 更新系统和安装基础依赖
update_system() {
    log "安装基础依赖..."
    # yum -y update
    mkdir -p /backup/yum.repos.d
    mv /etc/yum.repos.d/* /backup/yum.repos.d
    curl -o /etc/yum.repos.d/Centos7.repo http://mirrors.aliyun.com/repo/Centos-7.repo
    yum clean all && yum makecache
    yum install -y conntrack ipvsadm ipset jq sysstat curl iptables libseccomp
    log "系统更新和基础依赖安装完成"
}

# 2. 安装 Docker
install_docker() {
    log "安装 Docker..."
    yum install -y yum-utils device-mapper-persistent-data lvm2
    yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
    yum install -y "docker-ce-$DOCKER_VERSION" "docker-ce-cli-$DOCKER_VERSION"
    systemctl enable docker --now
    systemctl status docker --no-pager
    log "Docker 安装完成"
}

# 3. 配置 Docker
configure_docker() {
    log "配置 Docker..."
    cat <<EOF > /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "registry-mirrors": [
    "https://nmxk8hna.mirror.aliyuncs.com",
    "https://docker.mirrors.ustc.edu.cn"
  ],
  "log-driver": "json-file",
  "storage-driver": "overlay2"
}
EOF
    systemctl restart docker
    log "Docker 配置完成"
}

# 4. 系统配置（关闭防火墙、SELinux 等）
configure_system() {
    log "配置系统..."
    systemctl stop firewalld && systemctl disable firewalld
    setenforce 0 || true
    sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
    swapoff -a
    sed -i '/swap/s/^/#/' /etc/fstab
    iptables -F && iptables -P FORWARD ACCEPT
    cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    sysctl --system || true
    hostname=$(hostname)
    echo "${MASTER_IP}  ${hostname}" >> /etc/hosts
    log "系统配置完成"
}

clean_k8s_env() {
    rm -rvf $HOME/.kube/config /var/lib/kubelet /etc/kubernetes /var/lib/etcd /var/lib/dockershim /var/run/kubernetes /var/lib/cni /etc/cni/net.d
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -t mangle -F
    iptables -t mangle -X
    iptables -t raw -F
    iptables -t raw -X
    iptables -Z
    iptables -L -v
    iptables -t nat -L -v
}


# 5. 安装 Kubernetes 工具
install_kubernetes_tools() {
    log "安装 Kubernetes 工具..."
    cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
EOF
    yum install -y "kubectl-$K8S_VERSION-0" "kubelet-$K8S_VERSION-0" "kubeadm-$K8S_VERSION-0"
    systemctl enable kubelet --now
    log "Kubernetes 工具安装完成"
    kubeadm reset -f
}

# 6. 初始化 Master 节点
init_master() {
    log "初始化 Master 节点..."
    kubeadm init --image-repository registry.aliyuncs.com/google_containers \
                 --kubernetes-version="$K8S_VERSION" \
                 --pod-network-cidr="$POD_NETWORK_CIDR" \
                 --apiserver-advertise-address="$MASTER_IP"
    mkdir -p "$HOME/.kube"
    cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
    chown "$(id -u):$(id -g)" "$HOME/.kube/config"
    echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> /etc/profile
    kubectl taint nodes cluster-node-02 node-role.kubernetes.io/master:NoSchedule-
    log "Master 节点初始化完成"
}

# 7. 安装网络插件
install_network_plugin() {
    log "安装网络插件 Flannel..."

    # 检查配置文件是否已包含网络配置
    if grep -q "${POD_NETWORK_CIDR}" ./yaml/kube-flanel.yml; then
        log "网络配置正确"
    else
        log "网络配置不存在，进行替换"
    fi

    # 获取旧的网络值并替换
    OLD_VALUE=$(grep -oP '"Network":\s*"\K[^"]+' ./yaml/kube-flanel.yml)
    if [ -n "$OLD_VALUE" ]; then
        # 使用 ':' 作为分隔符避免转义问题
        sed -i "s:$OLD_VALUE:$POD_NETWORK_CIDR:g" ./yaml/kube-flanel.yml
        log "网络配置已更新"
    else
        log "未找到旧的网络配置"
    fi

    kubectl apply -f ./yaml/kube-flanel.yml
    log "网络插件安装完成"
}


# 8. 安装Ingress-nginx
install_ingress_plugin() {
    log "安装 Ingress-nginx..."
    kubectl apply -f ./yaml/ingress-nginx-daemonset.yaml
}

# 9. 安装 metrics-server
install_metrics-server() {
    log "安装 metrics-server..."
    kubectl apply -f ./yaml/metrics-server.yaml
}

# 9. 恢复前面前面操作的repo文件
restoring_yum() {
    mv /backup/yum.repos.d/* /etc/yum.repos.d/
    rm -rf /backup/yum.repos.d
}

# 主程序
main() {
    log "Kubernetes 自动化部署脚本开始运行..."
    #update_system
    #install_docker
    #configure_docker
    #configure_system
    #clean_k8s_env
    #install_kubernetes_tools
    #init_master
    install_network_plugin
    install_ingress_plugin
    install_metrics-server
    restoring_yum
    log "Kubernetes 部署完成！"
}

# 执行主程序
main "$@"
