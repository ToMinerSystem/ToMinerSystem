<div align="center">

# ToMinerSystem

**面向 Windows 与 Ubuntu 的多币种矿池中转、端口管理和 TMS 加密传输系统**

通过统一 Web 管理端配置中转端口、查看矿机状态和 Share 统计，并可使用 TMS 客户端在本地矿机与远程服务器之间建立加密链路。

</div>

## 目录

- [主要功能](#主要功能)
- [支持范围](#支持范围)
- [工作方式](#工作方式)
- [发行文件](#发行文件)
- [Ubuntu 服务端安装](#ubuntu-服务端安装)
- [Windows 服务端启动](#windows-服务端启动)
- [TMS 本地客户端](#tms-本地客户端)
- [服务费说明](#服务费说明)
- [安全建议](#安全建议)
- [常见问题](#常见问题)

## 主要功能

- 一个端口对应一组独立的币种、主矿池、备用矿池和传输配置。
- 支持 TCP、SSL/TLS 上游连接以及 Nginx Raw TCP/SSL 转发模式。
- Web 管理端提供端口启停、在线/离线矿机、算力、Share、日志和 TMS 配对管理。
- 主矿池不可用时可按端口配置切换备用矿池。
- TMS 客户端支持本地矿机通过 TCP 或 SSL 接入，再通过加密链路连接远程 ToMinerSystem 服务端。
- Windows 和 Ubuntu 均提供独立程序；Ubuntu 安装脚本自动注册 systemd 开机自启动。
- 首次安装随机生成 `52347–61892` 范围内的 Web 端口，后续启动保持不变；卸载后重新安装会重新生成。
- 服务费默认 `0%`，不预置服务费账户或服务费矿池。

## 支持范围

| 币种/模式 | 内置协议或方式 | 中转状态 | 服务费调度状态 |
|---|---|---|---|
| BTC | Bitcoin Stratum V1 | 支持 TCP/TLS、Job 与 Share 路由 | 已接入解析型调度 |
| BCH | Bitcoin Stratum V1 | 支持 TCP/TLS、Job 与 Share 路由 | 已接入解析型调度 |
| LTC | Litecoin Stratum V1 | 支持 TCP/TLS、Job 与 Share 路由 | 已接入解析型调度 |
| ETC | Ethereum Stratum / EthProxy | 支持多种行式 JSON 路径 | 可配置；具体矿池变体仍需真实矿机验证 |
| KAS | 独立协议适配入口 | 支持已配置的数据路径 | 协议级切换等待真实矿池验证 |
| ALEO | 独立协议适配入口 | 支持已配置的数据路径 | 协议级切换等待真实矿池验证 |
| PRL | PearlHash 行式 JSON | 支持 TCP/TLS 转发和 Share 监控 | 协议级切换等待真实矿池验证 |
| Nginx | Raw TCP/SSL | 仅进行字节转发和故障转移 | 不适用，不解析 Job/Share |

“可配置”不等于已通过全部真实矿池验证。运行时只有在服务费上游连接、认证和有效 Job 均准备完成后才会尝试切换；条件不满足时保持或返回主池，不伪造 Share、accepted 结果或算力数据。

## 工作方式

```text
普通中转
矿机 ──TCP/SSL──> ToMinerSystem 服务端 ──TCP/TLS──> 主矿池 / 备用矿池

TMS 加密传输
矿机 ──TCP/SSL──> 局域网 TMS 客户端 ══加密链路══> ToMinerSystem 服务端 ──> 矿池
```

TMS 端口在服务器 Web 中创建。TMS 客户端首次填写服务器 Web 提供的配对码后会保存绑定信息，随后自动连接并同步服务器端创建、修改、启停或删除的 TMS 线路。

## 发行文件

| 平台 | 文件 | 用途 |
|---|---|---|
| Windows | [`windows/ToMinerSystem-Server.exe`](windows/ToMinerSystem-Server.exe) | ToMinerSystem 服务端 |
| Ubuntu x86_64 | [`linux/tominersystem-server-linux-x86_64`](linux/tominersystem-server-linux-x86_64) | ToMinerSystem 服务端程序 |
| Ubuntu x86_64 | [`install.sh`](install.sh) | 服务端安装与管理脚本 |
| Windows | [`TMS/windows/ToMinerSystem-TMS.exe`](TMS/windows/ToMinerSystem-TMS.exe) | TMS 本地客户端 |
| Ubuntu x86_64 | [`TMS/linux/tms-local-linux-x86_64`](TMS/linux/tms-local-linux-x86_64) | TMS 本地客户端程序 |
| Ubuntu x86_64 | [`TMS/install.sh`](TMS/install.sh) | TMS 安装与管理脚本 |

发布前建议同时核对 GitHub Release 页面提供的 SHA-256 校验值。Ubuntu 安装脚本还会校验下载程序的固定 SHA-256。

## Ubuntu 服务端安装

当前安装脚本支持 Ubuntu x86_64。使用 `root` 或具有 `sudo` 权限的账户执行：

```bash
curl -fsSL -o install.sh \
  https://github.com/EvilGenius-dot/shortcut/raw/main/Readme/92/install.sh
chmod +x install.sh
sudo bash install.sh install
```

安装完成后终端会显示：

- Web 访问地址和随机端口；
- 默认管理员账户 `admin`；
- 本次安装生成的初始密码；
- systemd 服务状态。

常用管理命令：

```bash
sudo bash install.sh start
sudo bash install.sh stop
sudo bash install.sh restart
sudo bash install.sh status
sudo bash install.sh web-port
sudo bash install.sh reset-password
sudo bash install.sh uninstall
```

查看实时日志：

```bash
sudo journalctl -u tominersystem -f
```

> [!NOTE]
> 安装脚本开头集中保存 `VERSION`、`APP_NAME`、`APP_ID`、`DOWNLOAD_HOST` 和 `SERVICE_NAME`。自行托管发行文件时，只需修改该区域的下载地址和品牌参数。

## Windows 服务端启动

1. 下载 [`ToMinerSystem-Server.exe`](windows/ToMinerSystem-Server.exe) 到单独文件夹。
2. 双击运行；如被 Windows 防火墙询问，请只允许实际需要的网络范围。
3. 在启动窗口查看 Web 访问端口、管理员账户和初始密码。
4. 浏览器打开启动窗口显示的地址并登录。
5. 创建端口后，将矿机连接地址填写为 `服务器IP:监听端口`。

请勿将程序放在系统临时目录中运行。配置、日志、证书和状态文件应随程序目录一起备份。

## TMS 本地客户端

### Windows

1. 下载并运行 [`ToMinerSystem-TMS.exe`](TMS/windows/ToMinerSystem-TMS.exe)。
2. 在 ToMinerSystem 服务端 Web 的 **TMS** 页面复制配对码。
3. 首次在 TMS 客户端中粘贴配对码并保存。
4. 绑定成功后，TMS 会自动连接服务器并同步 TMS 端口。
5. 本地页面会显示矿机应连接的局域网地址，例如 `192.168.1.5:3333`。

识别码修改并保存后会立即按新配置连接；正常情况下，下次打开无需重复输入。

### Ubuntu

```bash
curl -fsSL -o install-tms.sh \
  https://github.com/EvilGenius-dot/shortcut/raw/main/Readme/92/TMS/install.sh
chmod +x install-tms.sh
sudo bash install-tms.sh install
```

安装完成后终端会显示 TMS Web 地址、默认账户和初始密码。管理命令：

```bash
sudo bash install-tms.sh start
sudo bash install-tms.sh stop
sudo bash install-tms.sh restart
sudo bash install-tms.sh status
sudo bash install-tms.sh web-port
sudo bash install-tms.sh uninstall
```

## 服务费说明

ToMinerSystem 的默认安装状态为：

```text
服务费比例：0%
服务费账户：未配置
服务费矿池：未配置
```

服务费按端口单独配置，启用规则为：

```text
服务费账户非空 AND 服务费比例大于 0
```

满足条件后保存端口会自动创建该端口的服务费调度；清空账户或将比例设为 `0` 会自动关闭。Nginx 模式不解析矿池协议，因此不提供服务费调度。

调度统计只计入对应上游真实确认的 accepted Share/工作量。服务费上游连接、认证、Job 或 Share 路由发生异常时，程序优先保持主池中转并停止新的调度，不用虚假数据补偿差额。

## 安全建议

- 首次登录后立即修改管理员密码，并妥善保存新密码。
- 不要把管理 Web 端直接暴露给整个互联网；优先使用防火墙白名单、VPN、SSH 隧道或可信反向代理。
- Web 登录包含密码哈希、登录限速、HttpOnly Cookie、CSRF 防护和接口限流，但仍需要正确配置主机防火墙。
- 仅开放实际使用的中转端口和管理来源，定期检查运行日志与错误日志。
- TMS 配对码等同于连接凭据，不要在群聊、截图或公开仓库中泄露。
- 备份配置和证书时一并保护文件权限；日志中不应记录钱包密码、Token 或私钥。
- 从官方发布位置下载文件，并在运行前核对 SHA-256。

## 常见问题

### Web 页面提示 `Failed to fetch`

通常表示浏览器无法访问后端接口。请依次检查：

1. ToMinerSystem 服务是否正在运行；
2. 浏览器地址和 Web 端口是否与启动窗口或 `web-port` 命令一致；
3. Windows 防火墙、UFW 或云安全组是否放行该端口；
4. 页面是否通过旧书签访问了已经卸载重装前的端口；
5. HTTPS 页面是否错误请求了 HTTP 接口。

### Ubuntu 重启后是否需要手动启动？

不需要。安装脚本会创建并启用 systemd 服务。可通过以下命令确认：

```bash
sudo systemctl status tominersystem --no-pager
```

### 为什么 Web 端口与示例不同？

首次安装会在 `52347–61892` 范围随机选择空闲端口，并保存到配置中。普通重启不会改变；卸载后重新安装会重新生成。

### Nginx 为什么没有矿机账户、Share 和服务费统计？

Nginx 是 Raw TCP/SSL 字节转发模式，不解析矿池协议，所以无法可靠识别 Worker、Job、Share 或 accepted 结果，也不会创建服务费调度器。

### 服务费池异常会导致矿机断线吗？

服务费路径被设计为主中转的附属功能。运行时预检或切换失败会停止新的服务费调度并尝试保持/恢复主池；不会伪造成功结果。不同矿池协议变体仍应在正式部署前使用真实矿机进行小规模验证。

## 仓库结构

```text
.
├── README.md
├── install.sh
├── linux/
│   └── tominersystem-server-linux-x86_64
├── windows/
│   └── ToMinerSystem-Server.exe
└── TMS/
    ├── install.sh
    ├── linux/
    │   └── tms-local-linux-x86_64
    └── windows/
        └── ToMinerSystem-TMS.exe
```

## 使用边界

本软件用于已获授权的矿机中转与管理环境。部署者负责确认其对矿机、网络、矿池账户和服务费配置拥有合法授权，并遵守所在地法律、矿池条款及网络安全要求。程序不应被用于隐藏服务费、伪造 Share、篡改 accepted 统计或接入未经授权的设备。

---

<div align="center">

**ToMinerSystem 5.0.4 · Windows / Ubuntu · Default Fee 0%**

</div>
