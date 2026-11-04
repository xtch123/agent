# Windows x64 Agent（非官方扩展）

本 Fork 的 **Linux** 附加架构继续从 [monitor-probe/agent](https://github.com/monitor-probe/agent) 官方 Release 源码构建。**Windows x64** 单独从 [Yeqingky/monitor-agent-win](https://github.com/Yeqingky/monitor-agent-win) 的对应版本构建，均保留原作者的 MIT 许可和署名。

该 Windows Agent 使用 Windows API 采集数据、Windows Service 管理后台运行；不是将 Linux 版直接交叉编译。使用之前应阅读 Windows 项目 README 和免责声明，特别是其作者注明代码由 AI 生成。

## 更新策略

- `.github/workflows/extra-linux.yml` 仍负责 ARMv7 等 Linux 架构，工作方式不变。
- `.github/workflows/extra-windows.yml` 每天检查一次**官方 Linux Agent**和**Windows 移植项目**的最新 Release tag。
- 仅当版本**完全一致**，且本 Fork 已经有 `extra-vX.Y.Z` Linux Release，才从 Windows 项目该 tag 源码交叉编译 Windows x64。
- Windows 编译先执行格式、类型和 Clippy 检查，通过后才生成 `monitor-agent-x86_64-pc-windows-gnu.exe`。
- Windows EXE **追加到同一个** `extra-vX.Y.Z` Release，不覆盖任何 Linux 二进制；原有 `SHA256SUMS` 仅增加 Windows EXE 的校验行。
- 如果 Windows 项目更新较慢，则跳过此次 Windows 构建，**绝不假装旧 Windows Agent 与新 Linux Agent 同版本**。之后定时任务会再次检查。
- 只创建 unsigned/非官方扩展包，**不会改变官方 Hub 的签名验证**，也不会更新/替换 Hub。
- Windows 目前只覆盖 x64（amd64）。Windows x86 和 Windows ARM64 需要额外适配测试，不能认为已经支持。

## 安装 Windows 节点

1. 在极简探针 Hub 后台创建一个节点，复制 Hub 的 HTTPS URL 和节点 Token。
2. 前往 [Fork Releases](https://github.com/xtch123/agent/releases)，下载当前 `extra-vX.Y.Z` 下的 `monitor-agent-x86_64-pc-windows-gnu.exe` 和 `SHA256SUMS`。
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

下载 Fork Release 的新版 EXE、核对校验和，再在管理员 PowerShell 中运行：

```powershell
.\monitor-agent-x86_64-pc-windows-gnu.exe install
```

同一服务名的升级沿用 Windows 本机保存的配置；无需重新填写 Token。**Windows 的 Agent 不会因为 Fork 出了新 Release 就自动在电脑上升级**，仍需到 Windows 主机运行命令。

## 支持边界

- Hub 继续使用官方版本；Windows 版使用相同 `/api/agent/ws` WebSocket 和 `hello`、`report`、`ping.result` 消息。
- 原有 Linux ARMv7 等发布和安装器不受影响。
- CI 成功仅能证明交叉编译成功，无法证明 Windows 实机的采样准确、开机自启或兼容所有 Windows 版本；首次部署请实机核实。
- EXE 目前未进行 Windows Authenticode 代码签名；SHA256 只能检验与 Release 文件是否一致，不等同于来源签名。
