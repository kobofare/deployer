

## 配置Git代理
在开发环境中配置代理：
- 本地开启了`sock5`代理且端口是`1080`
- 安装依赖`apt install connect-proxy`
- 在配置文件$HOME/.ssh/config添加代理
```text
Host github.com
    HostName github.com
    User git
    ProxyCommand connect -S 127.0.0.1:1080 %h %p
```

## 添加公钥
- 在开发环境中生成公私钥对`ssh-keygen`，公钥文件默认是`$HOME/.ssh/id_ed25519.pub`
- 登陆Github -> 点击右上角头像 -> Settings (设置) -> 在左侧菜单找到 SSH and GPG keys -> 点击绿色的 New SSH key 按钮 -> 粘贴公钥文件中的内容到*key* -> 点击 Add SSH key

## 配置Git
在开发环境中配置用户名和邮箱：
```bash
git config --global user.name "你的GitHub用户名"
git config --global user.email "你的GitHub邮箱"
```

