---
layout:     post		
title:      "搭建kubernetes集群"	
date:       2018-12-07	
author:     "KingXt"		
tags:
    - kubernetes
---

### 搭建kubernetes集群


#### 1. 搭建环境

1. macOS 10.14
2. virtualbox 5.2
3. CentOS version [CentOS-7-x86_64-Minimal-1810.iso](http://mirrors.nwsuaf.edu.cn/CentOS/7.6.1810/isos/x86_64/CentOS-7-x86_64-Minimal-1810.iso)
4. kubernetes版本v1.12.1

在macOS上安装virtualbox，一路next即可，安装完virtualbox后，参考下面方式安装CentOS
<img src="/img/post/k8s/k8s-install-env.gif" width="600"/>

CentOS 安装好后是没有GUI的，进去要你输入账号密码，账号root，密码是安装时候设置的。

安装完后，客户设置CentOS的端口代理，这样就可以在宿主机ssh到虚拟机上操作了
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

下面开始安装docker，docker一定要指定版本号。

```sheel
[root@localhost ~]# yum update && yum install docker-ce-18.06.1.ce
[root@localhost ~]# docker --version
Docker version 18.06.1-ce, build e68fc7a
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
2. 安装k8s组件 `yum install -y kubelet-1.12.1 kubeadm-1.12.1 kubectl-1.12.1`

```
[root@localhost ~]# yum install -y kubelet-1.12.1 kubeadm-1.12.1 kubectl-1.12.1
Failed to set locale, defaulting to C
Loaded plugins: fastestmirror
Loading mirror speeds from cached hostfile
 * base: mirrors.cn99.com
 * extras: mirrors.cn99.com
 * updates: CentOS.ustc.edu.cn
base                                                                                                                                     | 3.6 kB  00:00:00
docker-ce-stable                                                                                                                         | 3.5 kB  00:00:00
extras                                                                                                                                   | 3.4 kB  00:00:00
kubernetes                                                                                                                               | 1.4 kB  00:00:00
updates                                                                                                                                  | 3.4 kB  00:00:00
Resolving Dependencies
--> Running transaction check
---> Package kubeadm.x86_64 0:1.12.1-0 will be installed
--> Processing Dependency: kubernetes-cni >= 0.6.0 for package: kubeadm-1.12.1-0.x86_64
---> Package kubectl.x86_64 0:1.12.1-0 will be installed
---> Package kubelet.x86_64 0:1.12.1-0 will be installed
--> Running transaction check
---> Package kubernetes-cni.x86_64 0:0.6.0-0 will be installed
--> Finished Dependency Resolution

Dependencies Resolved

================================================================================================================================================================
 Package                                   Arch                              Version                                Repository                             Size
================================================================================================================================================================
Installing:
 kubeadm                                   x86_64                            1.12.1-0                               kubernetes                            7.2 M
 kubectl                                   x86_64                            1.12.1-0                               kubernetes                            7.7 M
 kubelet                                   x86_64                            1.12.1-0                               kubernetes                             19 M
Installing for dependencies:
 kubernetes-cni                            x86_64                            0.6.0-0                                kubernetes                            8.6 M

Transaction Summary
================================================================================================================================================================
Install  3 Packages (+1 Dependent package)

Total download size: 43 M
Installed size: 217 M
Downloading packages:
(1/4): ed7d25314d0fc930c9d0bae114016bf49ee852b3c4f243184630cf2c6cd62d43-kubectl-1.12.1-0.x86_64.rpm                                      | 7.7 MB  00:00:03
(2/4): 9c31cf74973740c100242b0cfc8d97abe2a95a3c126b1c4391c9f7915bdfd22b-kubeadm-1.12.1-0.x86_64.rpm                                      | 7.2 MB  00:00:05
(3/4): c4ebaa2e1ce38cda719cbe51274c4871b7ccb30371870525a217f6a430e60e3a-kubelet-1.12.1-0.x86_64.rpm                                      |  19 MB  00:00:10
(4/4): fe33057ffe95bfae65e2f269e1b05e99308853176e24a4d027bc082b471a07c0-kubernetes-cni-0.6.0-0.x86_64.rpm                                | 8.6 MB  00:00:10
----------------------------------------------------------------------------------------------------------------------------------------------------------------
Total                                                                                                                           2.8 MB/s |  43 MB  00:00:15
Running transaction check
Running transaction test
Transaction test succeeded
Running transaction
  Installing : kubernetes-cni-0.6.0-0.x86_64                                                                                                                1/4
  Installing : kubelet-1.12.1-0.x86_64                                                                                                                      2/4
  Installing : kubectl-1.12.1-0.x86_64                                                                                                                               3/4
  Installing : kubeadm-1.12.1-0.x86_64                                                                                                                               4/4
  Verifying  : kubelet-1.12.1-0.x86_64                                                                                                                               1/4
  Verifying  : kubectl-1.12.1-0.x86_64                                                                                                                               2/4
  Verifying  : kubernetes-cni-0.6.0-0.x86_64                                                                                                                         3/4
  Verifying  : kubeadm-1.12.1-0.x86_64                                                                                                                               4/4

Installed:
  kubeadm.x86_64 0:1.12.1-0                               kubectl.x86_64 0:1.12.1-0                               kubelet.x86_64 0:1.12.1-0

Dependency Installed:
  kubernetes-cni.x86_64 0:0.6.0-0

Complete!
[root@localhost ~]#
```

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

查询依赖关系

```
[root@localhost ~]# kubeadm config images list --kubernetes-version v1.12.1
k8s.gcr.io/kube-apiserver:v1.12.1
k8s.gcr.io/kube-controller-manager:v1.12.1
k8s.gcr.io/kube-scheduler:v1.12.1
k8s.gcr.io/kube-proxy:v1.12.1
k8s.gcr.io/pause:3.1
k8s.gcr.io/etcd:3.2.24
k8s.gcr.io/coredns:1.2.2
[root@localhost ~]#
```

#### 3. 搭建kubernetes集群
先关闭上面创建的master节点，右键可以复制两个节点，我们命名起为CentOS-Node2，CentOS-Node3，如下图所示。
<img src="/img/post/k8s/k8s-p1.png" width="600"/>

可以启动其中两个看看虚拟机的ip，发现都一样。这样虚拟机之间就不能互通了。
可以设置网络桥接模式，如下图所示：
<img src="/img/post/k8s/k8s-p2.png" width="600"/>

因为墙的关系，首先需要配置下docker镜像位置，可以参考下面配置：

```
docker pull anjia0532/google-containers.kube-controller-manager-amd64:v1.12.1
docker pull anjia0532/google-containers.kube-apiserver-amd64:v1.12.1
docker pull anjia0532/google-containers.kube-scheduler-amd64:v1.12.1
docker pull anjia0532/google-containers.kube-proxy-amd64:v1.12.1
docker pull anjia0532/google-containers.pause:3.1
docker pull anjia0532/google-containers.etcd-amd64:3.2.18
docker pull anjia0532/google-containers.coredns:1.1.3

docker tag anjia0532/google-containers.kube-controller-manager-amd64:v1.12.1 k8s.gcr.io/kube-controller-manager-amd64:v1.12.1
docker tag anjia0532/google-containers.kube-apiserver-amd64:v1.12.1 k8s.gcr.io/kube-apiserver-amd64:v1.12.1
docker tag anjia0532/google-containers.kube-scheduler-amd64:v1.12.1 k8s.gcr.io/kube-scheduler-amd64:v1.12.1
docker tag anjia0532/google-containers.kube-proxy-amd64:v1.12.1 k8s.gcr.io/kube-proxy-amd64:v1.12.1
docker tag anjia0532/google-containers.pause:3.1 k8s.gcr.io/pause:3.1
docker tag anjia0532/google-containers.etcd-amd64:3.2.18 k8s.gcr.io/etcd-amd64:3.2.18
docker tag anjia0532/google-containers.coredns:1.1.3 k8s.gcr.io/coredns:1.1.3

docker rmi anjia0532/google-containers.kube-controller-manager-amd64:v1.12.1
docker rmi anjia0532/google-containers.kube-apiserver-amd64:v1.12.1
docker rmi anjia0532/google-containers.kube-scheduler-amd64:v1.12.1
docker rmi anjia0532/google-containers.kube-proxy-amd64:v1.12.1
docker rmi anjia0532/google-containers.pause:3.1
docker rmi anjia0532/google-containers.etcd-amd64:3.2.18
docker rmi anjia0532/google-containers.coredns:1.1.3
```

在Master主节点（CentOS-master）上执行:
`kubeadm init --kubernetes-version=v1.12.1 --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=192.168.2.29`

执行这个命令可能会遇到下面这个问题

```sheel
error execution phase preflight: [preflight] Some fatal errors occurred:
	[ERROR FileContent--proc-sys-net-bridge-bridge-nf-call-iptables]: /proc/sys/net/bridge/bridge-nf-call-iptables contents are not set to 1
```

可以通过下面方式关闭brige对iptables使用
`echo "1" > /proc/sys/net/bridge/bridge-nf-call-iptables`


kubeadm init 如果执行失败要 kubeadm reset 重置下。

```
[root@localhost ~]# kubeadm init --kubernetes-version=v1.12.1 --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=192.168.2.40
[init] using Kubernetes version: v1.12.1
[preflight] running pre-flight checks
[preflight/images] Pulling images required for setting up a Kubernetes cluster
[preflight/images] This might take a minute or two, depending on the speed of your internet connection
[preflight/images] You can also perform this action in beforehand using 'kubeadm config images pull'
[kubelet] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[preflight] Activating the kubelet service
[certificates] Generated ca certificate and key.
[certificates] Generated apiserver certificate and key.
[certificates] apiserver serving cert is signed for DNS names [localhost.localdomain kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local] and IPs [10.96.0.1 192.168.2.40]
[certificates] Generated apiserver-kubelet-client certificate and key.
[certificates] Generated etcd/ca certificate and key.
[certificates] Generated etcd/peer certificate and key.
[certificates] etcd/peer serving cert is signed for DNS names [localhost.localdomain localhost] and IPs [192.168.2.40 127.0.0.1 ::1]
[certificates] Generated etcd/healthcheck-client certificate and key.
[certificates] Generated etcd/server certificate and key.
[certificates] etcd/server serving cert is signed for DNS names [localhost.localdomain localhost] and IPs [127.0.0.1 ::1]
[certificates] Generated apiserver-etcd-client certificate and key.
[certificates] Generated front-proxy-ca certificate and key.
[certificates] Generated front-proxy-client certificate and key.
[certificates] valid certificates and keys now exist in "/etc/kubernetes/pki"
[certificates] Generated sa key and public key.
[kubeconfig] Wrote KubeConfig file to disk: "/etc/kubernetes/admin.conf"
[kubeconfig] Wrote KubeConfig file to disk: "/etc/kubernetes/kubelet.conf"
[kubeconfig] Wrote KubeConfig file to disk: "/etc/kubernetes/controller-manager.conf"
[kubeconfig] Wrote KubeConfig file to disk: "/etc/kubernetes/scheduler.conf"
[controlplane] wrote Static Pod manifest for component kube-apiserver to "/etc/kubernetes/manifests/kube-apiserver.yaml"
[controlplane] wrote Static Pod manifest for component kube-controller-manager to "/etc/kubernetes/manifests/kube-controller-manager.yaml"
[controlplane] wrote Static Pod manifest for component kube-scheduler to "/etc/kubernetes/manifests/kube-scheduler.yaml"
[etcd] Wrote Static Pod manifest for a local etcd instance to "/etc/kubernetes/manifests/etcd.yaml"
[init] waiting for the kubelet to boot up the control plane as Static Pods from directory "/etc/kubernetes/manifests"
[init] this might take a minute or longer if the control plane images have to be pulled
[apiclient] All control plane components are healthy after 18.505408 seconds
[uploadconfig] storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config-1.12" in namespace kube-system with the configuration for the kubelets in the cluster
[markmaster] Marking the node localhost.localdomain as master by adding the label "node-role.kubernetes.io/master=''"
[markmaster] Marking the node localhost.localdomain as master by adding the taints [node-role.kubernetes.io/master:NoSchedule]
[patchnode] Uploading the CRI Socket information "/var/run/dockershim.sock" to the Node API object "localhost.localdomain" as an annotation
[bootstraptoken] using token: 27cj9s.1jfbcj18iucf82yr
[bootstraptoken] configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstraptoken] configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstraptoken] configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[bootstraptoken] creating the "cluster-info" ConfigMap in the "kube-public" namespace
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

