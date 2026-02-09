# ProxyList

SNIProxy + DNSMasq 代理配置管理工具

支持 Netflix, Disney+, HBO, Hulu, Amazon Prime Video, OpenAI, Claude, Gemini 等主流流媒体和 AI 服务的解锁。

## 功能特性

- ✅ 支持主流流媒体平台（Netflix, Disney+, HBO, Hulu 等）
- ✅ 支持 AI 服务（OpenAI, Claude, Gemini, Perplexity 等）
- ✅ 自动备份配置文件
- ✅ 自动重启服务
- ✅ 智能 IP 地址替换
- ✅ 域名重复检查

## 快速开始

### 1. 更新配置文件

一键替换 SNIProxy 和 DNSMasq 配置：

```bash
curl -fsSL https://raw.githubusercontent.com/csznet/proxylist/main/update.sh | sudo bash
```

或下载后手动执行：

```bash
sudo ./update.sh
```

**功能说明：**
- 选项 1：仅替换 SNIProxy 配置
- 选项 2：仅替换 DNSMasq 配置
- 选项 3：替换所有配置

### 2. 添加自定义域名

一键添加新域名到代理列表：

```bash
curl -fsSL https://raw.githubusercontent.com/csznet/proxylist/main/add_domain.sh | sudo bash
```

或下载后手动执行：

```bash
sudo ./add_domain.sh
```

**功能说明：**
- 自动检测服务和配置文件
- 支持批量添加域名（空格或逗号分隔）
- 自动检查域名是否重复
- 自动重启相关服务

## 支持的服务

### 流媒体平台
- Netflix
- Disney+
- HBO Max
- Hulu
- Amazon Prime Video
- BBC iPlayer
- Crunchyroll
- 巴哈姆特动画疯
- AbemaTV
- DMM
- 更多...

### AI 服务
- OpenAI (ChatGPT)
- Anthropic (Claude)
- Google (Gemini/Bard)
- Perplexity
- DeepSeek
- Mistral AI
- Cohere
- Character.AI
- HuggingFace

## 配置路径

默认配置文件路径：
- SNIProxy: `/etc/sniproxy.conf`
- DNSMasq: `/etc/dnsmasq.d/custom_netflix.conf`

## 使用示例

### 示例 1：批量添加 AI 域名

```bash
$ sudo ./add_domain.sh

# 输入域名时：
域名: openai.com claude.ai gemini.google.com
```

### 示例 2：更新配置并保留原 IP

```bash
$ sudo ./update.sh

# 选择选项：
请输入选项 [0-3]: 3

# 脚本会自动：
# 1. 检测原配置的 IP 地址（如 192.168.1.100）
# 2. 替换配置文件中的 1.1.1.1 为原 IP
# 3. 重启服务
```

## 注意事项

1. 脚本需要 root 权限运行
2. 执行前会自动备份原配置文件（格式：`*.backup.时间戳`）
3. DNSMasq 配置会自动保留原 IP 地址
4. 支持 systemctl 和 service 两种服务管理方式

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！

## 仓库地址

https://github.com/csznet/proxylist
