# monitor-agent · 多架构扩展版

> 基于 [monitor-probe/agent](https://github.com/monitor-probe/agent) 的 Fork，补充官方未发布的 Linux 架构（ARMv7、x86 32 位、RISC-V 等），并独立构建 [Yeqingky/monitor-agent-win](https://github.com/Yeqingky/monitor-agent-win) 的 Windows x64 移植版。
> **Hub 和官方 x86_64 / ARM64 Agent 不需要替换**；非官方扩展包不具备官方签名，部署前请按需验证。

**快速导航：** [版本状态](#版本状态) · [Hub 升级](#1-升级-hub主控) · [官方 Linux Agent](#2-升级官方-linux-agent) · [ARMv7 等扩展 Agent](#3-升级-armv7-等扩展-linux-agent) · [Windows Agent](#4-升级-windows-x64-agent) · [自动更新机制](#自动构建与版本规则)

## 版本状态

下方徽章从 GitHub Release 获取，**以后上游或本 Fork 发布新版时会随之刷新**（徽章服务可能有缓存）。这里显示的是**最新发布版本，不是 VPS/电脑上实际安装的版本**。

[![Hub 最新发布](https://img.shields.io/github/v/release/monitor-probe/monitor?label=Hub%20%28official%29)](https://github.com/monitor-probe/monitor/releases/latest)
[![Linux Agent 最新发布](https://img.shields.io/github/v/release/monitor-probe/agent?label=Linux%20Agent%20%28official%29)](https://github.com/monitor-probe/agent/releases/latest)
[![额外 Linux 架构](https://img.shields.io/github/v/release/xtch123/agent?label=Linux%20Extra&filter=extra-v%2A&sort=date&display_name=tag)](https://github.com/xtch123/agent/releases?q=extra-v)
[![Windows x64](https://img.shields.io/github/v/release/xtch123/agent?label=Windows%20x64&filter=windows-v%2A&sort=date&display_name=tag)](https://github.com/xtch123/agent/releases?q=windows-v)

**版本快照（2026-11-04 已核对）：**

| 组件 | 最新发布版本 | 发布页 / 下载 |
|---|---|---|
| 官方 Hub | **v1.5.1** | [官方 Hub Releases](https://github.com/monitor-probe/monitor/releases/latest) |
| 官方 Linux Agent（x86_64、ARM64） | **v1.2.3** | [官方 Agent Releases](https://github.com/monitor-probe/agent/releases/latest) |
| 本 Fork Linux 扩展架构 | **extra-v1.2.3** | [Linux 扩展版](https://github.com/xtch123/agent/releases/tag/extra-v1.2.3) |
| 本 Fork Windows x64 | **windows-v1.2.3** | [Windows 扩展版](https://github.com/xtch123/agent/releases/tag/windows-v1.2.3) |

> 快照数字是该日记录，**后续查最新版看上方徽章 / 链接，不要只看表格**。官方 Hub 面板「更新」页可检查节点当前版本是否落后。最新版本号不同不一定导致连接失败，但仍需确认协议兼容。

## 常用更新指令（收藏这里）

### 1. 升级 Hub（主控）

**方法 A：官方安装脚本部署的 Hub（systemd）**

在 **Hub 所在 Linux 服务器**执行，而不是在被监控的 Agent 节点上执行：

```bash
curl -fsSL https://github.com/monitor-probe/monitor/releases/latest/download/install-hub.sh -o install-hub.sh
sudo sh install-hub.sh
```

有交互终端时，菜单选择 **「1 安装 / 升级」**。官方脚本会复用原数据库、监听端口和 `--site` 设置，升级失败时尝试回滚；**不要用 `--purge`**，它会删除数据库。服务日志：`sudo journalctl -u monitor-hub -n 50 --no-pager`。

**方法 B：Docker Compose 部署的 Hub**

在原来的 `compose.yaml` 所在目录执行（以下假定 Compose 服务名为 `monitor`）：

```bash
docker compose pull monitor
docker compose up -d monitor
```

确保原有 `/data` 卷/目录挂载未变。实际服务名不是 `monitor` 时请替换。若使用 `docker run` 部署，则拉取原来使用的镜像，再按**原有端口、环境变量和数据卷挂载**重建容器，不要丢失 `/data`：

```bash
docker pull ghcr.io/monitor-probe/monitor:latest
# 如果原来用的是 Docker Hub 镜像，则改拉：docker pull stqfdyr/monitor:latest
```

详细操作：[Hub 官方安装脚本](https://github.com/monitor-probe/monitor/blob/main/install-hub.sh) · [官方 Docker 升级文档](https://monitor-document.pages.dev/install/docker)。

### 2. 升级官方 Linux Agent

**适用：** 官方 x86_64、ARM64 Agent，曾用 Hub 面板生成的官方脚本安装。

在**每台 Agent VPS**以 root 执行（把 `hub.example.com` 换成自己的 Hub 域名）：

```bash
curl -fsSL https://hub.example.com/install.sh | sh -s -- --upgrade
```

升级自动复用本机 Token、Hub 地址、统计网卡和上报间隔，不会创建新节点。普通用户可把管道右侧改成 `sudo sh -s -- --upgrade`；[官方批量升级说明](https://monitor-document.pages.dev/install/batch)。

### 3. 升级 ARMv7 等扩展 Linux Agent

**适用：** 已用本 Fork 的 `scripts/install-extra.sh` 安装的 ARMv7、i686 等额外架构；**不要用于替换官方 x86_64/ARM64 Agent**。

在对应 Linux 主机以 root 执行：

```bash
curl -fsSL https://raw.githubusercontent.com/xtch123/agent/main/scripts/install-extra.sh -o install-extra.sh
sh install-extra.sh --upgrade
```

首次安装或需要指定网卡请看 [README-EXTRA.md](README-EXTRA.md)。扩展版从本 Fork Linux 最新 Release 下载；如果运行在无 systemd/OpenRC 的容器中，重启后自启仍需容器侧单独配置。

### 4. 升级 Windows x64 Agent

从 [Windows 专属 Releases](https://github.com/xtch123/agent/releases?q=windows-v) 选择最新 `windows-v*`，下载 `monitor-agent-x86_64-pc-windows-gnu.exe`，核对该 Release 的 `SHA256SUMS`，然后在**管理员 PowerShell** 中进入 EXE 所在目录执行：

```powershell
.\monitor-agent-x86_64-pc-windows-gnu.exe install
```

已有服务时复用之前的配置和 Token。**首次安装**则需要从 Hub 新建节点，执行：

```powershell
.\monitor-agent-x86_64-pc-windows-gnu.exe install --server https://hub.example.com --token YOUR_NODE_TOKEN
```

详情：[WINDOWS-EXTRA.md](WINDOWS-EXTRA.md)。

## 自动构建与版本规则

| 构建流程 | 上游源码 | 本 Fork 发布名 | 触发/升级 |
|---|---|---|---|
| [Linux Extra Actions](https://github.com/xtch123/agent/actions/workflows/extra-linux.yml) | `monitor-probe/agent` 最新 Release tag | `extra-vX.Y.Z` | 每天检查，自动编译成功的平台 |
| [Windows Actions](https://github.com/xtch123/agent/actions/workflows/extra-windows.yml) | `Yeqingky/monitor-agent-win` 最新 Release tag | `windows-vX.Y.Z` | 每天检查，独立于 Linux 版本 |

**Linux 和 Windows 不必版本号一致**，谁先出新版就先构建谁。本 Fork 的 GitHub **Latest 始终留给 `extra-v*` Linux Release**，以保证 Linux 安装器使用的 `releases/latest/download` 不会误下载 Windows 文件。

注意：**GitHub Actions 自动构建发布 ≠ 各主机上的 Agent 自动升级**。各主机仍需按上述命令手动升级。Windows x64 移植版和额外 Linux 架构为**非官方、未签名构建**；CI 成功不代表所有真实机器均已验证通过。

---

## 官方 Linux Agent 使用说明（保留原 README）

以下保留上游 Linux Agent 的原始使用说明。**新增的 Windows 和扩展架构安装、升级以本页上方内容为准。**

[monitor](https://github.com/monitor-probe/monitor) 的 Linux agent。采集本机指标，经 WebSocket 上报 hub。

静态链接单文件，无运行时依赖，常驻内存数 MB。

### 特性

- 直接读 `/proc`、`/sys/class/net` 与 `statvfs`，不依赖 sysinfo
- 内存对齐 `free(1)` 的 used 列，磁盘对齐 `df(1)` 的 Used 列
- 无状态：不写文件，不保存跨重启的数据，流量累加由 hub 负责
- token 走 `Authorization` 头，不进反向代理的 access log
- 非回环地址拒绝明文 `ws://`

### 安装

在 hub 的面板添加节点，复制生成的命令在目标主机执行：

```bash
curl -fsSL https://your-hub/install.sh | sh -s -- --server https://your-hub --token <token>
```

安装脚本识别 systemd 与 OpenRC，二进制装到 `/opt/monitor/monitor-agent`，token 写入
`/opt/monitor/agent.env`（0600）——和 hub 同一个目录，那台机器上只有这一处要看。

### 运行

```bash
monitor-agent --server https://your-hub --token <token>
```

| 参数 | 默认 | 说明 |
|---|---|---|
| `--server` | 必填 | hub 地址，也可用 `MONITOR_SERVER` |
| `--token` | 必填 | 节点 token，也可用 `MONITOR_TOKEN` |
| `--interval` | 1 | 上报间隔（秒），1–3600 |
| `--iface` | 空 | 流量统计的网卡，逗号分隔，也可用 `MONITOR_IFACE`；见下 |

#### 统计哪些网卡的流量

默认规则是同一份线上的字节只数一次：lo、容器与虚拟机网卡、隧道不计；bond、网桥、VLAN、macvlan
这类叠在别的网卡上的设备也不计，只计它们底下的那块。除了按名字，还按内核给出的链路类型、`DEVTYPE`、
`lower_*` 链接和所属网桥判断，改过名的隧道、网桥，以及挂在网桥上的虚拟机 tap（如 libvirt 的 `vnet0`）
和容器 veth 同样认得出。PPPoE 只认 OpenWrt 的 `pppoe-wan`：pppd 拨号的
`ppp0` 默认照计，因为 LTE 拨号时它是唯一的链路，用 pppd 拨 PPPoE 的机器要用 `--iface` 指定。

转发流量的机器（软路由、桥接了软路由的宿主机）上，同一个包会经过两块真网卡，哪块面向运营商只有
使用者知道，这时用 `--iface`：

- `--iface eth1` 或 `--iface pppoe-wan`：只统计列出的网卡，写全名时内置规则不再生效
- `--iface -eth0`：从本来会计入的网卡里去掉一块（如软路由的 LAN 口），`-` 开头的都是排除，排除优先于列出。
  一批机器都有一块同名的内网网卡时，一条批量命令就能在每台上去掉它
- 只认完整的网卡名，不支持通配

启动时打印一行 `counting traffic on: ...`，列出此刻计入的网卡。所计网卡的集合一旦变化（改了 `--iface`、
网卡增减或被重新归类），上报的 `boot_id` 也跟着变，hub 重新对基线，不会把新旧两组读数之差记成流量。

### 上报字段

`src/collect.rs` 中的 `Facts` 与 `Metrics` 两个 struct 直接序列化为线上 JSON，是字段的权威定义。

- **`Facts`** 连接时上报一次：主机名、系统、内核、架构、虚拟化类型、CPU 型号与核数、内存与磁盘总量、本机 IPv4 / IPv6（每族一个，公网地址优先；IPv6 不取临时地址和已废弃地址）
- **`Metrics`** 每 `--interval` 秒上报：CPU、负载、内存、swap、磁盘、网卡收发速率与内核累计计数器、TCP / UDP 连接数、进程数、运行时间

`net_rx_total` / `net_tx_total` 为所计网卡的内核 lifetime 计数器之和，原样上报；`boot_id` 取自
`/proc/sys/kernel/random/boot_id`，后接 `/` 与所计网卡集合的摘要，标明这两个读数在哪段区间内可以相减，
是 hub 判定计数器重新开始的唯一依据，**不要删**。`iface` 回报当前的 `--iface`，供面板显示与预填。

连接 hub 时逐个尝试解析出的地址，除最后一个外每个限 5 秒。网卡上只有内网 IPv4（NAT）时先连 hub 的
IPv4：NAT 的公网地址不在网卡上，hub 只有看到一条 IPv4 连接才知道它。

协议说明见文档站的[架构与协议](https://monitor-document.pages.dev/dev/architecture)。

### 构建

需要 Rust stable。

```bash
cargo build --release
cargo test
cargo clippy --all-targets
```

发布产物为 musl 静态链接二进制，推送 `v*` tag 由 `.github/workflows/release.yml` 构建。

### 许可

MIT
