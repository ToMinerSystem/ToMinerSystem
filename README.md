<div id="top"></div>

<div align="center">

# ToMinerSystem

### 多币种矿池中转，可通过 TMS 建立本地加密传输

<br>

</div>

<table>
   <tr>
   <td>

<span id="anzhuang"></span>

## 服务协议

> [!Caution]
> 
> 本产品并非 VPN 类型产品，因为它无法使不允许地区访问禁止访问的内容。
>
> 本产品为矿机、矿场管理软件，并非通过不正当手段获取矿机数据。所有接入的设备均需设备拥有者主动设置矿机连接地址，以此确保任意使用本程序的客户拥有知情权。
> 
> 您不在任何恐怖活动组织及恐怖活动人员名单中，如联合国安理会决议中所列的恐怖活动组织及恐怖活动人员名单。
> 
> 您未被任何国家或地区的行政执法机构限制或禁止使用本程序。
> 
> 您非古巴、伊朗、朝鲜、叙利亚以及其他受到相关国家政府或国际机构执行制裁的国家或地区居民。
> 
> 您非限制或禁止开展数字货币相关活动国家或地区的居民，包括但不限于中国大陆地区等。
> 
> 您使用本程序提供的服务在您所在的国家或地区符合相关法律法规和政策。
> 
> 您同意：如因您所在国家或地区的法律法规和政策或其他任何适用法律的原因，导致您使用本程序的服务违法，您将独立承担相关法律风险和责任，您无条件且不可撤销地放弃向本程序进行追索的权利。
> 
> 您应该理解并遵守当地的法律法规。如果您使用此产品，默认代表您接受上述许可与限制。若因使用本产品引起法律问题，相关责任由使用者自行承担。

### **Linux 安装**

   <p>&emsp;&emsp;Ubuntu、Debian 或 CentOS x86_64 服务器运行以下 Shell 指令打开 ToMinerSystem 安装菜单：</p>

   ```sh
   bash <(curl -s -L https://github.com/ToMinerSystem/ToMinerSystem/raw/main/install.sh)
   ```
   <p>&emsp;&emsp;默认后台账户为 <code>admin</code>，初始密码和 Web 访问地址以安装完成后的终端提示为准。</p>

### **Windows 安装**

   <p>&emsp;&emsp;请直接从此项目的 Windows 目录下载服务端程序：</p>

   <p>&emsp;&emsp;<code>windows/ToMinerSystem-1.0.0.exe</code></p>

   <p>&emsp;&emsp;下载地址：<a href="windows/ToMinerSystem-1.0.0.exe">ToMinerSystem-1.0.0.exe</a></p>

   <p>&emsp;&emsp;Windows 版本放入单独文件夹后直接双击启动即可。</p>

   <p>&emsp;&emsp;默认后台账户为 <code>admin</code>，初始密码和 Web 访问端口会显示在启动窗口中。</p>

   <p>&emsp;&emsp;程序目录会保存配置、日志、证书和运行状态，请勿放在系统临时目录中，也不要只移动其中的单个配置文件。</p>

   </td>
   </tr>
   <tr>
   <td>

<span id="bizhong"></span>

### **支持的算法、协议及币种**

| 算法 / 协议 | 支持的币种或模式 |
| --- | --- |
| SHA256D | BTC、BCH |
| SCRYPT | LTC |
| ETHASH / ETHPROXY | ETC |
| KHEAVYHASH | KAS |
| ALEO ADAPTER | ALEO |
| PEARLHASH LINE JSON | PRL |
| RAW TCP / SSL | Nginx |

### **TMS 本地加密客户端**

<p>&emsp;&emsp;TMS 用于让局域网矿机先连接本地客户端，再通过加密链路连接远程 ToMinerSystem 服务端：</p>

<p><code>矿机 ──TCP/SSL──&gt; 本地 TMS 客户端 ══加密链路══&gt; ToMinerSystem 服务端 ──&gt; 矿池</code></p>

<p>&emsp;&emsp;Windows 版本下载：</p>

<p><code>TMS/windows/win-TMS.exe</code></p>

<p>&emsp;&emsp;下载地址：<a href="TMS/windows/win-TMS.exe">win-TMS.exe</a></p>

<p>&emsp;&emsp;Ubuntu、Debian、CentOS/RHEL 系列的 x86_64 或 ARM64 服务器运行以下指令打开安装管理菜单：</p>

```sh
bash <(curl -fsSL https://github.com/ToMinerSystem/ToMinerSystem/raw/main/TMS/TMS-install.sh)
```

<p>&emsp;&emsp;首次打开 TMS 客户端时，在 ToMinerSystem 服务端 Web 的 TMS 页面复制配对码并粘贴保存。绑定成功后，客户端会自动连接服务器并同步 Web 端创建、修改、启停或删除的 TMS 端口。</p>

<p>&emsp;&emsp;本地 TMS 页面会显示矿机应连接的局域网地址，例如 <code>192.168.1.5:3333</code>。

### **注意事项**

<p>&emsp;&emsp;Web 页面提示 <code>Failed to fetch</code> 时，请检查服务是否正在运行、访问端口是否正确，以及 Windows 防火墙、UFW 或云安全组是否放行管理端口。</p>

<p>&emsp;&emsp;首次登录后请立即修改管理员密码。不要把管理 Web 端直接暴露给整个互联网，建议使用防火墙白名单、VPN、SSH 隧道或可信反向代理限制访问来源。</p>

<p>&emsp;&emsp;TMS 配对码属于连接凭据，请勿在公开仓库、群聊或截图中泄露。</p>

   </td>
   </tr>
</table>

<div align="center">

ToMinerSystem · Windows / Ubuntu / Debian / CentOS · 开发阶段服务费 0%

<br>

</div>
