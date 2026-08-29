<div id="top"></div>

<div align="center">

# ToMinerSystem

### <a href="#anzhuang">多币种矿池中转，或通过 TMS 建立本地加密传输！点击查看！</a>

<br>

<a href="#anzhuang">
   <img src="https://img.shields.io/badge/%E5%AE%89%E8%A3%85%E6%95%99%E7%A8%8B-%F0%9F%91%88-00b9ff" alt="安装教程">
</a>
<a href="#bizhong">
   <img src="https://img.shields.io/badge/%E6%94%AF%E6%8C%81%E5%B8%81%E7%A7%8D-%F0%9F%91%88-8A2BE2" alt="支持币种">
</a>
<a href="#tms">
   <img src="https://img.shields.io/badge/TMS%E5%AE%A2%E6%88%B7%E7%AB%AF-%F0%9F%94%90-5865F2" alt="TMS客户端">
</a>
<a href="#fee">
   <img src="https://img.shields.io/badge/%E9%BB%98%E8%AE%A4%E6%9C%8D%E5%8A%A1%E8%B4%B9-0%25-16A34A" alt="默认服务费0%">
</a>

</div>

<table>
   <tr>
   <td>

<span id="anzhuang"></span>

## 服务协议

> [!CAUTION]
> 请注意，不同国家或地区的法律法规、矿池条款和网络管理要求可能限制此类产品或服务的使用。
>
> 本产品是矿机中转、端口管理和本地加密传输工具，不是 VPN 产品，也不用于绕过地区、网络或矿池的访问限制。
>
> 所有接入设备均应由矿机所有者或获得明确授权的管理人员主动配置连接地址。请勿接入未经授权的矿机、账户或网络。
>
> 本产品不应被用于伪造 Share、伪造 accepted 结果、篡改矿池统计、隐藏服务费或修改未经授权的钱包账户。
>
> 服务费账户、比例和矿池必须由管理员明确配置。默认安装不预置服务费账户、服务费矿池或开发者费率，默认比例为 `0%`。
>
> 您应理解并遵守所在地法律法规、矿池规则及网络安全要求。因部署或使用方式产生的责任由部署者和使用者承担。

### 👉 **Linux 安装**

   <p>&emsp;&emsp;Ubuntu、Debian 或 CentOS x86_64 服务器运行以下 Shell 指令打开 ToMinerSystem 安装菜单：</p>

   ```sh
   bash <(curl -s -L https://github.com/ToMinerSystem/ToMinerSystem/raw/main/install.sh)
   ```

   <p>&emsp;&emsp;安装脚本会自动识别发行版，Ubuntu/Debian 使用 <code>apt-get</code>，CentOS 使用 <code>dnf</code> 或 <code>yum</code>；随后下载 glibc 2.17 兼容程序、随机生成 Web 端口和初始密码，并注册 systemd 开机自启动服务。</p>

   <p>&emsp;&emsp;默认后台账户为 <code>admin</code>，初始密码和 Web 访问地址以安装完成后的终端提示为准。</p>

   <p>&emsp;&emsp;Web 端口首次安装时会在 <code>52347–61892</code> 范围内随机生成；普通启动或系统重启不会改变，卸载后重新安装会重新生成。</p>

   <p>&emsp;&emsp;常用管理指令：</p>

   ```sh
   sudo bash install.sh start
   sudo bash install.sh stop
   sudo bash install.sh restart
   sudo bash install.sh update
   sudo bash install.sh install-version 1.0.0
   sudo bash install.sh status
   sudo bash install.sh web-port
   sudo bash install.sh reset-password
   sudo bash install.sh uninstall
   ```

   <p>&emsp;&emsp;菜单中的“更新”会自动识别 GitHub 中最高的正式版本目录；“安装指定版本”可输入 <code>x.y.z</code> 版本号进行安装或回退。</p>

   <p>&emsp;&emsp;查看实时日志：</p>

   ```sh
   sudo journalctl -u tominersystem -f
   ```

   </td>
   </tr>
   <tr>
   <td>

### 👉 **Windows 安装**

   <p>&emsp;&emsp;请直接从此项目的 Windows 目录下载服务端程序：</p>

   ```text
   windows/ToMinerSystem-1.0.0.exe
   ```

   <p>&emsp;&emsp;下载地址：<a href="windows/ToMinerSystem-1.0.0.exe">ToMinerSystem-1.0.0.exe</a></p>

   <p>&emsp;&emsp;Windows 版本放入单独文件夹后直接双击启动即可。</p>

   <p>&emsp;&emsp;默认后台账户为 <code>admin</code>，初始密码和 Web 访问端口会显示在启动窗口中。</p>

   <p>&emsp;&emsp;程序目录会保存配置、日志、证书和运行状态，请勿放在系统临时目录中，也不要只移动其中的单个配置文件。</p>

   </td>
   </tr>
   <tr>
   <td>

<span id="bizhong"></span>

### 👉 **支持的算法、协议及币种**

<p>&emsp;&emsp;ToMinerSystem 根据币种自动选择程序内置协议，Web 端不需要手动选择协议适配器。</p>

```text
  算法 / 协议             支持的币种或模式
  SHA256D                 BTC、BCH
  SCRYPT                  LTC
  ETHASH / ETHPROXY       ETC
  KHEAVYHASH              KAS
  ALEO ADAPTER            ALEO
  PEARLHASH LINE JSON     PRL
  RAW TCP / SSL           Nginx
```

<p>&emsp;&emsp;当前协议状态：</p>

