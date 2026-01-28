
本文档介绍在 Ubuntu 上使用 **pyenv** 管理多个 Python 版本，并配合 **venv** 创建项目级虚拟环境的推荐工作流。

# Python 多版本管理：pyenv + venv（MacOS）

## 安装 pyenv

### 使用 Homebrew 安装
```bash
brew install pyenv
```

### 配置环境变量

在 ~/.zshrc 末尾追加：

```bash
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc
echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(pyenv init - zsh)"' >> ~/.zshrc
```

然后重新加载：

```bash
source ~/.zshrc
```

---

# Python 多版本管理：pyenv + venv（Ubuntu）

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

---

# 常用命令

## pyenv 常用命令
```bash
# 查看可安装 Python 版本
pyenv install -l

# 查看已安装的 Python 版本
pyenv versions

# 安装指定 Python 版本 

# ubuntu下安装依赖, macos下不用
apt update && apt install -y \
  build-essential \
  libssl-dev \
  zlib1g-dev \
  libbz2-dev \
  libreadline-dev \
  libsqlite3-dev \
  libffi-dev \
  libncursesw5-dev \
  libncurses-dev \
  xz-utils \
  tk-dev \
  libxml2-dev \
  libxmlsec1-dev \
  liblzma-dev

# 如果下载慢，可以手动下载, 以`Python-3.11.14.tar.xz`为例
# 1. 将下载的文件移动到 pyenv 的缓存目录
mkdir -p ~/.pyenv/cache
mv ~/Downloads/Python-3.11.14.tar.xz ~/.pyenv/cache/

pyenv install 3.11.14


# 设置全局默认版本
pyenv global 3.11.14

# 给项目单独指定版本
pyenv local 3.10.14

# 切换当前终端版本
pyenv shell 3.12.6

```

## 创建虚拟环境

```bash
# 在项目中创建虚拟环境
python -m venv .venv

# 激活虚拟环境
source .venv/bin/activate

# 退出虚拟环境
deactivate

```

## 设置 pip 国内加速
```bash
# 设置国内加速
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

# 升级 pip 本身
python -m pip install --upgrade pip -i https://pypi.tuna.tsinghua.edu.cn/simple

```
