
## Ubuntu

使用ufw工具：
```bash
# 开放TCP端口12341到12344
sudo ufw allow 12341:12344/tcp

# 开放UDP端口（如果需要）
sudo ufw allow 12341:12344/udp

# 验证是否成功
sudo ufw status

# 删除刚才添加的规则（如果需要撤销）
sudo ufw delete allow 12341:12344/tcp

# 重新加载防火墙规则
sudo ufw reload

# 关闭防火墙（不推荐）
sudo ufw disable

```