Your Kubernetes master has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of machines by running the following on each node
as root:

  kubeadm join 192.168.2.40:6443 --token iti9mo.pbnq2rkjyfsioo3v --discovery-token-ca-cert-hash sha256:a05528691d7117e21ccee9ee58a76a788026b9fc44ca1ebab5f452ed4ef003a6
```

注意 --apiserver-advertise-address，这是API server用来告知集群中其它成员的地址，这也是在 init流程的时候用来构建kubeadm join命令行的地址。

初始化集群成功后需要执行如下命令：

```sheel
[root@localhost ~]# mkdir -p $HOME/.kube
[root@localhost ~]# cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
[root@localhost ~]# chown $(id -u):$(id -g) $HOME/.kube/config
```
安装calico网络插件：

```
kubectl apply -f https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml
kubectl apply -f https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml
```
  
执行`kubectl get pod -n kube-system` 和 `kubectl get nodes` 查看状态。

在node加入master节点如果出了问题，第一步是看kubelet在子节点是不是跑起来了`systemctl status kubelet`，如果没跑起来，用`journalctl -xefu kubelet`命令查看错误日志。

最后通过如下方式将node2和node3加入到集群里面来。
`kubeadm join 192.168.2.40:6443 --token iti9mo.pbnq2rkjyfsioo3v --discovery-token-ca-cert-hash sha256:a05528691d7117e21ccee9ee58a76a788026b9fc44ca1ebab5f452ed4ef003a6`

#### 4. 搭建Kubernetes Dashboard

在master节点上建 kubernetes-dashboard.yaml 文件内容如下:

```yaml
# Filename: dashboard.yaml
# Revision: 1.0
# Date: 2018/10/18
# Author: along
# Description: Build kubernetes dashboard

