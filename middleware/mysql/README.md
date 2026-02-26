
# 配置数据库服务

第一步：创建环境变量，并修改配置
mv .env.template .env 

第二步：在目录`init.db`中，添加初始化脚本，可以是创建数据库，以及授权给某个用户

第三步：启动容器
docker compose up -d

## 设置初始化语句

1. 基于模版创建

```shell
cp -rf init.db.template init.db
```

2. 修改`01.sql`，或者新建`02.sql`

# 启动数据库服务

1. 进入容器
```bash
docker compose exec <service name, mysql> bash
# 或者
docker exec -it <container id> bash
```

2. 登录，以root用户登录

```bash
mysql -h localhost -u root -p
```

# 常用数据库操作

```bash
# 查看数据库的所有用户
SELECT user, host FROM mysql.user;

# 建库，例如test库
create database test;

# 查看数据库的所有者
select * from information_schema.SCHEMA_PRIVILEGES;

# 创建用户，用户名和密码都是test0
create user if not exists 'test0'@'%' identified with caching_sha2_password BY 'test0';

# 修改用户名，将用户名改为test1
ALTER USER 'test0'@'%' IDENTIFIED BY 'test1';

# 修改密码，修改test1的密码为password1
ALTER USER 'test1'@'%' IDENTIFIED BY 'password1';

# 授权数据库`test`给用户`test1`
grant all privileges on test.* to 'test1'@'%';

```

## 常见主机名对应关系

| 主机值 | 含义 | 访问来源 |
|--------|------|----------|
| `localhost` | 本地 socket 连接 | 本地程序 |
| `127.0.0.1` | 本地 TCP/IP 连接 | 本地程序 |
| `%` | 任意主机 | 远程连接 |
| `192.168.x.x` | 特定 IP | 局域网 |
