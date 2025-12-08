# Python 多版本管理：pyenv + venv（Ubuntu）

本文档介绍在 Ubuntu 上使用 **pyenv** 管理多个 Python 版本，并配合 **venv** 创建项目级虚拟环境的推荐工作流。

## 安装 pyenv

### 脚本安装

```bash
curl https://pyenv.run | bash
```

### 配置环境变量

在 ~/.bashrc 末尾追加：

```text
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
```

然后重新加载：

```bash
source ~/.bashrc
```

### 查看可安装 Python 版本

```bash
pyenv install -l
```

---

## 使用 pyenv 管理

### 安装指定 Python 版本 

```bash
pyenv install 3.12.6
```

### 设置全局默认版本

```bash
pyenv global 3.12.6
```

### 给项目单独指定版本

```bash
pyenv local 3.10.14
```

### 切换当前终端版本
```bash
pyenv shell 3.12.6
```

---

## 创建虚拟环境

### 在项目中创建虚拟环境

```bash
python -m venv .venv
```

### 激活虚拟环境

```bash
source .venv/bin/activate
```

### 退出虚拟环境

```bash
deactivate
```

