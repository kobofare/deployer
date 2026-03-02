
# LINUX 网络工具

## lsof

## ss

```bash

# 查看所有监听的 TCP 和 UDP 端口
ss -tuln
# -t: TCP
# -u: UDP
# -l: 监听
# -n: 数字形式（不解析域名和服务名）

# 查看所有已建立的 TCP 连接
ss -tn

# 查看所有连接（包括监听），并显示进程信息
ss -tulnp

# 查看连接到特定 IP 和端口的连接
ss dst 203.0.113.5:443

# 查看本地监听的特定端口
ss -l sport = :3306

```

## netstat