# ------------------- Dashboard Secret ------------------- #

apiVersion: v1
kind: Secret
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard-certs
  namespace: kube-system
type: Opaque

---
# ------------------- Dashboard Service Account ------------------- #

apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kube-system

---
# ------------------- Dashboard Role & Role Binding ------------------- #

kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: kubernetes-dashboard-minimal
  namespace: kube-system
rules:
  # Allow Dashboard to create 'kubernetes-dashboard-key-holder' secret.
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["create"]
  # Allow Dashboard to create 'kubernetes-dashboard-settings' config map.
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["create"]
  # Allow Dashboard to get, update and delete Dashboard exclusive secrets.
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["kubernetes-dashboard-key-holder", "kubernetes-dashboard-certs"]
  verbs: ["get", "update", "delete"]
  # Allow Dashboard to get and update 'kubernetes-dashboard-settings' config map.
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["kubernetes-dashboard-settings"]
  verbs: ["get", "update"]
  # Allow Dashboard to get metrics from heapster.
- apiGroups: [""]
  resources: ["services"]
  resourceNames: ["heapster"]
  verbs: ["proxy"]
- apiGroups: [""]
  resources: ["services/proxy"]
  resourceNames: ["heapster", "http:heapster:", "https:heapster:"]
  verbs: ["get"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: kubernetes-dashboard-minimal
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: kubernetes-dashboard-minimal
subjects:
- kind: ServiceAccount
  name: kubernetes-dashboard
  namespace: kube-system

---
# ------------------- Dashboard Deployment ------------------- #

kind: Deployment
apiVersion: apps/v1beta2
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kube-system
spec:
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      k8s-app: kubernetes-dashboard
  template:
    metadata:
      labels:
        k8s-app: kubernetes-dashboard
    spec:
      containers:
      - name: kubernetes-dashboard
        image: mirrorgooglecontainers/kubernetes-dashboard-amd64:v1.10.0
        ports:
        - containerPort: 8443
          protocol: TCP
        args:
          - --auto-generate-certificates
          # Uncomment the following line to manually specify Kubernetes API server Host
          # If not specified, Dashboard will attempt to auto discover the API server and connect
          # to it. Uncomment only if the default does not work.
          # - --apiserver-host=http://my-address:port
        volumeMounts:
        - name: kubernetes-dashboard-certs
          mountPath: /certs
          # Create on-disk volume to store exec logs
        - mountPath: /tmp
          name: tmp-volume
        livenessProbe:
          httpGet:
            scheme: HTTPS
            path: /
            port: 8443
          initialDelaySeconds: 30
          timeoutSeconds: 30
      volumes:
      - name: kubernetes-dashboard-certs
        secret:
          secretName: kubernetes-dashboard-certs
      - name: tmp-volume
        emptyDir: {}
      serviceAccountName: kubernetes-dashboard
      # Comment the following tolerations if Dashboard must not be deployed on master
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule

---

# ------------------- Dashboard Service ------------------- #

kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kube-system
spec:
  type: NodePort
  ports:
    - port: 443
      targetPort: 8443
      nodePort: 30000
  selector:
    k8s-app: kubernetes-dashboard

```

然后就可以部署dashboard了
`kubectl create -f kubernetes-dashboard.yaml`

```
[root@master ~]# kubectl -n kube-system get svc kubernetes-dashboard
NAME                   TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)         AGE
kubernetes-dashboard   NodePort   10.107.152.100   <none>        443:30000/TCP   4h29m
```

然后我们可以通过`https://192.168.2.40:30000/`dashboard了。chrome浏览器有安全策略控制，点击advance，然后Proceed to 192.168.2.40 (unsafe)，可以看到如下界面：
<img src="/img/post/k8s/dashboard-login.png" width="600"/>

