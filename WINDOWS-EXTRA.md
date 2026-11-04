# Windows x64 Agent（非官方扩展）

本 Fork 的 **Linux** 附加架构继续从 [monitor-probe/agent](https://github.com/monitor-probe/agent) 官方 Release 源码构建。**Windows x64** 单独从 [Yeqingky/monitor-agent-win](https://github.com/Yeqingky/monitor-agent-win) 的对应版本构建，均保留原作者的 MIT 许可和署名。

该 Windows Agent 使用 Windows API 采集数据、Windows Service 管理后台运行；不是将 Linux 版直接交叉编译。使用之前应阅读 Windows 项目 README 和免责声明，特别是其作者注明代码由 AI 生成。

## 更新策略（Linux / Windows 完全独立）

| 类型 | 独立上游 | 你的 GitHub Release 命名 | 更新条件 |
|---|---|---|---|
| Linux 附加架构（如 ARMv7） | [monitor-probe/agent](https://github.com/monitor-probe/agent) | `extra-vX.Y.Z` | 官方 Linux Agent 有新版本 |
| Windows x64 | [Yeqingky/monitor-agent-win](https://github.com/Yeqingky/monitor-agent-win) | `windows-vX.Y.Z` | Windows 移植版有新版本 |

- `.github/workflows/extra-linux.yml` 和 `.github/workflows/extra-windows.yml` 分别运行，每天各检查一次自己的上游。
- **不要求 Linux 和 Windows 版本号相同**。例如 Linux 已更新到 `extra-v1.2.5`，Windows 还在 `windows-v1.2.3`，两个 Release 都保留。
- Windows 构建先执行 `cargo fmt`、`cargo check`、Clippy，通过后才生成 `monitor-agent-x86_64-pc-windows-gnu.exe` 与 `SHA256SUMS`。
- Windows Release 通过 `--latest=false` 发布，**不会夺走 Linux 的 Latest 标记**。Linux 安装器继续使用 `releases/latest/download`，仍然从 Linux Release 取文件。
- Windows 发布失败不会阻塞 Linux，反之亦然。Windows 移植版没有更新时不会反复编译。
- 旧 `extra-v1.2.3` 中已经附带的 Windows EXE 作为历史文件原样保留。今后的 Windows 新版本只发布到 `windows-v*`。
- **Hub 协议兼容性要单独验证**：版本独立不代表任意不同版本组合都一定兼容。
- 两种额外架构均是非官方、未签名构建，不改变官方 Hub 签名验证，也不会更新/替换 Hub。
- Windows 目前只覆盖 x64（amd64），Windows x86 和 ARM64 不在当前构建范围。

## 安装 Windows 节点

1. 在极简探针 Hub 后台创建一个节点，复制 Hub 的 HTTPS URL 和节点 Token。
2. 前往 [Fork Releases](https://github.com/xtch123/agent/releases)（选择 `windows-v*`，不要通过 `releases/latest` 进入 Linux 版本），下载最新 Windows 专用 `windows-vX.Y.Z` Release 下的 `monitor-agent-x86_64-pc-windows-gnu.exe` 和 `SHA256SUMS`。
3. 检查 SHA256（在 PowerShell 中执行 `Get-FileHash .\monitor-agent-x86_64-pc-windows-gnu.exe -Algorithm SHA256`，与 SHA256SUMS 中对应文件的值比较）。
4. **以管理员身份**启动 PowerShell，进入下载目录后运行：

```powershell
.\monitor-agent-x86_64-pc-windows-gnu.exe install --server https://YOUR-HUB --token YOUR-NODE-TOKEN
```

如果只希望统计物理以太网，追加 `--iface "以太网"`（Windows 的实际适配器名称可能不同，可用 `Get-NetAdapter` 查看）。

安装器会把 EXE 复制到 `%ProgramData%\monitor-agent\monitor-agent.exe`，把配置保存为限制访问权限的配置文件，并创建延迟自动启动的 Windows Service。

查看服务：
```powershell
.\monitor-agent-x86_64-pc-windows-gnu.exe status
```

## 升级 Windows 节点

下载最新 `windows-vX.Y.Z` Release 的新版 EXE、核对校验和，再在管理员 PowerShell 中运行：

```powershell
.\monitor-agent-x86_64-pc-windows-gnu.exe install
```

同一服务名的升级沿用 Windows 本机保存的配置；无需重新填写 Token。**Windows 的 Agent 不会因为 Fork 出了新 Release 就自动在电脑上升级**，仍需到 Windows 主机运行命令。

## 支持边界

- Hub 继续使用官方版本；Windows 版使用相同 `/api/agent/ws` WebSocket 和 `hello`、`report`、`ping.result` 消息。
- 原有 Linux ARMv7 等发布和安装器不受影响。
- CI 成功仅能证明交叉编译成功，无法证明 Windows 实机的采样准确、开机自启或兼容所有 Windows 版本；首次部署请实机核实。
- EXE 目前未进行 Windows Authenticode 代码签名；SHA256 只能检验与 Release 文件是否一致，不等同于来源签名。
