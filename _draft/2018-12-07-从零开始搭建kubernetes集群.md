---
layout:     post		
title:      "从零开始搭建kubernetes集群"	
date:       2018-12-07	
author:     "KingXt"		
tags:
    - kubernetes
---

### 从零开始搭建kubernetes集群


#### 1. 搭建环境

1. macOS 10.14
2. virtualbox 5.2
3. centOS version [CentOS-7-x86_64-Minimal-1810.iso](http://mirrors.nwsuaf.edu.cn/centos/7.6.1810/isos/x86_64/CentOS-7-x86_64-Minimal-1810.iso)

在macOS上安装virtualbox，一路next即可，安装完virtualbox后，参考下面方式安装centOS
<img src="/img/post/k8s/k8s-install-env.gif" width="600"/>

CentOS 安装好后是没有GUI的，进去要你输入账号密码，账号root，密码是安装时候设置的。

安装完后，客户设置centOS的端口代理，这样就可以在宿主机ssh到虚拟机上操作了
`ssh -p 9000 root@127.0.0.1`

开始做一些前提工作
1. 关闭防火墙  `systemctl stop firewalld & systemctl disable firewalld`
2. 关闭swap `sed -i '/ swap / s/^/#/' /etc/fstab` `swapoff -a` ，可以通过top验证下swap是不是0，或者通过free -m
```sheel
[root@localhost ~]# free -m
              total        used        free      shared  buff/cache   available
Mem:            991         151         153           6         685         653
Swap:             0           0           0
```

下面开始安装docker
> 1. yum -y install yum-utils
> 2. yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
> 3. yum makecache
> 4. yum install docker-ce -y

```sheel
[root@localhost ~]# docker --version
Docker version 18.09.0, build 4d60db4
```

启动docker `systemctl start docker & systemctl enable docker`， 
验证docker

```sheel
[root@localhost ~]# docker run hello-world
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
d1725b59e92d: Pull complete
Digest: sha256:0add3ace90ecb4adbf7777e9aacf18357296e799f81cabc9fde470971e499788
Status: Downloaded newer image for hello-world:latest

Hello from Docker!
This message shows that your installation appears to be working correctly.
```

#### 2. 安装kubernetes
可以参考下面步骤配置k8s源
```sheel
[root@localhost ~]# cat <<EOF > /etc/yum.repos.d/kubernates.repo
> [kubernetes]
> name=Kubernetes
> baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
> enabled=1
> gpgcheck=0
> repo_gpgcheck=0
> repo_gpgcheck=0
> gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
> EOF
[root@localhost ~]#
```

1. 先关闭SELinux `setenforce 0`
2. 安装k8s组件 `yum install -y kubelet kubeadm kubectl`

kubelet启动时带的cgroup-driver和docker使用的cgroup-driver参数可能有所不同，会导致kubelet服务启动失败，我们将其改成一样。
```sheel
[root@localhost ~]# docker info | grep -i cgroup
Cgroup Driver: cgroupfs
```

启动kubelet
```sheel
[root@localhost ~]# systemctl enable kubelet && systemctl start kubelet
Created symlink from /etc/systemd/system/multi-user.target.wants/kubelet.service to /etc/systemd/system/kubelet.service.
```

#### 3. 搭建kubernetes集群
先关闭什么创建的master节点，右键可以复制两个节点，我们命名起为CentOS-Node2，CentOS-Node3，如下图所示。
<img src="/img/post/k8s/k8s-p1.png" width="600"/>

可以启动其中两个看看虚拟机的ip，发现都一样。这样虚拟机之间就不能互通了。
可以设置网络桥接模式，如下图所示：
<img src="/img/post/k8s/k8s-p2.png" width="600"/>

在Master主节点（CentOS-master）上执行:
`kubeadm init --pod-network-cidr=192.168.0.0/16 --kubernetes-version=v1.10.0 --apiserver-advertise-address=192.168.2.29`