我们用token方式登录，先建立admin-role.yaml文件，内容如下：

```yaml
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: admin
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: admin
  namespace: kube-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin
  namespace: kube-system
  labels:
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
```
执行如下创建serviceaccount角色并获取token。

```sheel
[root@master ~]# kubectl create -f admin-role.yaml

clusterrolebinding.rbac.authorization.k8s.io/admin created
serviceaccount/admin created
[root@master ~]# kubectl -n kube-system get secret|grep admin-token
admin-token-rdpcw                                kubernetes.io/service-account-token   3      13s
[root@master ~]# kubectl -n kube-system describe secret admin-token-rdpcw
Name:         admin-token-rdpcw
Namespace:    kube-system
Labels:       <none>
Annotations:  kubernetes.io/service-account.name: admin
              kubernetes.io/service-account.uid: 407647a5-feb2-11e8-ab46-080027c9c18d

Type:  kubernetes.io/service-account-token

Data
====
ca.crt:     1025 bytes
namespace:  11 bytes
token:      eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJhZG1pbi10b2tlbi1yZHBjdyIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJhZG1pbiIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50LnVpZCI6IjQwNzY0N2E1LWZlYjItMTFlOC1hYjQ2LTA4MDAyN2M5YzE4ZCIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDprdWJlLXN5c3RlbTphZG1pbiJ9.Ni1r3q7xuKLstby93F5GSeVRJNfo3nuAgom4kgV9HRJihUH9s92vxNHGCcduw__2nPinLQbONbPlmCn7VkOjSloC8_EHj96cTBJiJAb64hFlndz3vi5zFCnWQygt2yfOyLaLL4qN-7T2oki1HEf8AM4E4t0cl25M-FhxD8OiIeVcg9AAcCetIz_LTX4c7c8_1gpZAbApcFql9hz-f7g5HgFroRD9PjogJm1TPGYh1_iRk-AI4GzUTerD0XVdm1S5-2Zu_B_nja4YqyveMAvp0wrynxKms2MWZT572KBulLicG_xdi9CMeasHbDnqOw8ZrhYfM48envINcL8v9sE0rg
[root@master ~]#
```

通过上面的token登录就可以进入dashboard主界面了
<img src="/img/post/k8s/dashboard-main.png" width="600"/>