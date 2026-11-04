# 极简探针 Agent：额外 Linux 架构构建与安装

这是针对 [monitor-probe/agent](https://github.com/monitor-probe/agent) 的**非官方**附加构建，不替换官方 Hub，也不改变 Hub 的数字签名校验。

## 覆盖范围

官方上游只发布 Linux x86_64 和 AArch64。此 Fork 通过 `.github/workflows/extra-linux.yml` 自动尝试以下额外目标：

| 组别 | Rust targets | 状态 |
|---|---|---|
| ARMv7（独角鲸 NAT 优先） | armv7-unknown-linux-musleabihf / musleabi | 优先构建，hard-float 失败阻止 Release |
| ARMv6/ARMv5 | arm-unknown-linux-musleabihf / musleabi、armv5te-unknown-linux-musleabi | 尝试 |
| x86 32 位 | i686-unknown-linux-musl、i586-unknown-linux-musl | 尝试 |
| 其他 64 位 | riscv64gc、loongarch64、powerpc64le | 尝试 |
| 实验性 | MIPS/MIPSEL/MIPS64/MIPS64EL/S390x/PowerPC64 | 可能因工具链或依赖失败 |

**注意：编译成功 ≠ 实机验证通过。** Linux 发行版（Debian/Alpine/OpenWrt）与 CPU 架构是两个维度。容器中监控数据可能来自宿主机的 `/proc`，不一定是购买的容器配额。Windows、macOS、FreeBSD 不在本扩展内，它们需要不同的采集器代码。

## 更新来源

每次触发时读取官方仓库的最新 Release tag，然后直接检出 `monitor-probe/agent` 对应 tag 进行构建，**与 Fork 的 main 是否同步无关**。默认每天检查，也支持 Actions 里的 Run workflow。成功的产物自动发布到本 Fork 的 `extra-vX.Y.Z` Release，配套 `SHA256SUMS`。已发布该版本则跳过。

发布的额外架构二进制没有官方 Ed25519 签名，不能作为官方 Hub 的 `/agent/ARCH` 签名文件。这也是为什么单独从 Fork 的 Release 下载。

## 安装（ARMv7 Alpine NAT）

首先在 Hub 创建节点取得 URL 和 Token。只在 NAT 小鸡执行下列命令（**Token 不要截图公开**）：

```sh
apk add --no-cache curl
curl -fsSL https://raw.githubusercontent.com/xtch123/agent/main/scripts/install-extra.sh -o install-extra.sh
sh install-extra.sh --server https://YOUR_HUB --token YOUR_NODE_TOKEN --iface eth0
```

前提：Fork Actions 已成功生成 Release，包含 `monitor-agent-armv7-unknown-linux-musleabihf`。

安装器会校验 GitHub Release 对应 SHA256，验证二进制能执行，保留凭据到 `/opt/monitor/agent.env`。当活动的 systemd/OpenRC 可用时配置服务，其他 Podman 容器则手动启动常驻进程并记录 PID。**没有 init 的容器不能确保重启后自启**，需要容器宿主侧启动钩子或可用的进程管理器。

如果 ARMv7 小鸡使用 soft-float ABI，需要显式 `--target armv7-unknown-linux-musleabi`，并确保其 Release 构建成功。

## 单台机器升级

```sh
curl -fsSL https://raw.githubusercontent.com/xtch123/agent/main/scripts/install-extra.sh -o install-extra.sh
sh install-extra.sh --upgrade
```

升级复用当前节点的 Hub 地址、Token、上报间隔和网卡设置，安装器拒绝替换不由其管理的官方 Agent。升级前验证下载包；失败时尝试恢复上一版二进制。

你的普通 x86_64/AArch64 节点仍按官方 Hub 给出的升级命令处理，本 Fork 不管理它们。

## 运行验证

1. 查看 Fork 的 Actions → **Extra Linux architectures** 是否运行。
2. 查看 Releases 是否出现 `extra-vX.Y.Z`，且有 ARMv7 文件和 `SHA256SUMS`。
3. 在小鸡执行 `uname -m`、`/opt/monitor/monitor-agent --help`，检查 Hub 节点是否上线。
4. 与机器 `free`、`df`、`/proc/net/dev` 逐项比较读数。
5. 手动重启容器，核实 Agent 是否自动恢复；不恢复则配置容器持久化启动。

## 安全

官方签名验证不应关闭。Fork 产物依赖于 GitHub 账户、Actions 和构建镜像的可信性；SHA256 提供文件一致性校验，不等于签名认证。对外公开 Fork 时不要把 Hub Token 提交进仓库。
