
## 安装

```bash
# Ubuntu/Debian
apt install tmux

# MacOS (Homebrew)
brew install tmux
```

## 常用命令

```bash
# 查看所有会话
tmux ls

# 开启新会话
tmux new -s <session name>

# 推到后台（detach）, 先按ctrl + b, 再按d

# 拉回终端（attach）
tmux -a -t <session name>

# 关闭所有会话
tmux kill-server

# 关闭某个会话，在会话里面直接执行 exit 或者 ctrl + d，在会话外面执行
tmux kill-session -t <session name>
```