```text
  BTC、BCH、LTC    支持常见 Stratum V1、Job/Share 路由和解析型服务费调度
  ETC              支持 Ethereum Stratum mining.* 与 EthProxy 行式 JSON 路径
  KAS、ALEO        使用各自独立的协议适配入口
  PRL              支持 PearlHash 行式 JSON 的 TCP/TLS 转发和 Share 监控
  Nginx            仅进行 Raw TCP/SSL 字节转发和备用地址故障转移
```

> [!NOTE]
> 不同矿池可能使用不同协议变体。“可以配置”不等同于已经通过所有真实矿池验证。ETC、KAS、ALEO、PRL 的协议级服务费切换仍应使用真实矿机和目标矿池进行小规模验证；无法安全预热、认证或获得有效 Job 时，程序保持主池中转，不伪造切换成功。

   </td>
   </tr>
   <tr>
   <td>

<span id="tms"></span>

### 👉 **TMS 本地加密客户端**

<p>&emsp;&emsp;TMS 用于让局域网矿机先连接本地客户端，再通过加密链路连接远程 ToMinerSystem 服务端：</p>

```text
矿机 ──TCP/SSL──> 本地 TMS 客户端 ══加密链路══> ToMinerSystem 服务端 ──> 矿池
```

<p>&emsp;&emsp;Windows 版本下载：</p>

```text
TMS/windows/win-TMS.exe
```

<p>&emsp;&emsp;下载地址：<a href="TMS/windows/win-TMS.exe">win-TMS.exe</a></p>

<p>&emsp;&emsp;Ubuntu、Debian、CentOS/RHEL 系列的 x86_64 或 ARM64 服务器运行以下指令打开安装管理菜单：</p>

```sh
bash <(curl -fsSL https://github.com/ToMinerSystem/ToMinerSystem/raw/main/TMS/TMS-install.sh)
```

<p>&emsp;&emsp;首次打开 TMS 客户端时，在 ToMinerSystem 服务端 Web 的 TMS 页面复制配对码并粘贴保存。绑定成功后，客户端会自动连接服务器并同步 Web 端创建、修改、启停或删除的 TMS 端口。</p>

<p>&emsp;&emsp;本地 TMS 页面会显示矿机应连接的局域网地址，例如 <code>192.168.1.5:3333</code>。识别码保存后下次打开不需要重复输入；更换识别码并保存后会按新配置自动连接。</p>

<p>&emsp;&emsp;Linux TMS 常用管理指令：</p>

```sh
sudo bash TMS-install.sh start
sudo bash TMS-install.sh stop
sudo bash TMS-install.sh restart
sudo bash TMS-install.sh update
sudo bash TMS-install.sh install-version 1.0.0
sudo bash TMS-install.sh status
sudo bash TMS-install.sh web-port
sudo bash TMS-install.sh uninstall
```

   </td>
   </tr>
   <tr>
   <td>

<span id="fee"></span>

### 👉 **服务费说明**

<p>&emsp;&emsp;程序、安装脚本和初始配置默认均为 <strong>0% 服务费</strong>，不预置服务费账户或服务费矿池。</p>

<p>&emsp;&emsp;服务费按端口单独配置。服务费账户非空且比例大于 0 时，保存端口后自动启用；清空账户或把比例设为 0 后自动关闭，不需要额外的启用开关。</p>

<p>&emsp;&emsp;服务费统计只计入对应上游真实确认的 accepted Share 或工作量。服务费上游连接、认证、Job 或路由异常时，程序优先保持或恢复主池中转，不使用虚假数据补偿差额。</p>

<p>&emsp;&emsp;Nginx 是 Raw TCP/SSL 字节转发模式，不解析矿机账户、Worker、Job、Share 或矿池响应，因此不提供服务费调度。</p>

   </td>
   </tr>
   <tr>
   <td>

### 👉 **下载文件**

<p>&emsp;&emsp;当前发行目录包含以下文件：</p>

```text
README-1.0.0.md
install.sh
linux/ToMinerSystem-1.0.0
windows/ToMinerSystem-1.0.0.exe
TMS/TMS-install.sh
TMS/linux/TMS-1.0.0-linux-x86_64
TMS/linux/TMS-1.0.0-linux-aarch64
TMS/windows/win-TMS.exe
```

<p>&emsp;&emsp;Linux 安装脚本会校验下载程序的 SHA-256。运行 Windows 程序前，建议同时核对发布页提供的文件校验值。</p>

   </td>
   </tr>
   <tr>
   <td>

### 👉 **其他问题**

<p>&emsp;&emsp;Web 页面提示 <code>Failed to fetch</code> 时，请检查服务是否正在运行、访问端口是否正确，以及 Windows 防火墙、UFW 或云安全组是否放行管理端口。</p>

<p>&emsp;&emsp;首次登录后请立即修改管理员密码。不要把管理 Web 端直接暴露给整个互联网，建议使用防火墙白名单、VPN、SSH 隧道或可信反向代理限制访问来源。</p>

<p>&emsp;&emsp;TMS 配对码属于连接凭据，请勿在公开仓库、群聊或截图中泄露。钱包密码、Token、私钥和管理凭据也不应写入公开日志。</p>

<p>&emsp;&emsp;Linux 安装脚本开头集中设置了 <code>VERSION</code>、<code>APP_NAME</code>、<code>APP_ID</code>、<code>DOWNLOAD_HOST</code> 和 <code>SERVICE_NAME</code>，自行托管发行文件时可以在该区域修改下载地址和品牌信息。</p>

   </td>
   </tr>
</table>

<div align="center">

ToMinerSystem v1.0.0 · Windows / Ubuntu / Debian / CentOS · 默认服务费 0%

<br>

<a href="#top">返回顶部</a>

</div>
